import { Injectable, NotFoundException, ForbiddenException, BadRequestException } from '@nestjs/common';
import { PrismaService } from '@infrastructure/database/prisma.service';
import {
    CreateTripDto,
    UpdateTripDto,
    SearchTripsDto,
    TripResponseDto,
    TripListResponseDto,
    TripStatus
} from '@application/dto/trips/trips.dto';
import { v4 as uuid } from 'uuid';

@Injectable()
export class TripsService {
    constructor(private readonly prisma: PrismaService) { }

    async create(userId: string, dto: CreateTripDto): Promise<TripResponseDto> {
        // Verify vehicle belongs to user
        const vehicle = await this.prisma.vehicle.findFirst({
            where: { id: dto.vehicleId, userId },
        });

        if (!vehicle) {
            throw new BadRequestException('Bu araca erişim yetkiniz yok');
        }

        const trip = await this.prisma.trip.create({
            data: {
                id: uuid(),
                driverId: userId,
                vehicleId: dto.vehicleId,
                type: dto.type as any,
                status: 'published',
                departureCity: dto.departureCity,
                arrivalCity: dto.arrivalCity,
                departureAddress: dto.departureAddress,
                arrivalAddress: dto.arrivalAddress,
                departureLat: dto.departureLat,
                departureLng: dto.departureLng,
                arrivalLat: dto.arrivalLat,
                arrivalLng: dto.arrivalLng,
                departureTime: new Date(dto.departureTime),
                availableSeats: dto.availableSeats,
                pricePerSeat: dto.pricePerSeat,
                allowsPets: dto.allowsPets || false,
                allowsCargo: dto.allowsCargo || false,
                maxCargoWeight: dto.maxCargoWeight,
                womenOnly: dto.womenOnly || false,
                instantBooking: dto.instantBooking ?? true,
                preferences: JSON.stringify(dto.preferences || {}),
            },
            include: {
                driver: true,
                vehicle: true,
            },
        });

        return this.mapToResponse(trip);
    }

    async findAll(query: SearchTripsDto): Promise<TripListResponseDto> {
        const { from, to, date, seats, type, allowsPets, womenOnly, page = 1, limit = 20 } = query;
        const skip = (page - 1) * limit;

        const where: any = {
            status: 'published',
        };

        if (from) {
            where.departureCity = { contains: from, mode: 'insensitive' };
        }
        if (to) {
            where.arrivalCity = { contains: to, mode: 'insensitive' };
        }
        if (date) {
            const startOfDay = new Date(date);
            startOfDay.setHours(0, 0, 0, 0);
            const endOfDay = new Date(date);
            endOfDay.setHours(23, 59, 59, 999);
            where.departureTime = {
                gte: startOfDay,
                lte: endOfDay,
            };
        }
        if (seats) {
            where.availableSeats = { gte: seats };
        }
        if (type) {
            where.type = type;
        }
        if (allowsPets !== undefined) {
            where.allowsPets = allowsPets;
        }
        if (womenOnly !== undefined) {
            where.womenOnly = womenOnly;
        }

        const [trips, total] = await Promise.all([
            this.prisma.trip.findMany({
                where,
                skip,
                take: limit,
                orderBy: { departureTime: 'asc' },
                include: {
                    driver: true,
                    vehicle: true,
                },
            }),
            this.prisma.trip.count({ where }),
        ]);

        return {
            trips: trips.map(trip => this.mapToResponse(trip)),
            total,
            page,
            limit,
            totalPages: Math.ceil(total / limit),
        };
    }

    async findById(id: string): Promise<TripResponseDto> {
        const trip = await this.prisma.trip.findUnique({
            where: { id },
            include: {
                driver: true,
                vehicle: true,
                bookings: {
                    where: { status: { in: ['confirmed', 'checked_in'] } },
                    select: { seats: true },
                },
            },
        });

        if (!trip) {
            throw new NotFoundException('Yolculuk bulunamadı');
        }

        const response = this.mapToResponse(trip);

        // Get bus reference price from cache
        const busPrice = await this.getBusReferencePrice(trip.departureCity, trip.arrivalCity);
        if (busPrice) {
            response.busReferencePrice = busPrice;
        }

        return response;
    }

