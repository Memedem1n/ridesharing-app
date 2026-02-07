import { Injectable, NotFoundException, BadRequestException, ForbiddenException } from '@nestjs/common';
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

@Injectable()
export class BookingsService {
    private readonly holdMinutes: number;

    constructor(
        private readonly prisma: PrismaService,
        private readonly iyzicoService: IyzicoService,
        private readonly fcmService: FcmService,
        private readonly netgsmService: NetgsmService,
        private readonly configService: ConfigService,
    ) {
        this.holdMinutes = Number(this.configService.get('BOOKING_HOLD_MINUTES') || 15);
    }

    async create(userId: string, dto: CreateBookingDto): Promise<BookingResponseDto> {
        const booking = await this.prisma.$transaction(async (tx) => {
            const trip = await tx.trip.findUnique({
                where: { id: dto.tripId },
                include: { driver: true },
            });

            if (!trip) {
                throw new NotFoundException('Yolculuk bulunamadı');
            }

            if (trip.status !== 'published') {
                throw new BadRequestException('Bu yolculuk artık müsait değil');
            }

            if (trip.driverId === userId) {
                throw new BadRequestException('Kendi ilanınıza rezervasyon yapamazsınız');
            }

            if (trip.availableSeats < dto.seats) {
                throw new BadRequestException('Yeterli koltuk yok');
            }

            const priceTotal = Number(trip.pricePerSeat) * dto.seats;
            const commissionAmount = this.iyzicoService.calculateCommission(priceTotal);
            const qrCode = this.generateQRCode();
            const expiresAt = new Date(Date.now() + this.holdMinutes * 60 * 1000);
            const remainingSeats = trip.availableSeats - dto.seats;

            const updated = await tx.trip.updateMany({
                where: {
                    id: dto.tripId,
                    status: 'published',
                    availableSeats: { gte: dto.seats },
                },
                data: {
                    availableSeats: { decrement: dto.seats },
                    status: remainingSeats === 0 ? 'full' : 'published',
                },
            });

            if (updated.count === 0) {
                throw new BadRequestException('Yeterli koltuk yok');
            }

            const created = await tx.booking.create({
                data: {
                    id: uuid(),
                    tripId: dto.tripId,
                    passengerId: userId,
                    status: 'pending',
                    seats: dto.seats,
                    priceTotal,
                    commissionAmount,
                    itemType: (dto.itemType as any) || 'person',
                    itemDetails: dto.itemDetails ? JSON.stringify(dto.itemDetails) : null,
                    qrCode,
                    paymentStatus: 'pending',
                    expiresAt,
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

        await this.notifyNewBookingRequest(booking);
        return this.mapToResponse(booking);
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
            throw new NotFoundException('Rezervasyon bulunamadı');
        }

        if (booking.passengerId !== userId) {
            throw new ForbiddenException('Bu rezervasyona erişim yetkiniz yok');
        }

        if (booking.paymentStatus === 'paid') {
            throw new BadRequestException('Bu rezervasyon zaten ödendi');
        }

        if (booking.status !== 'pending') {
            throw new BadRequestException('Bu rezervasyon ödeme beklemiyor');
        }

        if (booking.expiresAt && booking.expiresAt.getTime() < Date.now()) {
            await this.expireBooking(booking);
            throw new BadRequestException('Rezervasyon süresi dolmuş');
        }

        const result = await this.iyzicoService.processPayment(
            userId,
            Number(booking.priceTotal),
            dto.cardToken,
            booking.id,
        );

        if (!result.success) {
            await this.prisma.$transaction(async (tx) => {
                await tx.booking.update({
                    where: { id: dto.bookingId },
                    data: {
                        status: 'cancelled_by_passenger',
                        cancellationTime: new Date(),
                        cancellationPenalty: 0,
                        paymentStatus: 'pending',
                        expiresAt: null,
                    },
                });

                await tx.trip.updateMany({
                    where: {
                        id: booking.tripId,
                        status: { in: ['published', 'full'] },
                    },
                    data: {
                        availableSeats: { increment: booking.seats },
                        status: 'published',
                    },
                });
            });

            throw new BadRequestException(result.errorMessage || 'Ödeme işlemi başarısız');
        }

        const updated = await this.prisma.booking.update({
            where: { id: dto.bookingId },
            data: {
                paymentStatus: 'paid',
                paymentId: result.paymentId,
                status: 'confirmed',
                expiresAt: null,
            },
            include: {
                trip: { include: { driver: true } },
                passenger: true,
            },
        });

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
            throw new NotFoundException('Geçersiz QR kod');
        }

        if (booking.trip.driverId !== driverId) {
            throw new ForbiddenException('Bu yolculuk size ait değil');
        }

        if (booking.status !== 'confirmed') {
            throw new BadRequestException('Bu rezervasyon onaylanmamış veya zaten check-in yapılmış');
        }

        const updated = await this.prisma.booking.update({
            where: { id: booking.id },
            data: {
                status: 'checked_in',
                checkedInAt: new Date(),
            },
            include: {
                trip: true,
                passenger: true,
            },
        });

        return this.mapToResponse(updated);
    }

    async cancel(bookingId: string, userId: string): Promise<void> {
        const booking = await this.prisma.booking.findUnique({
            where: { id: bookingId },
            include: { trip: { include: { driver: true } }, passenger: true },
        });

        if (!booking) {
            throw new NotFoundException('Rezervasyon bulunamadı');
        }

        const isPassenger = booking.passengerId === userId;
        const isDriver = booking.trip.driverId === userId;

        if (!isPassenger && !isDriver) {
            throw new ForbiddenException('Bu rezervasyonu iptal etme yetkiniz yok');
        }

        // Calculate cancellation penalty
        const hoursUntilDeparture = (booking.trip.departureTime.getTime() - Date.now()) / (1000 * 60 * 60);
        let refundPercentage = 100;
        let penalty = 0;

        if (hoursUntilDeparture < 2) {
            refundPercentage = 0; // No refund
            penalty = Number(booking.priceTotal);
        } else if (hoursUntilDeparture < 24) {
            refundPercentage = 50;
            penalty = Number(booking.priceTotal) * 0.5;
        }

        let refundAmount = 0;

        // Process refund if paid
        if (booking.paymentStatus === 'paid' && refundPercentage > 0) {
            refundAmount = Number(booking.priceTotal) * (refundPercentage / 100);
            await this.iyzicoService.refundPayment(
                booking.paymentId!,
                refundAmount,
                isPassenger ? 'Yolcu iptali' : 'Sürücü iptali',
            );
        }

        // Update booking
        await this.prisma.booking.update({
            where: { id: bookingId },
            data: {
                status: isPassenger ? 'cancelled_by_passenger' : 'cancelled_by_driver',
                cancellationTime: new Date(),
                cancellationPenalty: penalty,
                paymentStatus: refundPercentage === 100 ? 'refunded' :
                    refundPercentage > 0 ? 'partially_refunded' : 'paid',
                expiresAt: null,
            },
        });

        // Restore seats
        await this.prisma.trip.update({
            where: { id: booking.tripId },
            data: {
                availableSeats: { increment: booking.seats },
                status: 'published',
            },
        });

        await this.notifyCancellation(booking, isPassenger ? 'passenger' : 'driver', refundAmount);
    }

    async findMyBookings(userId: string): Promise<BookingListResponseDto> {
        const bookings = await this.prisma.booking.findMany({
            where: { passengerId: userId },
            orderBy: { createdAt: 'desc' },
            include: {
                trip: true,
                passenger: true,
            },
        });

        return {
            bookings: bookings.map(b => this.mapToResponse(b)),
            total: bookings.length,
        };
    }

    async findTripBookings(tripId: string, driverId: string): Promise<BookingListResponseDto> {
        const trip = await this.prisma.trip.findUnique({
            where: { id: tripId },
        });

        if (!trip || trip.driverId !== driverId) {
            throw new ForbiddenException('Bu yolculuğa erişim yetkiniz yok');
        }

        const bookings = await this.prisma.booking.findMany({
            where: { tripId },
            orderBy: { createdAt: 'desc' },
            include: {
                trip: true,
                passenger: true,
            },
        });

        return {
            bookings: bookings.map(b => this.mapToResponse(b)),
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
            throw new NotFoundException('Rezervasyon bulunamadı');
        }

        const isPassenger = booking.passengerId === userId;
        const isDriver = booking.trip?.driverId === userId;
        if (!isPassenger && !isDriver) {
            throw new ForbiddenException('Bu rezervasyona erişim yetkiniz yok');
        }

        return this.mapToResponse(booking);
    }

    private generateQRCode(): string {
        const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
        let code = 'BK-';
        for (let i = 0; i < 12; i++) {
            code += chars.charAt(Math.floor(Math.random() * chars.length));
        }
        return code;
    }

    private async expireBooking(booking: any): Promise<void> {
        await this.prisma.$transaction(async (tx) => {
            await tx.booking.update({
                where: { id: booking.id },
                data: {
                    status: 'expired',
                    cancellationTime: new Date(),
                    cancellationPenalty: 0,
                    paymentStatus: 'pending',
                    expiresAt: null,
                },
            });

            await tx.trip.updateMany({
                where: {
                    id: booking.tripId,
                    status: { in: ['published', 'full'] },
                },
                data: {
                    availableSeats: { increment: booking.seats },
                    status: 'published',
                },
            });
        });
    }

    private mapToResponse(booking: any): BookingResponseDto {
        return {
            id: booking.id,
            tripId: booking.tripId,
            trip: {
                departureCity: booking.trip.departureCity,
                arrivalCity: booking.trip.arrivalCity,
                departureTime: booking.trip.departureTime,
                pricePerSeat: Number(booking.trip.pricePerSeat),
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
            itemDetails: booking.itemDetails,
            qrCode: booking.qrCode,
            checkedInAt: booking.checkedInAt,
            expiresAt: booking.expiresAt,
            paymentStatus: booking.paymentStatus,
            createdAt: booking.createdAt,
        };
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

