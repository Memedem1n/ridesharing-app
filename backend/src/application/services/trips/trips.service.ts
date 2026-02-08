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
    RoutePreviewDto,
    RoutePreviewResponseDto,
    RouteAlternativeDto,
    RouteSnapshotDto,
    ViaCityDto,
    PickupPolicyDto,
    UpdateTripDto,
    SearchTripsDto,
    TripResponseDto,
    TripListResponseDto,
} from '@application/dto/trips/trips.dto';
import { v4 as uuid } from 'uuid';
import axios from 'axios';

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
    private readonly osrmBaseUrl = 'https://router.project-osrm.org';
    private readonly nominatimBaseUrl = 'https://nominatim.openstreetmap.org';

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

        const normalizedPreferences = this.buildTripPreferences(dto);

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
                preferences: JSON.stringify(normalizedPreferences),
            },
            include: {
                driver: true,
                vehicle: true,
            },
        });

        await this.invalidateSearchCache();
        return this.mapToResponse(trip);
    }

    async routePreview(dto: RoutePreviewDto): Promise<RoutePreviewResponseDto> {
        this.validateTripCoordinates(
            dto.departureLat,
            dto.departureLng,
            dto.arrivalLat,
            dto.arrivalLng,
        );

        const url = `${this.osrmBaseUrl}/route/v1/driving/${dto.departureLng},${dto.departureLat};${dto.arrivalLng},${dto.arrivalLat}`;

        try {
            const response = await axios.get(url, {
                params: {
                    alternatives: 'true',
                    overview: 'full',
                    geometries: 'geojson',
                    steps: 'false',
                },
                timeout: 10000,
                headers: {
                    'User-Agent': 'ridesharing-app/1.0',
                },
            });

            const routes = Array.isArray(response.data?.routes) ? response.data.routes : [];
            if (!routes.length) {
                throw new BadRequestException('Rota bulunamadi');
            }

            const alternatives: RouteAlternativeDto[] = [];
            for (let i = 0; i < Math.min(routes.length, 3); i += 1) {
                const route = routes[i];
                const rawCoordinates = Array.isArray(route?.geometry?.coordinates)
                    ? route.geometry.coordinates
                    : [];

                const points = rawCoordinates
                    .filter((coord: any) => Array.isArray(coord) && coord.length >= 2)
                    .map((coord: any) => ({
                        lat: Number(coord[1]),
                        lng: Number(coord[0]),
                    }))
                    .filter((point: any) => Number.isFinite(point.lat) && Number.isFinite(point.lng));

                const viaCities = await this.inferViaCities(points);
                const distanceKm = Number((Number(route.distance || 0) / 1000).toFixed(1));
                const durationMin = Number((Number(route.duration || 0) / 60).toFixed(1));

                alternatives.push({
                    id: `route_${i + 1}`,
                    route: {
                        provider: 'osrm',
                        distanceKm,
                        durationMin,
                        points,
                    },
                    viaCities,
                });
            }

            return { alternatives };
        } catch (error: any) {
            this.logger.warn(`ROUTE_PREVIEW_FAILED ${(error?.message || 'unknown')}`);
            if (error instanceof BadRequestException) {
                throw error;
            }
            throw new BadRequestException('Rota onizleme su anda olusturulamiyor');
        }
    }

    async findAll(query: SearchTripsDto): Promise<TripListResponseDto> {
        const cacheKey = this.buildSearchCacheKey(query);
        const cached = await this.getSearchCache(cacheKey);
        if (cached) {
            return cached;
        }

        const { from, to, date, seats, type, allowsPets, womenOnly } = query;
        const page = Number.isFinite(Number(query.page)) && Number(query.page) > 0
            ? Math.floor(Number(query.page))
            : 1;
        const limit = Number.isFinite(Number(query.limit)) && Number(query.limit) > 0
            ? Math.min(Math.floor(Number(query.limit)), 100)
            : 20;
        const seatsNumber = seats !== undefined && seats !== null && `${seats}`.trim() !== ''
            ? Number(seats)
            : undefined;
        if (seatsNumber !== undefined && (!Number.isFinite(seatsNumber) || seatsNumber <= 0)) {
            throw new BadRequestException('Koltuk sayisi gecersiz');
        }
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
            const startOfDay = new Date(`${date}T00:00:00.000Z`);
            const endOfDay = new Date(`${date}T23:59:59.999Z`);
            if (Number.isNaN(startOfDay.getTime()) || Number.isNaN(endOfDay.getTime())) {
                throw new BadRequestException('Tarih formati gecersiz');
            }
            where.departureTime = {
                gte: startOfDay,
                lte: endOfDay,
            };
        }
        if (seatsNumber !== undefined) {
            where.availableSeats = { gte: Math.floor(seatsNumber) };
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

    async findById(id: string, viewerId?: string): Promise<TripResponseDto> {
        const trip = await this.prisma.trip.findUnique({
            where: { id },
            include: {
                driver: true,
                vehicle: true,
                bookings: {
                    where: { status: { in: ['confirmed', 'checked_in', 'completed', 'disputed'] } },
                    include: {
                        passenger: {
                            select: {
                                id: true,
                                fullName: true,
                                profilePhotoUrl: true,
                                ratingAvg: true,
                            },
                        },
                    },
                },
            },
        });

        if (!trip) {
            throw new NotFoundException('Yolculuk bulunamadı');
        }

        const isDriverViewer = Boolean(viewerId && trip.driverId === viewerId);
        const isConfirmedPassengerViewer = Boolean(
            viewerId && trip.bookings.some((booking: any) =>
                booking.passengerId === viewerId
                && ['confirmed', 'checked_in', 'completed', 'disputed'].includes(booking.status)
            )
        );
        const canViewPassengerList = isDriverViewer || isConfirmedPassengerViewer;
        const canViewLiveLocation = isDriverViewer || isConfirmedPassengerViewer;

        const occupancy = trip.bookings.reduce((acc: { confirmedSeats: number; passengerCount: number }, booking: any) => {
            if (['confirmed', 'checked_in', 'completed', 'disputed'].includes(booking.status)) {
                acc.confirmedSeats += Number(booking.seats || 0);
                acc.passengerCount += 1;
            }
            return acc;
        }, { confirmedSeats: 0, passengerCount: 0 });

        const response = this.mapToResponse(trip, {
            canViewPassengerList,
            canViewLiveLocation,
            occupancy,
            passengers: canViewPassengerList
                ? trip.bookings.map((booking: any) => ({
                    id: booking.passenger.id,
                    fullName: booking.passenger.fullName,
                    profilePhotoUrl: booking.passenger.profilePhotoUrl || undefined,
                    ratingAvg: Number(booking.passenger.ratingAvg || 0),
                    seats: Number(booking.seats || 0),
                }))
                : undefined,
        });

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

        await this.invalidateSearchCache();
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

        await this.invalidateSearchCache();
        await this.cancelTripBookings(trip.id, trip.departureCity, trip.arrivalCity);
    }

    private async cancelTripBookings(tripId: string, from: string, to: string): Promise<void> {
        const bookings = await this.prisma.booking.findMany({
            where: {
                tripId,
                status: { in: ['pending', 'awaiting_payment', 'confirmed', 'checked_in'] },
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
                status: { in: ['pending', 'awaiting_payment', 'confirmed', 'checked_in'] },
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

    private async invalidateSearchCache(): Promise<void> {
        this.searchCache.clear();

        if (this.redisService.isConfigured()) {
            await this.redisService.delByPrefix('trips:search:');
        }
    }

    private mapToResponse(
        trip: any,
        options?: {
            occupancy?: { confirmedSeats: number; passengerCount: number };
            passengers?: Array<{ id: string; fullName: string; profilePhotoUrl?: string; ratingAvg: number; seats: number }>;
            canViewPassengerList?: boolean;
            canViewLiveLocation?: boolean;
        },
    ): TripResponseDto {
        const preferences = this.parseTripPreferences(trip.preferences);
        const route = this.normalizeRouteSnapshot(preferences.routeSnapshot);
        const viaCities = this.normalizeViaCities(preferences.viaCities);
        const pickupPolicies = this.normalizePickupPolicies(preferences.pickupPolicies);

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
            departureLat: trip.departureLat !== null && trip.departureLat !== undefined ? Number(trip.departureLat) : undefined,
            departureLng: trip.departureLng !== null && trip.departureLng !== undefined ? Number(trip.departureLng) : undefined,
            arrivalLat: trip.arrivalLat !== null && trip.arrivalLat !== undefined ? Number(trip.arrivalLat) : undefined,
            arrivalLng: trip.arrivalLng !== null && trip.arrivalLng !== undefined ? Number(trip.arrivalLng) : undefined,
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
            route,
            viaCities,
            pickupPolicies,
            occupancy: options?.occupancy,
            passengers: options?.passengers,
            canViewPassengerList: options?.canViewPassengerList,
            canViewLiveLocation: options?.canViewLiveLocation,
            createdAt: trip.createdAt,
        };
    }

    private buildTripPreferences(dto: CreateTripDto): Record<string, any> {
        const base = dto.preferences && typeof dto.preferences === 'object'
            ? { ...dto.preferences }
            : {};

        if (dto.routeSnapshot) {
            base.routeSnapshot = dto.routeSnapshot;
        }
        if (Array.isArray(dto.viaCities)) {
            base.viaCities = dto.viaCities;
        }
        if (Array.isArray(dto.pickupPolicies)) {
            base.pickupPolicies = dto.pickupPolicies;
        }

        return base;
    }

    private parseTripPreferences(raw: any): Record<string, any> {
        if (!raw) return {};
        if (typeof raw === 'string') {
            try {
                const parsed = JSON.parse(raw);
                return parsed && typeof parsed === 'object' ? parsed : {};
            } catch {
                return {};
            }
        }
        return typeof raw === 'object' ? raw : {};
    }

    private normalizeRouteSnapshot(raw: any): RouteSnapshotDto | undefined {
        if (!raw || typeof raw !== 'object') return undefined;

        const distanceKm = Number(raw.distanceKm);
        const durationMin = Number(raw.durationMin);
        if (!Number.isFinite(distanceKm) || !Number.isFinite(durationMin)) {
            return undefined;
        }

        const points = Array.isArray(raw.points)
            ? raw.points
                .map((point: any) => ({
                    lat: Number(point?.lat),
                    lng: Number(point?.lng),
                }))
                .filter((point: any) => Number.isFinite(point.lat) && Number.isFinite(point.lng))
            : [];

        return {
            provider: String(raw.provider || 'osrm'),
            distanceKm: Number(distanceKm.toFixed(1)),
            durationMin: Number(durationMin.toFixed(1)),
            points,
        };
    }

    private normalizeViaCities(raw: any): ViaCityDto[] | undefined {
        if (!Array.isArray(raw)) return undefined;
        const dedupe = new Set<string>();
        const normalized = raw
            .map((entry: any) => {
                const city = String(entry?.city || '').trim();
                const district = String(entry?.district || '').trim();
                const pickupSuggestions = Array.isArray(entry?.pickupSuggestions)
                    ? entry.pickupSuggestions
                        .map((item: any) => String(item || '').trim())
                        .filter((item: string) => item.length > 0)
                    : [];
                if (!city) return null;
                const key = `${city.toLowerCase()}|${district.toLowerCase()}`;
                if (dedupe.has(key)) return null;
                dedupe.add(key);
                return {
                    city,
                    district: district || undefined,
                    pickupSuggestions: pickupSuggestions.length
                        ? pickupSuggestions
                        : ['Otogar', 'Dinlenme Tesisi', 'Sehir Merkezi'],
                };
            })
            .filter(Boolean) as ViaCityDto[];
        return normalized.length ? normalized : undefined;
    }

    private normalizePickupPolicies(raw: any): PickupPolicyDto[] | undefined {
        if (!Array.isArray(raw)) return undefined;
        const normalized = raw
            .map((entry: any) => {
                const city = String(entry?.city || '').trim();
                const district = String(entry?.district || '').trim();
                if (!city) return null;
                const rawType = String(entry?.pickupType || '').trim();
                const pickupType = ['bus_terminal', 'rest_stop', 'city_center', 'address'].includes(rawType)
                    ? rawType
                    : 'city_center';
                return {
                    city,
                    district: district || undefined,
                    pickupAllowed: Boolean(entry?.pickupAllowed),
                    pickupType: pickupType as any,
                    note: entry?.note ? String(entry.note).slice(0, 240) : undefined,
                };
            })
            .filter(Boolean) as PickupPolicyDto[];
        return normalized.length ? normalized : undefined;
    }

    private async inferViaCities(points: Array<{ lat: number; lng: number }>): Promise<ViaCityDto[]> {
        const sampled = this.sampleRoutePoints(points, 6);
        const dedupe = new Set<string>();
        const viaCities: ViaCityDto[] = [];

        for (const point of sampled) {
            const resolved = await this.reverseGeocodeCity(point.lat, point.lng);
            if (!resolved) continue;
            const key = `${resolved.city.toLowerCase()}|${(resolved.district || '').toLowerCase()}`;
            if (dedupe.has(key)) continue;
            dedupe.add(key);
            viaCities.push({
                city: resolved.city,
                district: resolved.district,
                pickupSuggestions: ['Otogar', 'Dinlenme Tesisi', 'Sehir Merkezi'],
            });
        }

        return viaCities;
    }

    private sampleRoutePoints(points: Array<{ lat: number; lng: number }>, maxSamples: number): Array<{ lat: number; lng: number }> {
        if (!points.length) return [];
        if (points.length <= maxSamples) return points;

        const indexes = new Set<number>();
        indexes.add(0);
        indexes.add(points.length - 1);
        for (let i = 1; i < maxSamples - 1; i += 1) {
            indexes.add(Math.floor((i / (maxSamples - 1)) * (points.length - 1)));
        }

        return Array.from(indexes)
            .sort((a, b) => a - b)
            .map((index) => points[index]);
    }

    private async reverseGeocodeCity(lat: number, lng: number): Promise<{ city: string; district?: string } | null> {
        try {
            const response = await axios.get(`${this.nominatimBaseUrl}/reverse`, {
                params: {
                    format: 'jsonv2',
                    lat,
                    lon: lng,
                    zoom: 10,
                    addressdetails: 1,
                },
                timeout: 8000,
                headers: {
                    'User-Agent': 'ridesharing-app/1.0',
                },
            });

            const address = response.data?.address || {};
            const city = String(
                address.city
                || address.town
                || address.state
                || address.province
                || address.county
                || '',
            ).trim();
            const district = String(
                address.city_district
                || address.district
                || address.municipality
                || address.suburb
                || '',
            ).trim();

            if (!city) return null;
            return {
                city,
                district: district || undefined,
            };
        } catch {
            return null;
        }
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





