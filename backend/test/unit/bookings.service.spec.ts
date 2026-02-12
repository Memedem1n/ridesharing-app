import { Test, TestingModule } from '@nestjs/testing';
import { BookingsService } from '@application/services/bookings/bookings.service';
import { PrismaService } from '@infrastructure/database/prisma.service';
import { IyzicoService } from '@infrastructure/payment/iyzico.service';
import { FcmService } from '@infrastructure/notifications/fcm.service';
import { NetgsmService } from '@infrastructure/notifications/netgsm.service';
import { ConfigService } from '@nestjs/config';
import { NotFoundException, BadRequestException, ForbiddenException } from '@nestjs/common';

describe('BookingsService', () => {
    let service: BookingsService;

    const mockPrismaService = {
        $transaction: jest.fn(),
        booking: {
            findMany: jest.fn(),
            findUnique: jest.fn(),
            create: jest.fn(),
            update: jest.fn(),
            updateMany: jest.fn(),
        },
        trip: {
            findUnique: jest.fn(),
            update: jest.fn(),
            updateMany: jest.fn(),
        },
    };

    const mockIyzicoService = {
        processPayment: jest.fn(),
        refundPayment: jest.fn(),
        calculateCommission: jest.fn().mockReturnValue(15),
    };

    const mockFcmService = {
        notifyNewBookingRequest: jest.fn(),
        notifyBookingConfirmed: jest.fn(),
        notifyCancellation: jest.fn(),
    };

    const mockNetgsmService = {
        sendNewBookingRequest: jest.fn(),
        sendBookingConfirmation: jest.fn(),
        sendCancellationNotice: jest.fn(),
    };

    const mockConfigService = {
        get: jest.fn((key: string) => {
            if (key === 'BOOKING_HOLD_MINUTES') return 15;
            if (key === 'BOOKING_DISPUTE_WINDOW_HOURS') return 12;
            if (key === 'BOOKING_AUTO_COMPLETE_DELAY_MINUTES') return 60;
            return undefined;
        }),
    };

    const mockTrip = {
        id: 'trip-1',
        driverId: 'driver-1',
        status: 'published',
        pricePerSeat: 150,
        availableSeats: 3,
        departureCity: 'İstanbul',
        arrivalCity: 'Ankara',
        departureTime: new Date(Date.now() + 86400000 * 2), // 2 days from now
        driver: { id: 'driver-1', fullName: 'Driver' },
    };

    const mockBooking = {
        id: 'booking-1',
        tripId: 'trip-1',
        passengerId: 'passenger-1',
        status: 'confirmed',
        seats: 2,
        priceTotal: 300,
        commissionAmount: 30,
        qrCode: 'BK-ABC123456789',
        paymentStatus: 'paid',
        paymentId: 'PAY-123',
        trip: mockTrip,
        passenger: { fullName: 'Passenger', phone: '+905551234567' },
    };

    beforeEach(async () => {
        const module: TestingModule = await Test.createTestingModule({
            providers: [
                BookingsService,
                { provide: PrismaService, useValue: mockPrismaService },
                { provide: IyzicoService, useValue: mockIyzicoService },
                { provide: FcmService, useValue: mockFcmService },
                { provide: NetgsmService, useValue: mockNetgsmService },
                { provide: ConfigService, useValue: mockConfigService },
            ],
        }).compile();

        service = module.get<BookingsService>(BookingsService);
        jest.clearAllMocks();
        mockPrismaService.$transaction.mockImplementation(async (cb) => cb(mockPrismaService));
    });

    describe('create', () => {
        it('should create booking successfully', async () => {
            mockPrismaService.trip.findUnique.mockResolvedValue(mockTrip);
            mockPrismaService.booking.create.mockResolvedValue(mockBooking);
            mockPrismaService.trip.updateMany.mockResolvedValue({ count: 1 });

            const result = await service.create('passenger-1', {
                tripId: 'trip-1',
                seats: 2,
            });

            expect(result).toHaveProperty('id');
            expect(result).toHaveProperty('qrCode');
        });

        it('should throw NotFoundException for non-existent trip', async () => {
            mockPrismaService.trip.findUnique.mockResolvedValue(null);

            await expect(
                service.create('passenger-1', { tripId: 'non-existent', seats: 1 }),
            ).rejects.toThrow(NotFoundException);
        });

        it('should throw BadRequestException for own trip', async () => {
            mockPrismaService.trip.findUnique.mockResolvedValue(mockTrip);

            await expect(
                service.create('driver-1', { tripId: 'trip-1', seats: 1 }),
            ).rejects.toThrow(BadRequestException);
        });

        it('should throw BadRequestException for insufficient seats', async () => {
            mockPrismaService.trip.findUnique.mockResolvedValue({
                ...mockTrip,
                availableSeats: 1,
            });
            mockPrismaService.trip.updateMany.mockResolvedValue({ count: 0 });

            await expect(
                service.create('passenger-1', { tripId: 'trip-1', seats: 3 }),
            ).rejects.toThrow(BadRequestException);
        });
    });

    describe('processPayment', () => {
        it('should process payment successfully', async () => {
            mockPrismaService.booking.findUnique.mockResolvedValue({
                ...mockBooking,
                paymentStatus: 'pending',
                status: 'awaiting_payment',
                expiresAt: null,
                paymentDueAt: null,
            });
            mockIyzicoService.processPayment.mockResolvedValue({
                success: true,
                paymentId: 'PAY-456',
            });
            mockPrismaService.booking.update.mockResolvedValue({
                ...mockBooking,
                paymentStatus: 'paid',
                status: 'confirmed',
            });

            const result = await service.processPayment('passenger-1', {
                bookingId: 'booking-1',
                cardToken: 'TOKEN-123',
            });

            expect(result.paymentStatus).toBe('paid');
        });

        it('should throw BadRequestException for payment failure', async () => {
            mockPrismaService.booking.findUnique.mockResolvedValue({
                ...mockBooking,
                paymentStatus: 'pending',
                status: 'awaiting_payment',
                expiresAt: null,
                paymentDueAt: null,
            });
            mockIyzicoService.processPayment.mockResolvedValue({
                success: false,
                errorMessage: 'Card declined',
            });

            await expect(
                service.processPayment('passenger-1', {
                    bookingId: 'booking-1',
                    cardToken: 'TOKEN-123',
                }),
            ).rejects.toThrow(BadRequestException);
        });
    });

    describe('checkIn', () => {
        it('should check in successfully with valid QR code', async () => {
            mockPrismaService.booking.findUnique.mockResolvedValue(mockBooking);
            mockPrismaService.booking.update.mockResolvedValue({
                ...mockBooking,
                status: 'checked_in',
                checkedInAt: new Date(),
            });

            const result = await service.checkIn('driver-1', 'BK-ABC123456789');

            expect(result.status).toBe('checked_in');
        });

        it('should throw NotFoundException for invalid QR code', async () => {
            mockPrismaService.booking.findUnique.mockResolvedValue(null);

            await expect(service.checkIn('driver-1', 'INVALID')).rejects.toThrow(NotFoundException);
        });

        it('should throw ForbiddenException for non-driver', async () => {
            mockPrismaService.booking.findUnique.mockResolvedValue(mockBooking);

            await expect(
                service.checkIn('other-driver', 'BK-ABC123456789'),
            ).rejects.toThrow(ForbiddenException);
        });
    });

    describe('cancel', () => {
        it('should cancel with full refund if more than 24h before departure', async () => {
            mockPrismaService.booking.findUnique.mockResolvedValue(mockBooking);
            mockIyzicoService.refundPayment.mockResolvedValue({ success: true });
            mockPrismaService.booking.update.mockResolvedValue({});
            mockPrismaService.trip.update.mockResolvedValue({});

            await expect(service.cancel('booking-1', 'passenger-1')).resolves.not.toThrow();
            expect(mockIyzicoService.refundPayment).toHaveBeenCalled();
        });
    });
});
