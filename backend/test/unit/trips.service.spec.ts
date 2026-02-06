import { Test, TestingModule } from '@nestjs/testing';
import { TripsService } from '@application/services/trips/trips.service';
import { PrismaService } from '@infrastructure/database/prisma.service';
import { NotFoundException, BadRequestException, ForbiddenException } from '@nestjs/common';

describe('TripsService', () => {
    let service: TripsService;

    const mockPrismaService = {
        trip: {
            findMany: jest.fn(),
            findUnique: jest.fn(),
            create: jest.fn(),
            update: jest.fn(),
            count: jest.fn(),
        },
        vehicle: {
            findFirst: jest.fn(),
        },
    };

    const mockTrip = {
        id: 'trip-1',
        driverId: 'driver-1',
        vehicleId: 'vehicle-1',
        status: 'published',
        type: 'people',
        departureCity: 'İstanbul',
        arrivalCity: 'Ankara',
        departureTime: new Date('2026-02-10T09:00:00Z'),
        availableSeats: 3,
        pricePerSeat: 150,
        allowsPets: false,
        womenOnly: false,
        driver: {
            id: 'driver-1',
            fullName: 'Test Driver',
            ratingAvg: 4.5,
            totalTrips: 10,
        },
        vehicle: {
            id: 'vehicle-1',
            brand: 'Toyota',
            model: 'Corolla',
            licensePlate: '34ABC123',
        },
        createdAt: new Date(),
    };

    beforeEach(async () => {
        const module: TestingModule = await Test.createTestingModule({
            providers: [
                TripsService,
                { provide: PrismaService, useValue: mockPrismaService },
            ],
        }).compile();

        service = module.get<TripsService>(TripsService);
        jest.clearAllMocks();
    });

    describe('create', () => {
        const createDto = {
            vehicleId: 'vehicle-1',
            type: 'people' as any,
            departureCity: 'İstanbul',
            arrivalCity: 'Ankara',
            departureTime: '2026-02-10T09:00:00Z',
            availableSeats: 3,
            pricePerSeat: 150,
        };

        it('should create a trip successfully', async () => {
            mockPrismaService.vehicle.findFirst.mockResolvedValue({ id: 'vehicle-1' });
            mockPrismaService.trip.create.mockResolvedValue(mockTrip);

            const result = await service.create('driver-1', createDto);

            expect(result).toHaveProperty('id');
            expect(result.departureCity).toBe('İstanbul');
        });

        it('should throw BadRequestException for invalid vehicle', async () => {
            mockPrismaService.vehicle.findFirst.mockResolvedValue(null);

            await expect(service.create('driver-1', createDto)).rejects.toThrow(BadRequestException);
        });
    });

    describe('findAll', () => {
        it('should return paginated trips', async () => {
            mockPrismaService.trip.findMany.mockResolvedValue([mockTrip]);
            mockPrismaService.trip.count.mockResolvedValue(1);

            const result = await service.findAll({
                from: 'İstanbul',
                to: 'Ankara',
                page: 1,
                limit: 20,
            });

            expect(result.trips).toHaveLength(1);
            expect(result.total).toBe(1);
            expect(result.totalPages).toBe(1);
        });

        it('should filter by seats', async () => {
            mockPrismaService.trip.findMany.mockResolvedValue([mockTrip]);
            mockPrismaService.trip.count.mockResolvedValue(1);

            await service.findAll({ seats: 2 });

            expect(mockPrismaService.trip.findMany).toHaveBeenCalledWith(
                expect.objectContaining({
                    where: expect.objectContaining({
                        availableSeats: { gte: 2 },
                    }),
                }),
            );
        });
    });

    describe('findById', () => {
        it('should return trip by id', async () => {
            mockPrismaService.trip.findUnique.mockResolvedValue({
                ...mockTrip,
                bookings: [],
            });

            const result = await service.findById('trip-1');

            expect(result.id).toBe('trip-1');
        });

        it('should throw NotFoundException for non-existent trip', async () => {
            mockPrismaService.trip.findUnique.mockResolvedValue(null);

            await expect(service.findById('non-existent')).rejects.toThrow(NotFoundException);
        });
    });

    describe('update', () => {
        it('should update trip successfully by owner', async () => {
            mockPrismaService.trip.findUnique.mockResolvedValue(mockTrip);
            mockPrismaService.trip.update.mockResolvedValue({
                ...mockTrip,
                pricePerSeat: 180,
            });

            const result = await service.update('trip-1', 'driver-1', { pricePerSeat: 180 });

            expect(result.pricePerSeat).toBe(180);
        });

        it('should throw ForbiddenException for non-owner', async () => {
            mockPrismaService.trip.findUnique.mockResolvedValue(mockTrip);

            await expect(
                service.update('trip-1', 'other-user', { pricePerSeat: 180 }),
            ).rejects.toThrow(ForbiddenException);
        });
    });

    describe('cancel', () => {
        it('should cancel trip by owner', async () => {
            mockPrismaService.trip.findUnique.mockResolvedValue(mockTrip);
            mockPrismaService.trip.update.mockResolvedValue({});

            await expect(service.cancel('trip-1', 'driver-1')).resolves.not.toThrow();
        });

        it('should throw ForbiddenException for non-owner', async () => {
            mockPrismaService.trip.findUnique.mockResolvedValue(mockTrip);

            await expect(service.cancel('trip-1', 'other-user')).rejects.toThrow(ForbiddenException);
        });
    });
});
