import { Injectable, NotFoundException, BadRequestException, ForbiddenException, Logger } from '@nestjs/common';
import { PrismaService } from '@infrastructure/database/prisma.service';
import { IyzicoService } from '@infrastructure/payment/iyzico.service';
import { FcmService } from '@infrastructure/notifications/fcm.service';
import { NetgsmService } from '@infrastructure/notifications/netgsm.service';
import { ConfigService } from '@nestjs/config';
import {
    CreateBookingDto,
    ProcessPaymentDto,
    BookingResponseDto,
    BookingListResponseDto,
} from '@application/dto/bookings/bookings.dto';
import { v4 as uuid } from 'uuid';

type BookingSegmentContext = {
    departure: string;
    arrival: string;
    distanceKm: number;
    ratio: number;
    pricePerSeat: number;
};

@Injectable()
export class BookingsService {
    private readonly logger = new Logger(BookingsService.name);
    private readonly holdMinutes: number;
    private readonly disputeWindowHours: number;
    private readonly autoCompleteDelayMinutes: number;

    constructor(
        private readonly prisma: PrismaService,
        private readonly iyzicoService: IyzicoService,
        private readonly fcmService: FcmService,
        private readonly netgsmService: NetgsmService,
        private readonly configService: ConfigService,
    ) {
        this.holdMinutes = Number(this.configService.get('BOOKING_HOLD_MINUTES') || 15);
        this.disputeWindowHours = Number(this.configService.get('BOOKING_DISPUTE_WINDOW_HOURS') || 12);
        this.autoCompleteDelayMinutes = Number(this.configService.get('BOOKING_AUTO_COMPLETE_DELAY_MINUTES') || 60);
    }

    async create(userId: string, dto: CreateBookingDto): Promise<BookingResponseDto> {
        const booking = await this.prisma.$transaction(async (tx) => {
            const trip = await tx.trip.findUnique({
                where: { id: dto.tripId },
                include: { driver: true },
            });

            if (!trip) {
                this.logger.warn(`BOOKING_CREATE_TRIP_NOT_FOUND tripId=${dto.tripId} passengerId=${userId}`);
                throw new NotFoundException('Yolculuk bulunamadi');
            }

            if (trip.deletedAt) {
                this.logger.warn(`BOOKING_CREATE_TRIP_DELETED tripId=${dto.tripId} passengerId=${userId}`);
                throw new BadRequestException('Bu yolculuk artik musait degil');
            }

            if (trip.status !== 'published' && trip.status !== 'full') {
                this.logger.warn(`BOOKING_CREATE_TRIP_NOT_AVAILABLE tripId=${dto.tripId} status=${trip.status} passengerId=${userId}`);
                throw new BadRequestException('Bu yolculuk artik musait degil');
            }

            if (trip.driverId === userId) {
                this.logger.warn(`BOOKING_CREATE_SELF_BOOKING tripId=${dto.tripId} driverId=${trip.driverId}`);
                throw new BadRequestException('Kendi ilaniniza rezervasyon yapamazsiniz');
            }

            if (trip.availableSeats < dto.seats) {
                this.logger.warn(`BOOKING_CREATE_NOT_ENOUGH_SEATS tripId=${dto.tripId} seats=${dto.seats} available=${trip.availableSeats}`);
                throw new BadRequestException('Yeterli koltuk yok');
            }

            const segmentContext = this.resolveSegmentContext(
                trip,
                dto.requestedFrom,
                dto.requestedTo,
            );
            const effectivePricePerSeat =
                segmentContext?.pricePerSeat ?? Number(trip.pricePerSeat);
            const priceTotal = this.toMoney(effectivePricePerSeat * dto.seats);
            const commissionAmount = this.iyzicoService.calculateCommission(priceTotal);
            const qrCode = this.generateQRCode();
            const pnrCode = await this.generateUniquePnrCode(tx);
            const isInstant = this.resolveTripBookingType(trip) === 'instant';
            const now = new Date();
            const paymentDueAt = isInstant ? this.getPaymentExpiryFrom(now) : null;
            const bookingItemDetails = this.buildBookingItemDetails(
                dto.itemDetails,
                segmentContext,
            );

            const created = await tx.booking.create({
                data: {
                    id: uuid(),
                    tripId: dto.tripId,
                    passengerId: userId,
                    status: isInstant ? 'awaiting_payment' : 'pending',
                    seats: dto.seats,
                    priceTotal,
                    commissionAmount,
                    itemType: (dto.itemType as any) || 'person',
                    itemDetails: bookingItemDetails
                        ? JSON.stringify(bookingItemDetails)
                        : null,
                    qrCode,
                    pnrCode,
                    paymentStatus: 'pending',
                    acceptedAt: isInstant ? now : null,
                    expiresAt: paymentDueAt,
                    paymentDueAt,
                },
                include: {
                    trip: {
                        include: { driver: true },
                    },
                    passenger: true,
                },
            });

            return created;
        });

        if (booking.status === 'pending') {
            await this.notifyNewBookingRequest(booking);
        }

        return this.mapToResponse(booking);
    }

    async accept(bookingId: string, driverId: string): Promise<BookingResponseDto> {
        const booking = await this.prisma.booking.findUnique({
            where: { id: bookingId },
            include: {
                trip: { include: { driver: true } },
                passenger: true,
            },
        });

        if (!booking) {
            throw new NotFoundException('Rezervasyon bulunamadi');
        }

        if (booking.trip.driverId !== driverId) {
            throw new ForbiddenException('Bu rezervasyona erisim yetkiniz yok');
        }

        if (booking.status !== 'pending') {
            throw new BadRequestException('Sadece bekleyen rezervasyon kabul edilebilir');
        }

        const now = new Date();
        const paymentDueAt = this.getPaymentExpiryFrom(now);
        const updated = await this.prisma.booking.update({
            where: { id: bookingId },
            data: {
                status: 'awaiting_payment',
                acceptedAt: now,
                expiresAt: paymentDueAt,
                paymentDueAt,
            },
            include: {
                trip: { include: { driver: true } },
                passenger: true,
            },
        });

        return this.mapToResponse(updated);
    }

