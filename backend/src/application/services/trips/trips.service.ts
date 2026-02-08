import { Injectable, NotFoundException, ForbiddenException, BadRequestException, Logger } from '@nestjs/common';
import { PrismaService } from '@infrastructure/database/prisma.service';
import { BusPriceScraperService } from '@infrastructure/scraper/bus-price-scraper.service';
import { RedisService } from '@infrastructure/cache/redis.service';
import { FcmService } from '@infrastructure/notifications/fcm.service';
import { NetgsmService } from '@infrastructure/notifications/netgsm.service';
import { ConfigService } from '@nestjs/config';
import { IyzicoService } from '@infrastructure/payment/iyzico.service';
import {
    CreateTripDto,
    UpdateTripDto,
    SearchTripsDto,
    TripResponseDto,
    TripListResponseDto,
} from '@application/dto/trips/trips.dto';
import { v4 as uuid } from 'uuid';

@Injectable()
export class TripsService {
    private readonly logger = new Logger(TripsService.name);
    private readonly searchCacheTtl: number;
    private searchCache = new Map<string, { value: TripListResponseDto; expiresAt: number }>();
    private readonly turkeyBounds = {
        minLat: 35.8,
        maxLat: 42.2,
        minLng: 25.6,
        maxLng: 44.9,
    };

    constructor(
        private readonly prisma: PrismaService,
        private readonly busPriceScraper: BusPriceScraperService,
        private readonly redisService: RedisService,
        private readonly fcmService: FcmService,
        private readonly netgsmService: NetgsmService,
        private readonly configService: ConfigService,
        private readonly iyzicoService: IyzicoService,
    ) {
        const ttlRaw = this.configService.get('TRIP_SEARCH_CACHE_TTL_SECONDS');
        const ttlValue = ttlRaw === undefined ? 120 : Number(ttlRaw);
        this.searchCacheTtl = Number.isFinite(ttlValue) ? ttlValue : 120;
    }

    async create(userId: string, dto: CreateTripDto): Promise<TripResponseDto> {
        // Verify vehicle belongs to user
        const vehicle = await this.prisma.vehicle.findFirst({
            where: { id: dto.vehicleId, userId },
        });

        if (!vehicle) {
            throw new BadRequestException('Bu araca erişim yetkiniz yok');
        }

        this.validateTripCoordinates(
            dto.departureLat,
            dto.departureLng,
            dto.arrivalLat,
            dto.arrivalLng,
        );

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
                description: dto.description,
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
        const cacheKey = this.buildSearchCacheKey(query);
        const cached = await this.getSearchCache(cacheKey);
        if (cached) {
            return cached;
        }

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

        const result: TripListResponseDto = {
            trips: trips.map(trip => this.mapToResponse(trip)),
            total,
            page,
            limit,
            totalPages: Math.ceil(total / limit),
        };

        await this.setSearchCache(cacheKey, result);
        return result;
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

        this.validateTripCoordinates(
            dto.departureLat,
            dto.departureLng,
            dto.arrivalLat,
            dto.arrivalLng,
        );

        const updated = await this.prisma.trip.update({
            where: { id },
            data: {
                ...(dto.availableSeats !== undefined && { availableSeats: dto.availableSeats }),
                ...(dto.pricePerSeat !== undefined && { pricePerSeat: dto.pricePerSeat }),
                ...(dto.status && { status: dto.status as any }),
                ...(dto.departureAddress && { departureAddress: dto.departureAddress }),
                ...(dto.arrivalAddress && { arrivalAddress: dto.arrivalAddress }),
                ...(dto.departureLat !== undefined && { departureLat: dto.departureLat }),
                ...(dto.departureLng !== undefined && { departureLng: dto.departureLng }),
                ...(dto.arrivalLat !== undefined && { arrivalLat: dto.arrivalLat }),
                ...(dto.arrivalLng !== undefined && { arrivalLng: dto.arrivalLng }),
            },
            include: {
                driver: true,
                vehicle: true,
            },
        });

        await this.notifyTripUpdated(updated);
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

        await this.cancelTripBookings(trip.id, trip.departureCity, trip.arrivalCity);
    }

    private async cancelTripBookings(tripId: string, from: string, to: string): Promise<void> {
        const bookings = await this.prisma.booking.findMany({
            where: {
                tripId,
                status: { in: ['pending', 'confirmed', 'checked_in'] },
            },
            include: {
                passenger: true,
            },
        });

        for (const booking of bookings) {
            let refundAmount = 0;
            if (booking.paymentStatus === 'paid' && booking.paymentId) {
                try {
                    const refund = await this.iyzicoService.refundPayment(
                        booking.paymentId,
                        Number(booking.priceTotal),
                        'Sürücü iptali',
                    );
                    if (refund.success) {
                        refundAmount = Number(booking.priceTotal);
                    }
                } catch {
                    refundAmount = 0;
                }
            }

            await this.prisma.booking.update({
                where: { id: booking.id },
                data: {
                    status: 'cancelled_by_driver',
                    cancellationTime: new Date(),
                    cancellationPenalty: 0,
                    paymentStatus: refundAmount > 0 ? 'refunded' : booking.paymentStatus,
                    expiresAt: null,
                },
            });

            await this.notifyTripCancelled(booking.passenger, { from, to }, refundAmount);
        }
    }

