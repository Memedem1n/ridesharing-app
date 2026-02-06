import { Injectable, NotFoundException, ConflictException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '@infrastructure/database/prisma.service';
import { CreateVehicleDto, UpdateVehicleDto, VehicleResponseDto } from '@application/dto/vehicles/vehicles.dto';
import { v4 as uuid } from 'uuid';

@Injectable()
export class VehiclesService {
    constructor(private readonly prisma: PrismaService) { }

    async create(userId: string, dto: CreateVehicleDto): Promise<VehicleResponseDto> {
        // Check if license plate exists
        const existing = await this.prisma.vehicle.findUnique({
            where: { licensePlate: dto.licensePlate },
        });

        if (existing) {
            throw new ConflictException('Bu plaka zaten kayıtlı');
        }

        const vehicle = await this.prisma.vehicle.create({
            data: {
                id: uuid(),
                userId,
                licensePlate: dto.licensePlate.toUpperCase(),
                brand: dto.brand,
                model: dto.model,
                year: dto.year,
                color: dto.color,
                seats: dto.seats,
                hasAc: dto.hasAc ?? true,
                allowsPets: dto.allowsPets ?? false,
                allowsSmoking: dto.allowsSmoking ?? false,
            },
        });

        return this.mapToResponse(vehicle);
    }

    async findByUser(userId: string): Promise<VehicleResponseDto[]> {
        const vehicles = await this.prisma.vehicle.findMany({
            where: { userId },
            orderBy: { createdAt: 'desc' },
        });

        return vehicles.map(v => this.mapToResponse(v));
    }

    async findById(id: string, userId: string): Promise<VehicleResponseDto> {
        const vehicle = await this.prisma.vehicle.findUnique({
            where: { id },
        });

        if (!vehicle) {
            throw new NotFoundException('Araç bulunamadı');
        }

        if (vehicle.userId !== userId) {
            throw new ForbiddenException('Bu araca erişim yetkiniz yok');
        }

        return this.mapToResponse(vehicle);
    }

    async update(id: string, userId: string, dto: UpdateVehicleDto): Promise<VehicleResponseDto> {
        const vehicle = await this.prisma.vehicle.findUnique({
            where: { id },
        });

        if (!vehicle) {
            throw new NotFoundException('Araç bulunamadı');
        }

        if (vehicle.userId !== userId) {
            throw new ForbiddenException('Bu aracı düzenleme yetkiniz yok');
        }

        const updated = await this.prisma.vehicle.update({
            where: { id },
            data: {
                ...(dto.color !== undefined && { color: dto.color }),
                ...(dto.seats !== undefined && { seats: dto.seats }),
                ...(dto.hasAc !== undefined && { hasAc: dto.hasAc }),
                ...(dto.allowsPets !== undefined && { allowsPets: dto.allowsPets }),
                ...(dto.allowsSmoking !== undefined && { allowsSmoking: dto.allowsSmoking }),
                ...(dto.registrationImage !== undefined && { registrationImage: dto.registrationImage }),
            },
        });

        return this.mapToResponse(updated);
    }

    async delete(id: string, userId: string): Promise<void> {
        const vehicle = await this.prisma.vehicle.findUnique({
            where: { id },
        });

        if (!vehicle) {
            throw new NotFoundException('Araç bulunamadı');
        }

        if (vehicle.userId !== userId) {
            throw new ForbiddenException('Bu aracı silme yetkiniz yok');
        }

        // Check if vehicle has active trips
        const activeTrips = await this.prisma.trip.count({
            where: {
                vehicleId: id,
                status: { in: ['published', 'in_progress'] },
            },
        });

        if (activeTrips > 0) {
            throw new ConflictException('Bu aracın aktif yolculukları var');
        }

        await this.prisma.vehicle.delete({
            where: { id },
        });
    }

    private mapToResponse(vehicle: any): VehicleResponseDto {
        return {
            id: vehicle.id,
            licensePlate: vehicle.licensePlate,
            brand: vehicle.brand,
            model: vehicle.model,
            year: vehicle.year,
            color: vehicle.color,
            seats: vehicle.seats,
            hasAc: vehicle.hasAc,
            allowsPets: vehicle.allowsPets,
            allowsSmoking: vehicle.allowsSmoking,
            verified: vehicle.verified,
            registrationImage: vehicle.registrationImage,
            createdAt: vehicle.createdAt,
        };
    }
}