    async reject(bookingId: string, driverId: string, reason?: string): Promise<BookingResponseDto> {
        const booking = await this.prisma.booking.findUnique({
            where: { id: bookingId },
            include: {
                trip: { include: { driver: true } },
                passenger: true,
            },
        });

        if (!booking) {
            throw new NotFoundException('Rezervasyon bulunamadi');
        }

        if (booking.trip.driverId !== driverId) {
            throw new ForbiddenException('Bu rezervasyona erisim yetkiniz yok');
        }

        if (booking.status !== 'pending') {
            throw new BadRequestException('Sadece bekleyen rezervasyon reddedilebilir');
        }

        const updated = await this.prisma.booking.update({
            where: { id: bookingId },
            data: {
                status: 'rejected',
                cancellationTime: new Date(),
                cancellationPenalty: 0,
                expiresAt: null,
                paymentDueAt: null,
                ...(reason ? { disputeReason: reason.slice(0, 500) } : {}),
            },
            include: {
                trip: { include: { driver: true } },
                passenger: true,
            },
        });

        return this.mapToResponse(updated);
    }

    async processPayment(userId: string, dto: ProcessPaymentDto): Promise<BookingResponseDto> {
        const booking = await this.prisma.booking.findUnique({
            where: { id: dto.bookingId },
            include: {
                trip: { include: { driver: true } },
                passenger: true,
            },
        });

        if (!booking) {
            throw new NotFoundException('Rezervasyon bulunamadi');
        }

        if (booking.passengerId !== userId) {
            throw new ForbiddenException('Bu rezervasyona erisim yetkiniz yok');
        }

        if (booking.paymentStatus === 'paid') {
            throw new BadRequestException('Bu rezervasyon zaten odendi');
        }

        if (booking.status !== 'awaiting_payment') {
            throw new BadRequestException('Bu rezervasyon odeme beklemiyor');
        }

        const paymentDueAt = booking.paymentDueAt || booking.expiresAt;
        if (paymentDueAt && paymentDueAt.getTime() < Date.now()) {
            await this.expireBooking(booking);
            throw new BadRequestException('Odeme suresi dolmus');
        }

        const result = await this.iyzicoService.processPayment(
            userId,
            Number(booking.priceTotal),
            dto.cardToken,
            booking.id,
        );

        if (!result.success) {
            throw new BadRequestException(result.errorMessage || 'Odeme islemi basarisiz');
        }

        const now = new Date();

        await this.prisma.$transaction(async (tx) => {
            const seatUpdate = await tx.trip.updateMany({
                where: {
                    id: booking.tripId,
                    status: { in: ['published', 'full'] },
                    availableSeats: { gte: booking.seats },
                },
                data: {
                    availableSeats: { decrement: booking.seats },
                },
            });

            if (seatUpdate.count === 0) {
                throw new BadRequestException('Yeterli koltuk kalmadi');
            }

            const updatedTrip = await tx.trip.findUnique({
                where: { id: booking.tripId },
                select: { availableSeats: true },
            });

            await tx.booking.update({
                where: { id: dto.bookingId },
                data: {
                    paymentStatus: 'paid',
                    paymentId: result.paymentId,
                    status: 'confirmed',
                    paidAt: now,
                    expiresAt: null,
                    paymentDueAt: null,
                },
            });

            if (updatedTrip) {
                await tx.trip.update({
                    where: { id: booking.tripId },
                    data: {
                        status: updatedTrip.availableSeats === 0 ? 'full' : 'published',
                    },
                });
            }
        });

        const updated = await this.prisma.booking.findUnique({
            where: { id: dto.bookingId },
            include: {
                trip: { include: { driver: true } },
                passenger: true,
            },
        });

        if (!updated) {
            throw new NotFoundException('Odeme sonrasi rezervasyon bulunamadi');
        }

        await this.notifyBookingConfirmed(updated);
        return this.mapToResponse(updated);
    }

    async checkIn(driverId: string, qrCode: string): Promise<BookingResponseDto> {
        const booking = await this.prisma.booking.findUnique({
            where: { qrCode },
            include: {
                trip: true,
                passenger: true,
            },
        });

        if (!booking) {
            throw new NotFoundException('Gecersiz QR kod');
        }

        if (booking.trip.driverId !== driverId) {
            throw new ForbiddenException('Bu yolculuk size ait degil');
        }

        if (booking.status !== 'confirmed') {
            throw new BadRequestException('Bu rezervasyon check-in icin uygun degil');
        }

        const updated = await this.prisma.booking.update({
            where: { id: booking.id },
            data: {
                status: 'checked_in',
                checkedInAt: new Date(),
            },
            include: {
                trip: { include: { driver: true } },
                passenger: true,
                payoutLedger: true,
            },
        });

        await this.releasePayoutForBooking(updated.id, 10);
        return this.mapToResponse(updated);
    }

    async checkInByPnr(driverId: string, pnrCode: string, tripId: string): Promise<BookingResponseDto> {
        const normalizedPnr = this.normalizePnrCode(pnrCode);
        if (normalizedPnr.length !== 6) {
            throw new BadRequestException('Gecersiz PNR kod');
        }

        const booking = await this.prisma.booking.findUnique({
            where: { pnrCode: normalizedPnr },
            include: {
                trip: true,
                passenger: true,
            },
        });

        if (!booking) {
            throw new NotFoundException('Gecersiz PNR kod');
        }

        if (booking.tripId !== tripId) {
            throw new BadRequestException('PNR bu yolculuga ait degil');
        }

        if (booking.trip.driverId !== driverId) {
            throw new ForbiddenException('Bu yolculuk size ait degil');
        }

        if (booking.status !== 'confirmed') {
            throw new BadRequestException('Bu rezervasyon check-in icin uygun degil');
        }

        const updated = await this.prisma.booking.update({
            where: { id: booking.id },
            data: {
                status: 'checked_in',
                checkedInAt: new Date(),
            },
            include: {
                trip: { include: { driver: true } },
                passenger: true,
                payoutLedger: true,
            },
        });

        await this.releasePayoutForBooking(updated.id, 10);
        return this.mapToResponse(updated);
    }

