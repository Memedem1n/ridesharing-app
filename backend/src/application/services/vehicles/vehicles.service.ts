import {
    Injectable,
    NotFoundException,
    ConflictException,
    ForbiddenException,
    BadRequestException,
} from '@nestjs/common';
import { PrismaService } from '@infrastructure/database/prisma.service';
import {
    CreateVehicleDto,
    UpdateVehicleDto,
    VehicleResponseDto,
    VehicleOwnershipType,
    VehicleOwnerRelation,
} from '@application/dto/vehicles/vehicles.dto';
import { v4 as uuid } from 'uuid';

@Injectable()
export class VehiclesService {
    constructor(private readonly prisma: PrismaService) { }

    async create(userId: string, dto: CreateVehicleDto): Promise<VehicleResponseDto> {
        const user = await this.prisma.user.findUnique({
            where: { id: userId },
            select: { fullName: true },
        });

        const normalizedPlate = dto.licensePlate.trim().toUpperCase();
        const normalizedRegistrationNumber = dto.registrationNumber.trim().toUpperCase();
        const ownershipType = dto.ownershipType ?? VehicleOwnershipType.SELF;
        const ownerFullName = dto.ownerFullName?.trim();
        const ownerRelation = dto.ownerRelation?.trim();
        const registrationImage = dto.registrationImage?.trim();

        if (!normalizedRegistrationNumber) {
            throw new BadRequestException('Ruhsat numarasi zorunludur');
        }
        if (!registrationImage) {
            throw new BadRequestException('Ruhsat gorseli zorunludur');
        }
        this.assertOwnershipFields(
            ownershipType,
            ownerFullName,
            ownerRelation,
            user?.fullName,
        );

        const existing = await this.prisma.vehicle.findUnique({
            where: { licensePlate: normalizedPlate },
            select: { id: true },
        });
        if (existing) {
            throw new ConflictException('Bu plaka zaten kayitli');
        }

        const existingRegistration = await this.prisma.vehicle.findUnique({
            where: { registrationNumber: normalizedRegistrationNumber },
            select: { id: true },
        });
        if (existingRegistration) {
            throw new ConflictException('Bu ruhsat numarasi zaten kayitli');
        }

        const vehicle = await this.prisma.vehicle.create({
            data: {
                id: uuid(),
                userId,
                licensePlate: normalizedPlate,
                registrationNumber: normalizedRegistrationNumber,
                ownershipType,
                ownerFullName:
                    ownershipType === VehicleOwnershipType.RELATIVE
                        ? ownerFullName
                        : null,
                ownerRelation:
                    ownershipType === VehicleOwnershipType.RELATIVE
                        ? ownerRelation
                        : null,
                brand: dto.brand,
                model: dto.model,
                year: dto.year,
                color: dto.color,
                seats: dto.seats,
                hasAc: dto.hasAc ?? true,
                allowsPets: dto.allowsPets ?? false,
                allowsSmoking: dto.allowsSmoking ?? false,
                registrationImage,
            },
        });

        return this.mapToResponse(vehicle);
    }

    async findByUser(userId: string): Promise<VehicleResponseDto[]> {
        const vehicles = await this.prisma.vehicle.findMany({
            where: { userId },
            orderBy: { createdAt: 'desc' },
        });

        return vehicles.map((v) => this.mapToResponse(v));
    }

    async findById(id: string, userId: string): Promise<VehicleResponseDto> {
        const vehicle = await this.prisma.vehicle.findUnique({
            where: { id },
        });

        if (!vehicle) {
            throw new NotFoundException('Arac bulunamadi');
        }

        if (vehicle.userId !== userId) {
            throw new ForbiddenException('Bu araca erisim yetkiniz yok');
        }

        return this.mapToResponse(vehicle);
    }