    async findByDriver(driverId: string): Promise<TripResponseDto[]> {
        const trips = await this.prisma.trip.findMany({
            where: { driverId },
            orderBy: { createdAt: 'desc' },
            include: {
                driver: true,
                vehicle: true,
            },
        });

        return trips.map(trip => this.mapToResponse(trip));
    }

    async update(id: string, userId: string, dto: UpdateTripDto): Promise<TripResponseDto> {
        const trip = await this.prisma.trip.findUnique({
            where: { id },
        });

        if (!trip) {
            throw new NotFoundException('Yolculuk bulunamadı');
        }

        if (trip.driverId !== userId) {
            throw new ForbiddenException('Bu yolculuğu düzenleme yetkiniz yok');
        }

        const updated = await this.prisma.trip.update({
            where: { id },
            data: {
                ...(dto.availableSeats !== undefined && { availableSeats: dto.availableSeats }),
                ...(dto.pricePerSeat !== undefined && { pricePerSeat: dto.pricePerSeat }),
                ...(dto.status && { status: dto.status as any }),
                ...(dto.departureAddress && { departureAddress: dto.departureAddress }),
                ...(dto.arrivalAddress && { arrivalAddress: dto.arrivalAddress }),
            },
            include: {
                driver: true,
                vehicle: true,
            },
        });

        return this.mapToResponse(updated);
    }

    async cancel(id: string, userId: string): Promise<void> {
        const trip = await this.prisma.trip.findUnique({
            where: { id },
        });

        if (!trip) {
            throw new NotFoundException('Yolculuk bulunamadı');
        }

        if (trip.driverId !== userId) {
            throw new ForbiddenException('Bu yolculuğu iptal etme yetkiniz yok');
        }

        await this.prisma.trip.update({
            where: { id },
            data: { status: 'cancelled' },
        });

        // TODO: Notify booked passengers
        // TODO: Process refunds
    }

    private async getBusReferencePrice(from: string, to: string): Promise<number | null> {
        // TODO: Implement Redis cache lookup
        // For now, return mock data
        const routes: Record<string, number> = {
            'istanbul-ankara': 350,
            'ankara-istanbul': 350,
            'istanbul-izmir': 300,
            'izmir-istanbul': 300,
            'ankara-izmir': 400,
            'izmir-ankara': 400,
        };

        const key = `${from.toLowerCase()}-${to.toLowerCase()}`;
        return routes[key] || null;
    }

    private mapToResponse(trip: any): TripResponseDto {
        return {
            id: trip.id,
            driverId: trip.driverId,
            driver: {
                id: trip.driver.id,
                fullName: trip.driver.fullName,
                profilePhotoUrl: trip.driver.profilePhotoUrl,
                ratingAvg: Number(trip.driver.ratingAvg),
                totalTrips: trip.driver.totalTrips,
            },
            vehicle: {
                id: trip.vehicle.id,
                brand: trip.vehicle.brand,
                model: trip.vehicle.model,
                color: trip.vehicle.color,
                licensePlate: trip.vehicle.licensePlate,
            },
            status: trip.status,
            type: trip.type,
            departureCity: trip.departureCity,
            arrivalCity: trip.arrivalCity,
            departureAddress: trip.departureAddress,
            arrivalAddress: trip.arrivalAddress,
            departureTime: trip.departureTime,
            estimatedArrivalTime: trip.estimatedArrivalTime,
            availableSeats: trip.availableSeats,
            pricePerSeat: Number(trip.pricePerSeat),
            allowsPets: trip.allowsPets,
            womenOnly: trip.womenOnly,
            distanceKm: trip.distanceKm ? Number(trip.distanceKm) : undefined,
            createdAt: trip.createdAt,
        };
    }
}