    async completeByPassenger(bookingId: string, passengerId: string): Promise<BookingResponseDto> {
        const booking = await this.prisma.booking.findUnique({
            where: { id: bookingId },
            include: {
                trip: { include: { driver: true } },
                passenger: true,
            },
        });

        if (!booking) {
            throw new NotFoundException('Rezervasyon bulunamadi');
        }

        if (booking.passengerId !== passengerId) {
            throw new ForbiddenException('Bu rezervasyonu tamamlama yetkiniz yok');
        }

        if (booking.status !== 'checked_in') {
            throw new BadRequestException('Sadece check-in yapilmis rezervasyon tamamlanabilir');
        }

        const now = new Date();
        const updated = await this.prisma.booking.update({
            where: { id: booking.id },
            data: {
                status: 'completed',
                completedAt: now,
                completionSource: 'passenger',
                disputeStatus: 'none',
                disputeDeadlineAt: this.getDisputeDeadlineFrom(now),
            },
            include: {
                trip: { include: { driver: true } },
                passenger: true,
                payoutLedger: true,
            },
        });

        return this.mapToResponse(updated);
    }

    async raiseDispute(bookingId: string, userId: string, reason: string): Promise<BookingResponseDto> {
        const booking = await this.prisma.booking.findUnique({
            where: { id: bookingId },
            include: {
                trip: { include: { driver: true } },
                passenger: true,
                payoutLedger: true,
            },
        });

        if (!booking) {
            throw new NotFoundException('Rezervasyon bulunamadi');
        }

        const isPassenger = booking.passengerId === userId;
        const isDriver = booking.trip.driverId === userId;
        if (!isPassenger && !isDriver) {
            throw new ForbiddenException('Bu rezervasyon icin itiraz acamazsiniz');
        }

        if (booking.status !== 'completed' && booking.status !== 'disputed') {
            throw new BadRequestException('Ihtilaf sadece tamamlanmis rezervasyonlarda acilabilir');
        }

        if (!booking.disputeDeadlineAt || booking.disputeDeadlineAt.getTime() < Date.now()) {
            throw new BadRequestException('Ihtilaf suresi dolmus');
        }

        if (booking.payout90ReleasedAt) {
            throw new BadRequestException('Bu rezervasyon icin odeme dagitimi tamamlanmis');
        }

        const updated = await this.prisma.$transaction(async (tx) => {
            const disputedBooking = await tx.booking.update({
                where: { id: booking.id },
                data: {
                    status: 'disputed',
                    disputeStatus: 'open',
                    disputedAt: new Date(),
                    disputeReason: reason.slice(0, 500),
                    payoutHoldReason: 'dispute_open',
                },
                include: {
                    trip: { include: { driver: true } },
                    passenger: true,
                    payoutLedger: true,
                },
            });

            if (booking.payoutLedger) {
                await tx.payoutLedger.update({
                    where: { id: booking.payoutLedger.id },
                    data: {
                        status: 'hold',
                        holdReason: 'dispute_open',
                    },
                });
            }

            return disputedBooking;
        });

        return this.mapToResponse(updated);
    }

    async autoCompleteEligibleBookings(): Promise<number> {
        const now = new Date();
        const candidates = await this.prisma.booking.findMany({
            where: {
                status: 'checked_in',
                checkedInAt: { not: null },
            },
            include: {
                trip: true,
            },
        });

        let completed = 0;
        for (const booking of candidates) {
            const autoCompletionTime = this.getAutoCompletionTime(booking);
            if (now.getTime() < autoCompletionTime.getTime()) {
                continue;
            }

            await this.prisma.booking.update({
                where: { id: booking.id },
                data: {
                    status: 'completed',
                    completedAt: now,
                    completionSource: 'auto',
                    disputeStatus: 'none',
                    disputeDeadlineAt: this.getDisputeDeadlineFrom(now),
                },
            });
            completed++;
        }

        if (completed > 0) {
            this.logger.log(`Auto-completed ${completed} bookings.`);
        }
        return completed;
    }

    async releasePendingPayouts(): Promise<{ stage10Released: number; stage90Released: number }> {
        const paidBookings = await this.prisma.booking.findMany({
            where: {
                paymentStatus: 'paid',
                status: { in: ['checked_in', 'completed'] },
            },
            select: { id: true },
        });

        let stage10Released = 0;
        let stage90Released = 0;

        for (const booking of paidBookings) {
            const stage10Result = await this.releasePayoutForBooking(booking.id, 10);
            if (stage10Result) {
                stage10Released++;
            }

            const stage90Result = await this.releasePayoutForBooking(booking.id, 90);
            if (stage90Result) {
                stage90Released++;
            }
        }

        if (stage10Released > 0 || stage90Released > 0) {
            this.logger.log(`Released payouts: stage10=${stage10Released}, stage90=${stage90Released}`);
        }
        return { stage10Released, stage90Released };
    }