    async update(id: string, userId: string, dto: UpdateVehicleDto): Promise<VehicleResponseDto> {
        const vehicle = await this.prisma.vehicle.findUnique({
            where: { id },
        });

        if (!vehicle) {
            throw new NotFoundException('Arac bulunamadi');
        }

        if (vehicle.userId !== userId) {
            throw new ForbiddenException('Bu araci duzenleme yetkiniz yok');
        }

        const user = await this.prisma.user.findUnique({
            where: { id: userId },
            select: { fullName: true },
        });

        const rawOwnershipType = dto.ownershipType ?? vehicle.ownershipType;
        const nextOwnershipType =
            rawOwnershipType === VehicleOwnershipType.RELATIVE
                ? VehicleOwnershipType.RELATIVE
                : VehicleOwnershipType.SELF;
        const nextOwnerFullName = dto.ownerFullName !== undefined
            ? dto.ownerFullName?.trim()
            : vehicle.ownerFullName;
        const nextOwnerRelation = dto.ownerRelation !== undefined
            ? dto.ownerRelation?.trim()
            : vehicle.ownerRelation;
        this.assertOwnershipFields(
            nextOwnershipType,
            nextOwnerFullName,
            nextOwnerRelation,
            user?.fullName,
        );

        let normalizedRegistrationNumber: string | undefined;
        if (dto.registrationNumber !== undefined) {
            normalizedRegistrationNumber = dto.registrationNumber.trim().toUpperCase();
            if (!normalizedRegistrationNumber) {
                throw new BadRequestException('Ruhsat numarasi bos olamaz');
            }
            const duplicate = await this.prisma.vehicle.findFirst({
                where: {
                    registrationNumber: normalizedRegistrationNumber,
                    id: { not: id },
                },
                select: { id: true },
            });
            if (duplicate) {
                throw new ConflictException('Bu ruhsat numarasi zaten kayitli');
            }
        }

        const updated = await this.prisma.vehicle.update({
            where: { id },
            data: {
                ...(dto.color !== undefined && { color: dto.color }),
                ...(dto.seats !== undefined && { seats: dto.seats }),
                ...(dto.hasAc !== undefined && { hasAc: dto.hasAc }),
                ...(dto.allowsPets !== undefined && { allowsPets: dto.allowsPets }),
                ...(dto.allowsSmoking !== undefined && { allowsSmoking: dto.allowsSmoking }),
                ...(dto.registrationImage !== undefined && {
                    registrationImage: dto.registrationImage?.trim() || null,
                }),
                ...(dto.ownershipType !== undefined && { ownershipType: dto.ownershipType }),
                ...(dto.ownerFullName !== undefined && {
                    ownerFullName: dto.ownerFullName?.trim() || null,
                }),
                ...(dto.ownerRelation !== undefined && {
                    ownerRelation: dto.ownerRelation?.trim() || null,
                }),
                ...(normalizedRegistrationNumber !== undefined && {
                    registrationNumber: normalizedRegistrationNumber,
                }),
            },
        });

        return this.mapToResponse(updated);
    }

    async delete(id: string, userId: string): Promise<void> {
        const vehicle = await this.prisma.vehicle.findUnique({
            where: { id },
        });

        if (!vehicle) {
            throw new NotFoundException('Arac bulunamadi');
        }

        if (vehicle.userId !== userId) {
            throw new ForbiddenException('Bu araci silme yetkiniz yok');
        }

        const activeTrips = await this.prisma.trip.count({
            where: {
                vehicleId: id,
                status: { in: ['published', 'in_progress'] },
            },
        });

        if (activeTrips > 0) {
            throw new ConflictException('Bu aracin aktif yolculuklari var');
        }

        await this.prisma.vehicle.delete({
            where: { id },
        });
    }

    private assertOwnershipFields(
        ownershipType: VehicleOwnershipType,
        ownerFullName?: string | null,
        ownerRelation?: string | null,
        userFullName?: string | null,
    ): void {
        if (ownershipType !== VehicleOwnershipType.RELATIVE) {
            return;
        }

        if (!ownerFullName || !ownerRelation) {
            throw new BadRequestException(
                'Arac size ait degilse akraba bilgileri zorunludur',
            );
        }

        const allowedRelations = new Set<string>(
            Object.values(VehicleOwnerRelation),
        );
        if (!allowedRelations.has(ownerRelation)) {
            throw new BadRequestException('Yakinlik derecesi gecersiz');
        }

        const ownerSurname = this.extractSurname(ownerFullName);
        const userSurname = userFullName ? this.extractSurname(userFullName) : null;

        if (!userSurname) {
            throw new BadRequestException(
                'Profil soyad bilgisi eksik. Lutfen profil adinizi soyad seklinde guncelleyin.',
            );
        }
        if (!ownerSurname) {
            throw new BadRequestException('Arac sahibi ad soyad girilmelidir');
        }

        if (this.normalizeTrKey(ownerSurname) !== this.normalizeTrKey(userSurname)) {
            throw new BadRequestException(
                'Arac sahibi soyadi sizin soyadinizla eslesmelidir',
            );
        }
    }

    private extractSurname(fullName: string): string | null {
        const normalized = String(fullName || '').trim();
        if (!normalized) return null;
        const parts = normalized.split(/\s+/).filter(Boolean);
        if (parts.length < 2) return null;
        return parts[parts.length - 1] ?? null;
    }

    private normalizeTrKey(value: string): string {
        return String(value || '')
            .trim()
            .toLocaleLowerCase('tr-TR')
            .normalize('NFKD')
            .replace(/[\u0300-\u036f]/g, '')
            .replace(/ı/g, 'i');
    }

    private mapToResponse(vehicle: any): VehicleResponseDto {
        return {
            id: vehicle.id,
            licensePlate: vehicle.licensePlate,
            registrationNumber: vehicle.registrationNumber ?? undefined,
            ownershipType: vehicle.ownershipType,
            ownerFullName: vehicle.ownerFullName,
            ownerRelation: vehicle.ownerRelation,
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
