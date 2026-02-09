import { BadRequestException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { ConfigService } from '@nestjs/config';
import { TripsService } from './trips.service';
import { PrismaService } from '@infrastructure/database/prisma.service';
import { BusPriceScraperService } from '@infrastructure/scraper/bus-price-scraper.service';
import { RedisService } from '@infrastructure/cache/redis.service';
import { FcmService } from '@infrastructure/notifications/fcm.service';
import { NetgsmService } from '@infrastructure/notifications/netgsm.service';
import { IyzicoService } from '@infrastructure/payment/iyzico.service';
import axios from 'axios';

describe('TripsService', () => {
    let service: TripsService;

    const mockPrismaService = {
        vehicle: {
            findFirst: jest.fn(),
        },
        trip: {
            create: jest.fn(),
            findUnique: jest.fn(),
            update: jest.fn(),
        },
        booking: {
            findMany: jest.fn().mockResolvedValue([]),
        },
    };

    const mockBusPriceScraperService = {
        getPrice: jest.fn().mockResolvedValue(null),
    };

    const mockRedisService = {
        isConfigured: jest.fn().mockReturnValue(false),
    };

    const mockFcmService = {
        notifyTripUpdated: jest.fn(),
        notifyTripCancelled: jest.fn(),
    };

    const mockNetgsmService = {
        sendTripUpdated: jest.fn(),
        sendTripCancelled: jest.fn(),
        sendCancellationNotice: jest.fn(),
    };

    const mockConfigService = {
        get: jest.fn((key: string) => {
            if (key === 'TRIP_SEARCH_CACHE_TTL_SECONDS') return 120;
            return undefined;
        }),
    };

    const mockIyzicoService = {
        refundPayment: jest.fn().mockResolvedValue({ success: true }),
    };

    const baseTrip = {
        id: 'trip-1',
        driverId: 'driver-1',
        status: 'published',
        type: 'people',
        departureCity: 'Istanbul',
        arrivalCity: 'Ankara',
        departureAddress: 'Kadikoy',
        arrivalAddress: 'Kizilay',
        departureTime: new Date('2026-02-09T08:00:00Z'),
        availableSeats: 3,
        pricePerSeat: 150,
        allowsPets: false,
        allowsCargo: false,
        womenOnly: false,
        instantBooking: true,
        description: null,
        distanceKm: null,
        createdAt: new Date('2026-02-08T10:00:00Z'),
        driver: {
            id: 'driver-1',
            fullName: 'Driver',
            profilePhotoUrl: null,
            ratingAvg: 4.6,
            totalTrips: 20,
        },
        vehicle: {
            id: 'vehicle-1',
            brand: 'Toyota',
            model: 'Corolla',
            color: 'White',
            licensePlate: '34ABC123',
        },
    };

    beforeEach(async () => {
        const module: TestingModule = await Test.createTestingModule({
            providers: [
                TripsService,
                { provide: PrismaService, useValue: mockPrismaService },
                { provide: BusPriceScraperService, useValue: mockBusPriceScraperService },
                { provide: RedisService, useValue: mockRedisService },
                { provide: FcmService, useValue: mockFcmService },
                { provide: NetgsmService, useValue: mockNetgsmService },
                { provide: ConfigService, useValue: mockConfigService },
                { provide: IyzicoService, useValue: mockIyzicoService },
            ],
        }).compile();

        service = module.get<TripsService>(TripsService);
        jest.clearAllMocks();
    });

    afterEach(() => {
        jest.restoreAllMocks();
    });

    it('accepts coordinates inside Turkiye bounds on create', async () => {
        mockPrismaService.vehicle.findFirst.mockResolvedValue({ id: 'vehicle-1' });
        mockPrismaService.trip.create.mockResolvedValue(baseTrip);

        const result = await service.create('driver-1', {
            vehicleId: 'vehicle-1',
            type: 'people' as any,
            departureCity: 'Istanbul',
            arrivalCity: 'Ankara',
            departureAddress: 'Kadikoy',
            arrivalAddress: 'Kizilay',
            departureLat: 41.01,
            departureLng: 29.0,
            arrivalLat: 39.92,
            arrivalLng: 32.85,
            departureTime: '2026-02-09T08:00:00Z',
            availableSeats: 3,
            pricePerSeat: 150,
        });

        expect(result.id).toBe('trip-1');
    });

    it('rejects coordinates outside Turkiye bounds on create', async () => {
        mockPrismaService.vehicle.findFirst.mockResolvedValue({ id: 'vehicle-1' });

        await expect(
            service.create('driver-1', {
                vehicleId: 'vehicle-1',
                type: 'people' as any,
                departureCity: 'Paris',
                arrivalCity: 'Ankara',
                departureLat: 48.85,
                departureLng: 2.35,
                arrivalLat: 39.92,
                arrivalLng: 32.85,
                departureTime: '2026-02-09T08:00:00Z',
                availableSeats: 3,
                pricePerSeat: 150,
            }),
        ).rejects.toThrow(BadRequestException);
    });

    it('rejects partial coordinates on update', async () => {
        mockPrismaService.trip.findUnique.mockResolvedValue({
            id: 'trip-1',
            driverId: 'driver-1',
        });

        await expect(
            service.update('trip-1', 'driver-1', {
                departureLat: 41.01,
            }),
        ).rejects.toThrow(BadRequestException);
    });

    it('builds route preview by geocoding departure and arrival city names', async () => {
        jest.spyOn(service as any, 'forwardGeocodeCity').mockImplementation(async (query: string) => {
            if (query === 'Istanbul') return { lat: 41.0082, lng: 28.9784 };
            if (query === 'Ankara') return { lat: 39.9208, lng: 32.8541 };
            return null;
        });
        jest.spyOn(service as any, 'inferViaCities').mockResolvedValue([
            { city: 'Eskisehir', district: 'Odunpazari', pickupSuggestions: ['Otogar'] },
        ]);
        jest.spyOn(axios, 'get').mockResolvedValue({
            data: {
                routes: [
                    {
                        distance: 451_200,
                        duration: 17_400,
                        geometry: {
                            coordinates: [
                                [28.9784, 41.0082],
                                [30.5, 40.6],
                                [32.8541, 39.9208],
                            ],
                        },
                    },
                ],
            },
        } as any);

        const result = await service.routePreview({
            departureCity: 'Istanbul',
            arrivalCity: 'Ankara',
        });

        expect(result.alternatives).toHaveLength(1);
        expect(result.alternatives[0].id).toBe('route_1');
        expect(result.alternatives[0].route.points).toHaveLength(3);
        expect(result.alternatives[0].viaCities).toHaveLength(1);
    });

    it('rejects route preview when no departure/arrival info is provided', async () => {
        await expect(
            service.routePreview({}),
        ).rejects.toThrow(BadRequestException);
    });
});