    async cancel(bookingId: string, userId: string): Promise<void> {
        const booking = await this.prisma.booking.findUnique({
            where: { id: bookingId },
            include: { trip: { include: { driver: true } }, passenger: true },
        });

        if (!booking) {
            throw new NotFoundException('Rezervasyon bulunamadi');
        }

        const isPassenger = booking.passengerId === userId;
        const isDriver = booking.trip.driverId === userId;

        if (!isPassenger && !isDriver) {
            throw new ForbiddenException('Bu rezervasyonu iptal etme yetkiniz yok');
        }

        if (['checked_in', 'completed', 'disputed'].includes(booking.status)) {
            throw new BadRequestException('Check-in sonrasi rezervasyon iptal edilemez');
        }

        if (['expired', 'cancelled_by_passenger', 'cancelled_by_driver', 'rejected'].includes(booking.status)) {
            throw new BadRequestException('Rezervasyon zaten kapatilmis');
        }

        const hoursUntilDeparture = (booking.trip.departureTime.getTime() - Date.now()) / (1000 * 60 * 60);
        let refundPercentage = 100;
        let penalty = 0;

        if (hoursUntilDeparture < 2) {
            refundPercentage = 0;
            penalty = Number(booking.priceTotal);
        } else if (hoursUntilDeparture < 24) {
            refundPercentage = 50;
            penalty = Number(booking.priceTotal) * 0.5;
        }

        let refundAmount = 0;

        if (booking.paymentStatus === 'paid' && booking.paymentId && refundPercentage > 0) {
            refundAmount = Number(booking.priceTotal) * (refundPercentage / 100);
            await this.iyzicoService.refundPayment(
                booking.paymentId,
                refundAmount,
                isPassenger ? 'Yolcu iptali' : 'Surucu iptali',
            );
        }

        await this.prisma.$transaction(async (tx) => {
            await tx.booking.update({
                where: { id: bookingId },
                data: {
                    status: isPassenger ? 'cancelled_by_passenger' : 'cancelled_by_driver',
                    cancellationTime: new Date(),
                    cancellationPenalty: penalty,
                    paymentStatus: refundPercentage === 100 ? 'refunded' :
                        refundPercentage > 0 ? 'partially_refunded' : booking.paymentStatus,
                    expiresAt: null,
                    paymentDueAt: null,
                },
            });

            if (booking.status === 'confirmed') {
                await tx.trip.update({
                    where: { id: booking.tripId },
                    data: {
                        availableSeats: { increment: booking.seats },
                        status: 'published',
                    },
                });
            }
        });

        await this.notifyCancellation(booking, isPassenger ? 'passenger' : 'driver', refundAmount);
    }

    async findMyBookings(userId: string): Promise<BookingListResponseDto> {
        const bookings = await this.prisma.booking.findMany({
            where: {
                passengerId: userId,
                itemType: { not: 'chat_only' },
            },
            orderBy: { createdAt: 'desc' },
            include: {
                trip: true,
                passenger: true,
            },
        });

        return {
            bookings: bookings.map((b) => this.mapToResponse(b)),
            total: bookings.length,
        };
    }

    async findTripBookings(tripId: string, driverId: string): Promise<BookingListResponseDto> {
        const trip = await this.prisma.trip.findUnique({
            where: { id: tripId },
        });

        if (!trip || trip.driverId !== driverId) {
            throw new ForbiddenException('Bu yolculuga erisim yetkiniz yok');
        }

        const bookings = await this.prisma.booking.findMany({
            where: {
                tripId,
                itemType: { not: 'chat_only' },
            },
            orderBy: { createdAt: 'desc' },
            include: {
                trip: true,
                passenger: true,
            },
        });

        return {
            bookings: bookings.map((b) => this.mapToResponse(b)),
            total: bookings.length,
        };
    }

    async findById(bookingId: string, userId: string): Promise<BookingResponseDto> {
        const booking = await this.prisma.booking.findUnique({
            where: { id: bookingId },
            include: {
                trip: { include: { driver: true } },
                passenger: true,
            },
        });

        if (!booking) {
            throw new NotFoundException('Rezervasyon bulunamadi');
        }

        const isPassenger = booking.passengerId === userId;
        const isDriver = booking.trip?.driverId === userId;
        if (!isPassenger && !isDriver) {
            throw new ForbiddenException('Bu rezervasyona erisim yetkiniz yok');
        }

        return this.mapToResponse(booking);
    }

    private getPaymentExpiryFrom(base: Date): Date {
        return new Date(base.getTime() + this.holdMinutes * 60 * 1000);
    }

    private resolveTripBookingType(trip: any): 'instant' | 'approval_required' {
        const raw = String(trip?.bookingType || '').trim().toLowerCase();
        if (raw === 'approval_required') {
            return 'approval_required';
        }
        if (raw === 'instant') {
            return 'instant';
        }
        return trip?.instantBooking === false ? 'approval_required' : 'instant';
    }

    private getDisputeDeadlineFrom(base: Date): Date {
        return new Date(base.getTime() + this.disputeWindowHours * 60 * 60 * 1000);
    }

    private getAutoCompletionTime(booking: any): Date {
        const baseline = booking.trip.estimatedArrivalTime
            ? new Date(booking.trip.estimatedArrivalTime)
            : new Date(new Date(booking.trip.departureTime).getTime() + 2 * 60 * 60 * 1000);
        return new Date(baseline.getTime() + this.autoCompleteDelayMinutes * 60 * 1000);
    }

    private generateQRCode(): string {
        const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
        let code = 'BK-';
        for (let i = 0; i < 12; i++) {
            code += chars.charAt(Math.floor(Math.random() * chars.length));
        }
        return code;
    }

    private generatePnrCode(): string {
        const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
        let code = '';
        for (let i = 0; i < 6; i++) {
            code += chars.charAt(Math.floor(Math.random() * chars.length));
        }
        return code;
    }

    private normalizePnrCode(pnrCode: string): string {
        return (pnrCode || '').toUpperCase().replace(/[^A-Z0-9]/g, '').slice(0, 6);
    }

    private async generateUniquePnrCode(tx: any): Promise<string> {
        for (let i = 0; i < 10; i++) {
            const candidate = this.generatePnrCode();
            const existing = await tx.booking.findUnique({
                where: { pnrCode: candidate },
                select: { id: true },
            });
            if (!existing) {
                return candidate;
            }
        }
        throw new BadRequestException('PNR kod olusturulamadi');
    }

