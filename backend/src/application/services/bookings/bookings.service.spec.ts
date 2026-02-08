import { BadRequestException, ForbiddenException, NotFoundException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { BookingsService } from './bookings.service';
import { PrismaService } from '@infrastructure/database/prisma.service';
import { IyzicoService } from '@infrastructure/payment/iyzico.service';
import { FcmService } from '@infrastructure/notifications/fcm.service';
import { NetgsmService } from '@infrastructure/notifications/netgsm.service';

describe('BookingsService', () => {
    let service: BookingsService;

    const mockPrismaService = {
        $transaction: jest.fn(),
        booking: {
            findUnique: jest.fn(),
            update: jest.fn(),
        },
    };

    const mockIyzicoService = {
        processPayment: jest.fn(),
        refundPayment: jest.fn(),
        calculateCommission: jest.fn(() => 10),
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
            return undefined;
        }),
    };

    const confirmedBooking = {
        id: 'booking-1',
        tripId: 'trip-1',
        passengerId: 'passenger-1',
        status: 'confirmed',
        seats: 1,
        priceTotal: 120,
        commissionAmount: 12,
        itemType: 'person',
        itemDetails: null,
        qrCode: 'BK-ABC123456789',
        pnrCode: 'ABC123',
        checkedInAt: null,
        paymentStatus: 'paid',
        expiresAt: null,
        createdAt: new Date('2026-02-08T10:00:00Z'),
        trip: {
            id: 'trip-1',
            driverId: 'driver-1',
            departureCity: 'Istanbul',
            arrivalCity: 'Ankara',
            departureTime: new Date('2026-02-10T09:00:00Z'),
            pricePerSeat: 120,
        },
        passenger: {
            fullName: 'Passenger One',
            phone: '+905550000000',
            profilePhotoUrl: null,
        },
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
    });

    it('checks in with valid pnr and trip id', async () => {
        mockPrismaService.booking.findUnique.mockResolvedValue(confirmedBooking);
        mockPrismaService.booking.update.mockResolvedValue({
            ...confirmedBooking,
            status: 'checked_in',
            checkedInAt: new Date('2026-02-08T10:15:00Z'),
        });

        const result = await service.checkInByPnr('driver-1', 'abc123', 'trip-1');

        expect(result.status).toBe('checked_in');
        expect(result.pnrCode).toBe('ABC123');
        expect(mockPrismaService.booking.findUnique).toHaveBeenCalledWith(
            expect.objectContaining({
                where: { pnrCode: 'ABC123' },
            }),
        );
    });

    it('throws BadRequestException for malformed pnr', async () => {
        await expect(service.checkInByPnr('driver-1', 'A1', 'trip-1')).rejects.toThrow(BadRequestException);
    });

    it('throws NotFoundException for unknown pnr', async () => {
        mockPrismaService.booking.findUnique.mockResolvedValue(null);

        await expect(service.checkInByPnr('driver-1', 'ABC123', 'trip-1')).rejects.toThrow(NotFoundException);
    });

    it('throws BadRequestException when pnr belongs to another trip', async () => {
        mockPrismaService.booking.findUnique.mockResolvedValue(confirmedBooking);

        await expect(service.checkInByPnr('driver-1', 'ABC123', 'trip-2')).rejects.toThrow(BadRequestException);
    });

    it('throws ForbiddenException when driver does not own trip', async () => {
        mockPrismaService.booking.findUnique.mockResolvedValue(confirmedBooking);

        await expect(service.checkInByPnr('driver-2', 'ABC123', 'trip-1')).rejects.toThrow(ForbiddenException);
    });
});
