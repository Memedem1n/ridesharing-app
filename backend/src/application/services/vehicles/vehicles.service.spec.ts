import { BadRequestException, ConflictException } from '@nestjs/common';
import { Test, TestingModule } from '@nestjs/testing';
import { PrismaService } from '@infrastructure/database/prisma.service';
import { VehiclesService } from './vehicles.service';
import {
    VehicleOwnerRelation,
    VehicleOwnershipType,
} from '@application/dto/vehicles/vehicles.dto';

describe('VehiclesService', () => {
    let service: VehiclesService;

    const mockPrismaService = {
        user: {
            findUnique: jest.fn(),
        },
        vehicle: {
            findUnique: jest.fn(),
            findFirst: jest.fn(),
            create: jest.fn(),
            findMany: jest.fn(),
            update: jest.fn(),
            delete: jest.fn(),
        },
        trip: {
            count: jest.fn().mockResolvedValue(0),
        },
    };

    const baseVehicle = {
        id: 'vehicle-1',
        userId: 'user-1',
        licensePlate: '34ABC123',
        registrationNumber: '34-AB-123456',
        ownershipType: VehicleOwnershipType.SELF,
        ownerFullName: null,
        ownerRelation: null,
        brand: 'Toyota',
        model: 'Corolla',
        year: 2020,
        color: 'White',
        seats: 4,
        hasAc: true,
        allowsPets: false,
        allowsSmoking: false,
        verified: false,
        registrationImage: '/uploads/registrations/car-1.png',
        createdAt: new Date('2026-02-10T10:00:00Z'),
    };

    beforeEach(async () => {
        const module: TestingModule = await Test.createTestingModule({
            providers: [
                VehiclesService,
                { provide: PrismaService, useValue: mockPrismaService },
            ],
        }).compile();

        service = module.get<VehiclesService>(VehiclesService);
        jest.clearAllMocks();
    });

    it('requires owner fields when ownership type is relative', async () => {
        mockPrismaService.user.findUnique.mockResolvedValue({
            fullName: 'Ali Yilmaz',
        });

        await expect(
            service.create('user-1', {
                licensePlate: '34abc123',
                registrationNumber: '34-ab-123456',
                ownershipType: VehicleOwnershipType.RELATIVE,
                registrationImage: '/uploads/registrations/car-1.png',
                brand: 'Toyota',
                model: 'Corolla',
                year: 2020,
                seats: 4,
            } as any),
        ).rejects.toThrow(BadRequestException);
    });

    it('rejects relative ownership when owner surname does not match user surname', async () => {
        mockPrismaService.user.findUnique.mockResolvedValue({
            fullName: 'Ali Yilmaz',
        });

        await expect(
            service.create('user-1', {
                licensePlate: '34abc123',
                registrationNumber: '34-ab-123456',
                ownershipType: VehicleOwnershipType.RELATIVE,
                ownerFullName: 'Mehmet Demir',
                ownerRelation: VehicleOwnerRelation.FATHER,
                registrationImage: '/uploads/registrations/car-1.png',
                brand: 'Toyota',
                model: 'Corolla',
                year: 2020,
                seats: 4,
            } as any),
        ).rejects.toThrow(BadRequestException);
    });

    it('rejects create when registration number already exists', async () => {
        mockPrismaService.user.findUnique.mockResolvedValue({
            fullName: 'Ali Yilmaz',
        });
        mockPrismaService.vehicle.findUnique
            .mockResolvedValueOnce(null)
            .mockResolvedValueOnce({ id: 'vehicle-2' });

        await expect(
            service.create('user-1', {
                licensePlate: '34abc123',
                registrationNumber: '34-ab-123456',
                ownershipType: VehicleOwnershipType.SELF,
                registrationImage: '/uploads/registrations/car-1.png',
                brand: 'Toyota',
                model: 'Corolla',
                year: 2020,
                seats: 4,
            } as any),
        ).rejects.toThrow(ConflictException);
    });

    it('normalizes plate and registration number on create', async () => {
        mockPrismaService.user.findUnique.mockResolvedValue({
            fullName: 'Ali Yilmaz',
        });
        mockPrismaService.vehicle.findUnique
            .mockResolvedValueOnce(null)
            .mockResolvedValueOnce(null);
        mockPrismaService.vehicle.create.mockImplementation(async ({ data }: any) => ({
            ...baseVehicle,
            ...data,
        }));

        const result = await service.create('user-1', {
            licensePlate: '34abc123',
            registrationNumber: '34-ab-123456',
            ownershipType: VehicleOwnershipType.SELF,
            registrationImage: '/uploads/registrations/car-1.png',
            brand: 'Toyota',
            model: 'Corolla',
            year: 2020,
            seats: 4,
        } as any);

        expect(result.licensePlate).toBe('34ABC123');
        expect(result.registrationNumber).toBe('34-AB-123456');
        expect(mockPrismaService.vehicle.create).toHaveBeenCalledWith(
            expect.objectContaining({
                data: expect.objectContaining({
                    licensePlate: '34ABC123',
                    registrationNumber: '34-AB-123456',
                }),
            }),
        );
    });

    it('rejects update when registration number is empty', async () => {
        mockPrismaService.vehicle.findUnique.mockResolvedValue(baseVehicle);
        mockPrismaService.user.findUnique.mockResolvedValue({
            fullName: 'Ali Yilmaz',
        });

        await expect(
            service.update('vehicle-1', 'user-1', {
                registrationNumber: '   ',
            } as any),
        ).rejects.toThrow(BadRequestException);
    });

    it('rejects update when registration number belongs to another vehicle', async () => {
        mockPrismaService.vehicle.findUnique.mockResolvedValue(baseVehicle);
        mockPrismaService.user.findUnique.mockResolvedValue({
            fullName: 'Ali Yilmaz',
        });
        mockPrismaService.vehicle.findFirst.mockResolvedValue({ id: 'vehicle-2' });

        await expect(
            service.update('vehicle-1', 'user-1', {
                registrationNumber: '34-xy-999999',
            } as any),
        ).rejects.toThrow(ConflictException);
    });

    it('rejects update when relative owner surname does not match', async () => {
        mockPrismaService.vehicle.findUnique.mockResolvedValue(baseVehicle);
        mockPrismaService.user.findUnique.mockResolvedValue({
            fullName: 'Ali Yilmaz',
        });

        await expect(
            service.update('vehicle-1', 'user-1', {
                ownershipType: VehicleOwnershipType.RELATIVE,
                ownerFullName: 'Ayse Demir',
                ownerRelation: VehicleOwnerRelation.MOTHER,
            } as any),
        ).rejects.toThrow(BadRequestException);
    });
});