    private async expireBooking(booking: any): Promise<void> {
        await this.prisma.booking.update({
            where: { id: booking.id },
            data: {
                status: 'expired',
                cancellationTime: new Date(),
                cancellationPenalty: 0,
                paymentStatus: 'pending',
                expiresAt: null,
                paymentDueAt: null,
            },
        });
    }

    private async releasePayoutForBooking(bookingId: string, stage: 10 | 90): Promise<boolean> {
        let booking = await this.prisma.booking.findUnique({
            where: { id: bookingId },
            include: {
                trip: { include: { driver: true } },
                passenger: true,
                payoutLedger: true,
            },
        });

        if (!booking || booking.paymentStatus !== 'paid') {
            return false;
        }

        const ledger = await this.ensurePayoutLedger(booking);
        booking = { ...booking, payoutLedger: ledger };

        if (stage === 10 && booking.payout10ReleasedAt) {
            return false;
        }
        if (stage === 90 && booking.payout90ReleasedAt) {
            return false;
        }

        if (stage === 90) {
            if (booking.status !== 'completed') {
                return false;
            }
            if (booking.disputeStatus === 'open') {
                return false;
            }
            if (!booking.disputeDeadlineAt || booking.disputeDeadlineAt.getTime() > Date.now()) {
                return false;
            }
            if (!booking.payout10ReleasedAt) {
                await this.releasePayoutForBooking(booking.id, 10);
                booking = await this.prisma.booking.findUnique({
                    where: { id: bookingId },
                    include: {
                        trip: { include: { driver: true } },
                        passenger: true,
                        payoutLedger: true,
                    },
                }) as any;
                if (!booking || !booking.payout10ReleasedAt) {
                    return false;
                }
            }
        }

        const driver = booking.trip.driver;
        if (driver.payoutVerificationStatus !== 'verified' || !driver.payoutProviderAccountId) {
            await this.prisma.$transaction(async (tx) => {
                await tx.booking.update({
                    where: { id: booking.id },
                    data: { payoutHoldReason: 'driver_payout_account_not_verified' },
                });
                await tx.payoutLedger.update({
                    where: { id: ledger.id },
                    data: {
                        status: 'hold',
                        holdReason: 'driver_payout_account_not_verified',
                    },
                });
            });
            return false;
        }

        const amount = stage === 10 ? Number(ledger.release10Amount) : Number(ledger.release90Amount);
        if (amount <= 0) {
            const now = new Date();
            await this.prisma.$transaction(async (tx) => {
                await tx.booking.update({
                    where: { id: booking.id },
                    data: stage === 10
                        ? { payout10ReleasedAt: now, payoutHoldReason: null }
                        : { payout90ReleasedAt: now, payoutHoldReason: null },
                });
                await tx.payoutLedger.update({
                    where: { id: ledger.id },
                    data: stage === 10
                        ? { stage10ReleasedAt: now, status: 'partial_released', holdReason: null, lastError: null }
                        : { stage90ReleasedAt: now, status: 'released', holdReason: null, lastError: null },
                });
            });
            return true;
        }

        const payoutResult = await this.iyzicoService.releasePayout(
            driver.payoutProviderAccountId,
            amount,
            `booking-${booking.id}-stage-${stage}`,
        );

        if (!payoutResult.success) {
            await this.prisma.$transaction(async (tx) => {
                await tx.booking.update({
                    where: { id: booking.id },
                    data: { payoutHoldReason: payoutResult.errorMessage || 'payout_release_failed' },
                });
                await tx.payoutLedger.update({
                    where: { id: ledger.id },
                    data: {
                        status: 'hold',
                        holdReason: 'payout_release_failed',
                        lastError: payoutResult.errorMessage || 'payout_release_failed',
                    },
                });
            });
            return false;
        }

        const now = new Date();
        await this.prisma.$transaction(async (tx) => {
            await tx.user.update({
                where: { id: driver.id },
                data: {
                    walletBalance: { increment: amount },
                },
            });

            await tx.booking.update({
                where: { id: booking.id },
                data: stage === 10
                    ? { payout10ReleasedAt: now, payoutHoldReason: null }
                    : { payout90ReleasedAt: now, payoutHoldReason: null },
            });

            await tx.payoutLedger.update({
                where: { id: ledger.id },
                data: stage === 10
                    ? {
                        stage10ReleasedAt: now,
                        status: 'partial_released',
                        holdReason: null,
                        lastError: null,
                        providerTransferId: payoutResult.transferId,
                    }
                    : {
                        stage90ReleasedAt: now,
                        status: 'released',
                        holdReason: null,
                        lastError: null,
                        providerTransferId: payoutResult.transferId,
                    },
            });
        });

        return true;
    }

    private async ensurePayoutLedger(booking: any): Promise<any> {
        if (booking.payoutLedger) {
            return booking.payoutLedger;
        }

        const grossAmount = Number(booking.priceTotal);
        const commissionAmount = Number(booking.commissionAmount);
        const driverNetAmount = Math.max(0, Math.round((grossAmount - commissionAmount) * 100) / 100);
        const release10Amount = Math.round(driverNetAmount * 0.1 * 100) / 100;
        const release90Amount = Math.round((driverNetAmount - release10Amount) * 100) / 100;

        return this.prisma.payoutLedger.create({
            data: {
                id: uuid(),
                bookingId: booking.id,
                driverId: booking.trip.driverId,
                grossAmount,
                commissionAmount,
                driverNetAmount,
                release10Amount,
                release90Amount,
                status: 'pending',
            },
        });
    }