    private async notifyTripUpdated(trip: any): Promise<void> {
        const bookings = await this.prisma.booking.findMany({
            where: {
                tripId: trip.id,
                status: { in: ['pending', 'confirmed', 'checked_in'] },
            },
            include: { passenger: true },
        });

        if (!bookings.length) return;

        try {
            await Promise.all(bookings.map(async (booking) => {
                const passenger = booking.passenger;
                const tokens = this.extractDeviceTokens(passenger?.preferences);

                if (tokens.length > 0) {
                    await Promise.all(tokens.map((token) =>
                        this.fcmService.notifyTripUpdated(token, {
                            from: trip.departureCity,
                            to: trip.arrivalCity,
                            tripId: trip.id,
                        })
                    ));
                }

                if (passenger?.phone) {
                    await this.netgsmService.sendTripUpdated(passenger.phone, {
                        from: trip.departureCity,
                        to: trip.arrivalCity,
                    });
                }
            }));
        } catch {
            // Ignore notification errors
        }
    }

    private async notifyTripCancelled(passenger: any, tripInfo: { from: string; to: string }, refundAmount: number) {
        try {
            const tokens = this.extractDeviceTokens(passenger?.preferences);
            if (tokens.length > 0) {
                await Promise.all(tokens.map((token) =>
                    this.fcmService.notifyTripCancelled(token, { from: tripInfo.from, to: tripInfo.to })
                ));
            }

            if (passenger?.phone) {
                await this.netgsmService.sendTripCancelled(passenger.phone, tripInfo);
                if (refundAmount > 0) {
                    await this.netgsmService.sendCancellationNotice(passenger.phone, refundAmount);
                }
            }
        } catch {
            // Ignore notification errors
        }
    }

    private async getBusReferencePrice(from: string, to: string): Promise<number | null> {
        return this.busPriceScraper.getPrice(from, to);
    }

    private buildSearchCacheKey(query: SearchTripsDto): string {
        const keyPayload = {
            from: query.from?.toLowerCase() || '',
            to: query.to?.toLowerCase() || '',
            date: query.date || '',
            seats: query.seats || '',
            type: query.type || '',
            allowsPets: query.allowsPets ?? '',
            womenOnly: query.womenOnly ?? '',
            page: query.page || 1,
            limit: query.limit || 20,
        };
        return `trips:search:${Buffer.from(JSON.stringify(keyPayload)).toString('base64')}`;
    }

    private async getSearchCache(key: string): Promise<TripListResponseDto | null> {
        if (!this.searchCacheTtl) return null;

        if (this.redisService.isConfigured()) {
            return this.redisService.getJson<TripListResponseDto>(key);
        }

        const cached = this.searchCache.get(key);
        if (!cached) return null;
        if (cached.expiresAt < Date.now()) {
            this.searchCache.delete(key);
            return null;
        }
        return cached.value;
    }

    private async setSearchCache(key: string, value: TripListResponseDto): Promise<void> {
        if (!this.searchCacheTtl) return;

        if (this.redisService.isConfigured()) {
            await this.redisService.setJson(key, value, this.searchCacheTtl);
            return;
        }

        this.searchCache.set(key, {
            value,
            expiresAt: Date.now() + this.searchCacheTtl * 1000,
        });
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
            allowsCargo: trip.allowsCargo,
            womenOnly: trip.womenOnly,
            instantBooking: trip.instantBooking,
            description: trip.description ?? undefined,
            distanceKm: trip.distanceKm ? Number(trip.distanceKm) : undefined,
            createdAt: trip.createdAt,
        };
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

    private validateTripCoordinates(
        departureLat?: number,
        departureLng?: number,
        arrivalLat?: number,
        arrivalLng?: number,
    ): void {
        this.validateCoordinatePair('kalkis', departureLat, departureLng);
        this.validateCoordinatePair('varis', arrivalLat, arrivalLng);
    }

    private validateCoordinatePair(label: string, lat?: number, lng?: number): void {
        const hasLat = lat !== undefined && lat !== null;
        const hasLng = lng !== undefined && lng !== null;

        if (!hasLat && !hasLng) {
            return;
        }

        if (!hasLat || !hasLng) {
            throw new BadRequestException(`${label} koordinatlari eksik`);
        }

        if (!this.isWithinTurkey(lat!, lng!)) {
            throw new BadRequestException(`${label} koordinatlari Turkiye disinda`);
        }
    }

    private isWithinTurkey(lat: number, lng: number): boolean {
        return lat >= this.turkeyBounds.minLat
            && lat <= this.turkeyBounds.maxLat
            && lng >= this.turkeyBounds.minLng
            && lng <= this.turkeyBounds.maxLng;
    }
}




