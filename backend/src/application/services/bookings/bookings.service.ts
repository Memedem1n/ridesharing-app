import { Injectable, NotFoundException, BadRequestException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '@infrastructure/database/prisma.service';
import { IyzicoService } from '@infrastructure/payment/iyzico.service';
import {
    CreateBookingDto,
    ProcessPaymentDto,
    BookingResponseDto,
    BookingListResponseDto,
    BookingStatus,
    PaymentStatus,
} from '@application/dto/bookings/bookings.dto';
import { v4 as uuid } from 'uuid';

@Injectable()
export class BookingsService {
    constructor(
        private readonly prisma: PrismaService,
        private readonly iyzicoService: IyzicoService,
    ) { }

    async create(userId: string, dto: CreateBookingDto): Promise<BookingResponseDto> {
        // Get trip
        const trip = await this.prisma.trip.findUnique({
            where: { id: dto.tripId },
            include: { driver: true },
        });

        if (!trip) {
            throw new NotFoundException('Yolculuk bulunamadı');
        }

        if (trip.status !== 'published') {
            throw new BadRequestException('Bu yolculuk artık müsait değil');
        }

        if (trip.availableSeats < dto.seats) {
            throw new BadRequestException('Yeterli koltuk yok');
        }

        if (trip.driverId === userId) {
            throw new BadRequestException('Kendi ilanınıza rezervasyon yapamazsınız');
        }

        // Calculate price
        const priceTotal = Number(trip.pricePerSeat) * dto.seats;
        const commissionAmount = this.iyzicoService.calculateCommission(priceTotal);

        // Generate QR code
        const qrCode = this.generateQRCode();

        // Create booking
        const booking = await this.prisma.booking.create({
            data: {
                id: uuid(),
                tripId: dto.tripId,
                passengerId: userId,
                status: 'pending',
                seats: dto.seats,
                priceTotal,
                commissionAmount,
                itemType: dto.itemType as any || 'person',
                itemDetails: dto.itemDetails ? JSON.stringify(dto.itemDetails) : null,
                qrCode,
                paymentStatus: 'pending',
            },
            include: {
                trip: {
                    include: { driver: true },
                },
                passenger: true,
            },
        });

        // Update available seats
        await this.prisma.trip.update({
            where: { id: dto.tripId },
            data: {
                availableSeats: trip.availableSeats - dto.seats,
                status: trip.availableSeats - dto.seats === 0 ? 'full' : 'published',
            },
        });

        return this.mapToResponse(booking);
    }

    async processPayment(userId: string, dto: ProcessPaymentDto): Promise<BookingResponseDto> {
        const booking = await this.prisma.booking.findUnique({
            where: { id: dto.bookingId },
            include: {
                trip: true,
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

        // Process payment via İyzico
        const result = await this.iyzicoService.processPayment(
            userId,
            Number(booking.priceTotal),
            dto.cardToken,
            booking.id,
        );

        if (!result.success) {
            throw new BadRequestException(result.errorMessage || 'Ödeme işlemi başarısız');
        }

        // Update booking
        const updated = await this.prisma.booking.update({
            where: { id: dto.bookingId },
            data: {
                paymentStatus: 'paid',
                paymentId: result.paymentId,
                status: 'confirmed',
            },
            include: {
                trip: true,
                passenger: true,
            },
        });

        // TODO: Send confirmation SMS/push

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
            include: { trip: true },
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

        // Process refund if paid
        if (booking.paymentStatus === 'paid' && refundPercentage > 0) {
            const refundAmount = Number(booking.priceTotal) * (refundPercentage / 100);
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

    private generateQRCode(): string {
        const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
        let code = 'BK-';
        for (let i = 0; i < 12; i++) {
            code += chars.charAt(Math.floor(Math.random() * chars.length));
        }
        return code;
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
            paymentStatus: booking.paymentStatus,
            createdAt: booking.createdAt,
        };
    }
}