    private resolveSegmentContext(
        trip: any,
        requestedFrom?: string,
        requestedTo?: string,
    ): BookingSegmentContext | undefined {
        const fromQuery = String(requestedFrom || '').trim();
        const toQuery = String(requestedTo || '').trim();
        if (!fromQuery || !toQuery) {
            return undefined;
        }

        const stops = this.buildTripStops(trip);
        if (stops.length < 2) {
            return undefined;
        }

        const startIndex = this.findMatchingStopIndex(stops, fromQuery, 0);
        if (startIndex < 0) {
            return undefined;
        }
        const endIndex = this.findMatchingStopIndex(stops, toQuery, startIndex + 1);
        if (endIndex < 0 || endIndex <= startIndex) {
            return undefined;
        }

        const totalDistanceKm = this.resolveTripDistanceKm(trip, stops);
        if (!Number.isFinite(totalDistanceKm) || totalDistanceKm <= 0) {
            return undefined;
        }

        const segmentDistanceKm = this.resolveSegmentDistanceKm(
            stops,
            startIndex,
            endIndex,
            totalDistanceKm,
        );
        if (!Number.isFinite(segmentDistanceKm) || segmentDistanceKm <= 0) {
            return undefined;
        }

        const ratio = this.clamp01(segmentDistanceKm / totalDistanceKm);
        if (!Number.isFinite(ratio) || ratio <= 0) {
            return undefined;
        }

        const basePricePerSeat = Number(trip.pricePerSeat || 0);
        if (!Number.isFinite(basePricePerSeat) || basePricePerSeat <= 0) {
            return undefined;
        }

        return {
            departure: stops[startIndex].city,
            arrival: stops[endIndex].city,
            distanceKm: this.toMoney(segmentDistanceKm),
            ratio: this.toMoney(ratio),
            pricePerSeat: this.toMoney(basePricePerSeat * ratio),
        };
    }

    private buildTripStops(trip: any): Array<{
        city: string;
        district?: string;
        lat?: number;
        lng?: number;
        searchText: string;
    }> {
        const preferences = this.parseTripPreferences(trip.preferences);
        const viaCities = this.normalizeViaCities(preferences.viaCities);
        const stops: Array<{
            city: string;
            district?: string;
            lat?: number;
            lng?: number;
            searchText: string;
        }> = [];

        stops.push({
            city: String(trip.departureCity || '').trim(),
            lat: this.toFiniteNumber(trip.departureLat),
            lng: this.toFiniteNumber(trip.departureLng),
            searchText: String(trip.departureCity || '').trim(),
        });

        for (const via of viaCities) {
            const city = via.city.trim();
            if (!city) continue;
            const district = via.district?.trim();
            const text = district ? `${city} ${district}` : city;
            const dedupeKey = this.normalizeForSearch(text);
            if (
                stops.some((stop) => this.normalizeForSearch(stop.searchText) === dedupeKey)
            ) {
                continue;
            }
            stops.push({
                city,
                district,
                lat: via.lat,
                lng: via.lng,
                searchText: text,
            });
        }

        stops.push({
            city: String(trip.arrivalCity || '').trim(),
            lat: this.toFiniteNumber(trip.arrivalLat),
            lng: this.toFiniteNumber(trip.arrivalLng),
            searchText: String(trip.arrivalCity || '').trim(),
        });

        return stops.filter((stop) => stop.city.length > 0);
    }

    private findMatchingStopIndex(
        stops: Array<{ searchText: string }>,
        query: string,
        fromIndex: number,
    ): number {
        for (let i = Math.max(0, fromIndex); i < stops.length; i += 1) {
            if (this.matchesLocationQuery(query, stops[i].searchText)) {
                return i;
            }
        }
        return -1;
    }

    private matchesLocationQuery(query: string, candidate: string): boolean {
        const normalizedQuery = this.normalizeForSearch(query);
        const normalizedCandidate = this.normalizeForSearch(candidate);
        if (!normalizedQuery || !normalizedCandidate) return false;

        if (
            normalizedCandidate.includes(normalizedQuery) ||
            normalizedQuery.includes(normalizedCandidate)
        ) {
            return true;
        }

        const queryTokens = normalizedQuery.split(' ').filter(Boolean);
        const candidateTokens = normalizedCandidate.split(' ').filter(Boolean);
        if (!queryTokens.length || !candidateTokens.length) return false;

        return queryTokens.every((token) =>
            candidateTokens.some((candidateToken) =>
                this.isFuzzyTokenMatch(token, candidateToken),
            ),
        );
    }

    private isFuzzyTokenMatch(queryToken: string, candidateToken: string): boolean {
        if (
            candidateToken.includes(queryToken) ||
            queryToken.includes(candidateToken)
        ) {
            return true;
        }
        const maxDistance =
            queryToken.length <= 4 ? 1 : queryToken.length <= 8 ? 2 : 3;
        return (
            this.levenshteinDistance(queryToken, candidateToken, maxDistance) <=
            maxDistance
        );
    }

    private levenshteinDistance(
        left: string,
        right: string,
        maxDistance: number,
    ): number {
        if (left === right) return 0;
        if (!left.length) return right.length;
        if (!right.length) return left.length;
        if (Math.abs(left.length - right.length) > maxDistance) {
            return maxDistance + 1;
        }

        const previousRow = Array.from({ length: right.length + 1 }, (_, i) => i);
        const currentRow = new Array<number>(right.length + 1);

        for (let i = 1; i <= left.length; i += 1) {
            currentRow[0] = i;
            let rowMin = currentRow[0];

            for (let j = 1; j <= right.length; j += 1) {
                const insertCost = currentRow[j - 1] + 1;
                const deleteCost = previousRow[j] + 1;
                const replaceCost =
                    previousRow[j - 1] + (left[i - 1] === right[j - 1] ? 0 : 1);
                const next = Math.min(insertCost, deleteCost, replaceCost);
                currentRow[j] = next;
                if (next < rowMin) {
                    rowMin = next;
                }
            }

            if (rowMin > maxDistance) {
                return maxDistance + 1;
            }

            for (let j = 0; j <= right.length; j += 1) {
                previousRow[j] = currentRow[j];
            }
        }

        return previousRow[right.length];
    }

    private normalizeForSearch(value: string): string {
        return String(value || '')
            .trim()
            .toLocaleLowerCase('tr-TR')
            .replace(/ı/g, 'i')
            .replace(/ğ/g, 'g')
            .replace(/ş/g, 's')
            .replace(/ö/g, 'o')
            .replace(/ü/g, 'u')
            .replace(/ç/g, 'c')
            .normalize('NFKD')
            .replace(/[\u0300-\u036f]/g, '')
            .replace(/[^a-z0-9\s]/g, ' ')
            .replace(/\s+/g, ' ')
            .trim();
    }

    private resolveTripDistanceKm(
        trip: any,
        stops: Array<{ lat?: number; lng?: number }>,
    ): number {
        const preferences = this.parseTripPreferences(trip.preferences);
        const routeDistance = Number(preferences?.routeSnapshot?.distanceKm || 0);
        if (Number.isFinite(routeDistance) && routeDistance > 0) {
            return routeDistance;
        }

        const tripDistance = Number(trip.distanceKm || 0);
        if (Number.isFinite(tripDistance) && tripDistance > 0) {
            return tripDistance;
        }

        const first = stops[0];
        const last = stops[stops.length - 1];
        if (
            first?.lat !== undefined &&
            first?.lng !== undefined &&
            last?.lat !== undefined &&
            last?.lng !== undefined
        ) {
            return this.haversineDistanceKm(first.lat, first.lng, last.lat, last.lng);
        }

        return 0;
    }

    private resolveSegmentDistanceKm(
        stops: Array<{ lat?: number; lng?: number }>,
        startIndex: number,
        endIndex: number,
        totalDistanceKm: number,
    ): number {
        const start = stops[startIndex];
        const end = stops[endIndex];
        if (
            start?.lat !== undefined &&
            start?.lng !== undefined &&
            end?.lat !== undefined &&
            end?.lng !== undefined
        ) {
            const direct = this.haversineDistanceKm(start.lat, start.lng, end.lat, end.lng);
            if (Number.isFinite(direct) && direct > 0) {
                return Math.min(direct, totalDistanceKm);
            }
        }

        const stopSpan = stops.length - 1;
        if (stopSpan <= 0) {
            return totalDistanceKm;
        }

        const ratio = this.clamp01((endIndex - startIndex) / stopSpan);
        return totalDistanceKm * ratio;
    }

    private clamp01(value: number): number {
        if (!Number.isFinite(value)) return 0;
        if (value < 0) return 0;
        if (value > 1) return 1;
        return value;
    }

    private toFiniteNumber(value: any): number | undefined {
        if (value === null || value === undefined) return undefined;
        const parsed = Number(value);
        return Number.isFinite(parsed) ? parsed : undefined;
    }

    private toMoney(value: number): number {
        return Number(Number(value || 0).toFixed(2));
    }

    private haversineDistanceKm(
        lat1: number,
        lng1: number,
        lat2: number,
        lng2: number,
    ): number {
        const toRad = (deg: number) => (deg * Math.PI) / 180;
        const earthRadiusKm = 6371;
        const dLat = toRad(lat2 - lat1);
        const dLng = toRad(lng2 - lng1);
        const a =
            Math.sin(dLat / 2) ** 2 +
            Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
        const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
        return earthRadiusKm * c;
    }

    private parseTripPreferences(raw: any): Record<string, any> {
        if (!raw) return {};
        if (typeof raw === 'string') {
            try {
                const parsed = JSON.parse(raw);
                return parsed && typeof parsed === 'object' ? parsed : {};
            } catch {
                return {};
            }
        }
        return typeof raw === 'object' ? raw : {};
    }

    private normalizeViaCities(raw: any): Array<{
        city: string;
        district?: string;
        lat?: number;
        lng?: number;
    }> {
        if (!Array.isArray(raw)) return [];
        const dedupe = new Set<string>();
        return raw
            .map((entry: any) => {
                const city = String(entry?.city || '').trim();
                if (!city) return null;
                const district = String(entry?.district || '').trim();
                const key = this.normalizeForSearch(
                    district ? `${city} ${district}` : city,
                );
                if (dedupe.has(key)) return null;
                dedupe.add(key);
                return {
                    city,
                    district: district || undefined,
                    lat: this.toFiniteNumber(entry?.lat),
                    lng: this.toFiniteNumber(entry?.lng),
                };
            })
            .filter(Boolean) as Array<{
            city: string;
            district?: string;
            lat?: number;
            lng?: number;
        }>;
    }

    private buildBookingItemDetails(
        currentDetails: any,
        segment?: BookingSegmentContext,
    ): any {
        if (!segment) {
            return currentDetails ?? null;
        }

        if (currentDetails === null || currentDetails === undefined) {
            return { segment };
        }

        if (typeof currentDetails === 'object' && !Array.isArray(currentDetails)) {
            return {
                ...currentDetails,
                segment,
            };
        }

        return {
            value: currentDetails,
            segment,
        };
    }

    private extractSegmentContext(raw: any): BookingSegmentContext | undefined {
        const segment = raw?.segment;
        if (!segment || typeof segment !== 'object') {
            return undefined;
        }

        const departure = String(segment.departure || '').trim();
        const arrival = String(segment.arrival || '').trim();
        const distanceKm = Number(segment.distanceKm);
        const ratio = Number(segment.ratio);
        const pricePerSeat = Number(segment.pricePerSeat);

        if (
            !departure ||
            !arrival ||
            !Number.isFinite(distanceKm) ||
            !Number.isFinite(ratio) ||
            !Number.isFinite(pricePerSeat)
        ) {
            return undefined;
        }

        return {
            departure,
            arrival,
            distanceKm: this.toMoney(distanceKm),
            ratio: this.toMoney(ratio),
            pricePerSeat: this.toMoney(pricePerSeat),
        };
    }

    private mapToResponse(booking: any): BookingResponseDto {
        const parsedItemDetails = this.parseItemDetails(booking.itemDetails);
        const seats = Number(booking.seats || 0);
        const effectivePricePerSeat =
            seats > 0
                ? this.toMoney(Number(booking.priceTotal) / seats)
                : Number(booking.trip.pricePerSeat);
        const segment = this.extractSegmentContext(parsedItemDetails);

        return {
            id: booking.id,
            tripId: booking.tripId,
            trip: {
                departureCity: booking.trip.departureCity,
                arrivalCity: booking.trip.arrivalCity,
                departureTime: booking.trip.departureTime,
                pricePerSeat: effectivePricePerSeat,
            },
            passengerId: booking.passengerId,
            passenger: {
                fullName: booking.passenger.fullName,
                phone: booking.passenger.phone,
                profilePhotoUrl: booking.passenger.profilePhotoUrl,
            },
            status: booking.status,
            seats: booking.seats,
            priceTotal: Number(booking.priceTotal),
            commissionAmount: Number(booking.commissionAmount),
            itemType: booking.itemType,
            itemDetails: parsedItemDetails,
            segment,
            qrCode: booking.qrCode,
            pnrCode: booking.pnrCode || undefined,
            checkedInAt: booking.checkedInAt || undefined,
            acceptedAt: booking.acceptedAt || undefined,
            paidAt: booking.paidAt || undefined,
            completedAt: booking.completedAt || undefined,
            completionSource: booking.completionSource || undefined,
            disputeStatus: booking.disputeStatus || undefined,
            disputedAt: booking.disputedAt || undefined,
            disputeReason: booking.disputeReason || undefined,
            disputeDeadlineAt: booking.disputeDeadlineAt || undefined,
            payout10ReleasedAt: booking.payout10ReleasedAt || undefined,
            payout90ReleasedAt: booking.payout90ReleasedAt || undefined,
            payoutHoldReason: booking.payoutHoldReason || undefined,
            expiresAt: booking.expiresAt || undefined,
            paymentDueAt: booking.paymentDueAt || undefined,
            paymentStatus: booking.paymentStatus,
            createdAt: booking.createdAt,
        };
    }

    private parseItemDetails(raw: any): any {
        if (!raw) return undefined;
        if (typeof raw !== 'string') return raw;
        try {
            return JSON.parse(raw);
        } catch {
            return raw;
        }
    }

    private async notifyNewBookingRequest(booking: any) {
        try {
            const driver = booking.trip?.driver;
            const passenger = booking.passenger;
            if (!driver) return;

            const tokens = this.extractDeviceTokens(driver.preferences);
            if (tokens.length > 0) {
                await Promise.all(tokens.map((token) =>
                    this.fcmService.notifyNewBookingRequest(token, passenger.fullName, {
                        from: booking.trip.departureCity,
                        to: booking.trip.arrivalCity,
                    })
                ));
            }

            if (driver.phone) {
                await this.netgsmService.sendNewBookingRequest(driver.phone, passenger.fullName, {
                    from: booking.trip.departureCity,
                    to: booking.trip.arrivalCity,
                    date: this.formatTripDate(booking.trip.departureTime),
                });
            }
        } catch {
            // Ignore notification errors
        }
    }

    private async notifyBookingConfirmed(booking: any) {
        try {
            const passenger = booking.passenger;
            const driver = booking.trip?.driver;

            const tokens = this.extractDeviceTokens(passenger.preferences);
            if (tokens.length > 0) {
                await Promise.all(tokens.map((token) =>
                    this.fcmService.notifyBookingConfirmed(token, {
                        from: booking.trip.departureCity,
                        to: booking.trip.arrivalCity,
                    })
                ));
            }

            if (passenger.phone) {
                await this.netgsmService.sendBookingConfirmation(passenger.phone, {
                    from: booking.trip.departureCity,
                    to: booking.trip.arrivalCity,
                    date: this.formatTripDateTime(booking.trip.departureTime),
                    qrCode: booking.qrCode,
                });
            }

            if (driver?.phone) {
                await this.netgsmService.sendNewBookingRequest(driver.phone, passenger.fullName, {
                    from: booking.trip.departureCity,
                    to: booking.trip.arrivalCity,
                    date: this.formatTripDate(booking.trip.departureTime),
                });
            }
        } catch {
            // Ignore notification errors
        }
    }

    private async notifyCancellation(booking: any, cancelledBy: 'driver' | 'passenger', refundAmount: number) {
        try {
            const otherUser = cancelledBy === 'driver' ? booking.passenger : booking.trip.driver;
            if (!otherUser) return;

            const tokens = this.extractDeviceTokens(otherUser.preferences);
            if (tokens.length > 0) {
                await Promise.all(tokens.map((token) =>
                    this.fcmService.notifyCancellation(token, cancelledBy)
                ));
            }

            if (otherUser.phone) {
                const payout = cancelledBy === 'driver' ? refundAmount : 0;
                await this.netgsmService.sendCancellationNotice(otherUser.phone, payout);
            }
        } catch {
            // Ignore notification errors
        }
    }

    private extractDeviceTokens(preferences: any): string[] {
        if (!preferences) return [];
        const parsed = typeof preferences === 'string'
            ? (() => {
                try {
                    return JSON.parse(preferences);
                } catch {
                    return {};
                }
            })()
            : preferences;

        const tokens = parsed?.deviceTokens;
        if (Array.isArray(tokens)) {
            return tokens.filter((t) => typeof t === 'string' && t.length > 0);
        }
        if (typeof parsed?.deviceToken === 'string' && parsed.deviceToken.length > 0) {
            return [parsed.deviceToken];
        }
        return [];
    }

    private formatTripDate(date: Date): string {
        const formatter = new Intl.DateTimeFormat('tr-TR', {
            day: '2-digit',
            month: '2-digit',
            year: 'numeric',
        });
        return formatter.format(date);
    }

    private formatTripDateTime(date: Date): string {
        const formatter = new Intl.DateTimeFormat('tr-TR', {
            day: '2-digit',
            month: '2-digit',
            year: 'numeric',
            hour: '2-digit',
            minute: '2-digit',
        });
        return formatter.format(date);
    }
}
