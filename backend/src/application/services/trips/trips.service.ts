import {
  Injectable,
  NotFoundException,
  ForbiddenException,
  BadRequestException,
  Logger,
} from "@nestjs/common";
import { PrismaService } from "@infrastructure/database/prisma.service";
import { BusPriceScraperService } from "@infrastructure/scraper/bus-price-scraper.service";
import { RedisService } from "@infrastructure/cache/redis.service";
import { FcmService } from "@infrastructure/notifications/fcm.service";
import { NetgsmService } from "@infrastructure/notifications/netgsm.service";
import { ConfigService } from "@nestjs/config";
import { IyzicoService } from "@infrastructure/payment/iyzico.service";
import {
  CreateTripDto,
  RoutePreviewDto,
  RoutePreviewResponseDto,
  RouteAlternativeDto,
  RouteEstimateDto,
  RouteEstimateResponseDto,
  RouteSnapshotDto,
  TripBookingType,
  ViaCityDto,
  PickupPolicyDto,
  UpdateTripDto,
  SearchTripsDto,
  TripResponseDto,
  TripListResponseDto,
} from "@application/dto/trips/trips.dto";
import { RoutingProviderResolver } from "@infrastructure/maps/routing-provider-resolver.service";
import { v4 as uuid } from "uuid";
import axios from "axios";

type TripSearchMatch = {
  matchType: "full" | "partial";
  segmentDeparture: string;
  segmentArrival: string;
  segmentDistanceKm: number;
  segmentRatio: number;
  segmentPricePerSeat: number;
};

type TripStop = {
  city: string;
  district?: string;
  lat?: number;
  lng?: number;
  searchText: string;
};

@Injectable()
export class TripsService {
  private readonly logger = new Logger(TripsService.name);
  private readonly searchCacheTtl: number;
  private searchCache = new Map<
    string,
    { value: TripListResponseDto; expiresAt: number }
  >();
  private readonly turkeyBounds = {
    minLat: 35.8,
    maxLat: 42.2,
    minLng: 25.6,
    maxLng: 44.9,
  };
  private readonly nominatimBaseUrl = "https://nominatim.openstreetmap.org";

  constructor(
    private readonly prisma: PrismaService,
    private readonly busPriceScraper: BusPriceScraperService,
    private readonly redisService: RedisService,
    private readonly fcmService: FcmService,
    private readonly netgsmService: NetgsmService,
    private readonly configService: ConfigService,
    private readonly iyzicoService: IyzicoService,
    private readonly routingProviderResolver: RoutingProviderResolver,
  ) {
    const ttlRaw = this.configService.get("TRIP_SEARCH_CACHE_TTL_SECONDS");
    const ttlValue = ttlRaw === undefined ? 120 : Number(ttlRaw);
    this.searchCacheTtl = Number.isFinite(ttlValue) ? ttlValue : 120;
  }

  async create(userId: string, dto: CreateTripDto): Promise<TripResponseDto> {
    // Verify vehicle belongs to user
    const vehicle = await this.prisma.vehicle.findFirst({
      where: { id: dto.vehicleId, userId },
    });

    if (!vehicle) {
      throw new BadRequestException("Bu araca erişim yetkiniz yok");
    }

    this.validateTripCoordinates(
      dto.departureLat,
      dto.departureLng,
      dto.arrivalLat,
      dto.arrivalLng,
    );

    const normalizedPreferences = this.buildTripPreferences(dto);

    const bookingType = this.resolveBookingType(dto);
    const trip = await this.prisma.trip.create({
      data: {
        id: uuid(),
        driverId: userId,
        vehicleId: dto.vehicleId,
        type: dto.type as any,
        status: "published",
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
        instantBooking: bookingType === TripBookingType.INSTANT,
        bookingType,
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
    let departureLat = dto.departureLat;
    let departureLng = dto.departureLng;
    let arrivalLat = dto.arrivalLat;
    let arrivalLng = dto.arrivalLng;

    if (
      (departureLat === undefined || departureLng === undefined) &&
      dto.departureCity?.trim()
    ) {
      const resolved = await this.forwardGeocodeCity(dto.departureCity);
      if (resolved) {
        departureLat = resolved.lat;
        departureLng = resolved.lng;
      }
    }

    if (
      (arrivalLat === undefined || arrivalLng === undefined) &&
      dto.arrivalCity?.trim()
    ) {
      const resolved = await this.forwardGeocodeCity(dto.arrivalCity);
      if (resolved) {
        arrivalLat = resolved.lat;
        arrivalLng = resolved.lng;
      }
    }

    if (
      departureLat === undefined ||
      departureLng === undefined ||
      arrivalLat === undefined ||
      arrivalLng === undefined
    ) {
      throw new BadRequestException(
        "Rota onizleme icin kalkis ve varis konumu secilmeli",
      );
    }

    this.validateTripCoordinates(
      departureLat,
      departureLng,
      arrivalLat,
      arrivalLng,
    );

    const routingProvider = this.routingProviderResolver.getProvider();
    try {
      const paths = await routingProvider.getRouteAlternatives({
        departureLat,
        departureLng,
        arrivalLat,
        arrivalLng,
        alternatives: 3,
      });

      if (!paths.length) {
        throw new BadRequestException("Rota bulunamadi");
      }

      const alternatives: RouteAlternativeDto[] = [];
      for (let i = 0; i < Math.min(paths.length, 3); i += 1) {
        const path = paths[i];
        const viaCities = await this.inferViaCities(path.points);
        const simplifiedPoints = this.downsampleRoutePoints(path.points, 280);

        alternatives.push({
          id: `route_${i + 1}`,
          route: {
            provider: path.provider,
            distanceKm: path.distanceKm,
            durationMin: path.durationMin,
            points: simplifiedPoints,
            bbox: path.bbox,
          },
          viaCities,
        });
      }

      return {
        provider: routingProvider.name,
        alternatives,
      };
    } catch (error: any) {
      this.logger.warn(`ROUTE_PREVIEW_FAILED ${error?.message || "unknown"}`);
      if (error instanceof BadRequestException) {
        throw error;
      }

      const fallbackDistanceKm = this.haversineDistanceKm(
        departureLat,
        departureLng,
        arrivalLat,
        arrivalLng,
      );
      const fallbackDurationMin = Number(
        ((fallbackDistanceKm / 70) * 60).toFixed(1),
      );
      return {
        provider: "fallback",
        alternatives: [
          {
            id: "route_fallback",
            route: {
              provider: "fallback",
              distanceKm: Number(fallbackDistanceKm.toFixed(1)),
              durationMin: Number.isFinite(fallbackDurationMin)
                ? fallbackDurationMin
                : 0,
              points: [
                { lat: departureLat, lng: departureLng },
                { lat: arrivalLat, lng: arrivalLng },
              ],
              bbox: this.computeBoundingBox([
                { lat: departureLat, lng: departureLng },
                { lat: arrivalLat, lng: arrivalLng },
              ]),
            },
            viaCities: [],
          },
        ],
      };
    }
  }

  async estimateRouteCost(
    dto: RouteEstimateDto,
  ): Promise<RouteEstimateResponseDto> {
    let departureLat = dto.departureLat;
    let departureLng = dto.departureLng;
    let arrivalLat = dto.arrivalLat;
    let arrivalLng = dto.arrivalLng;

    if (
      (departureLat === undefined || departureLng === undefined) &&
      dto.departureCity?.trim()
    ) {
      const resolved = await this.forwardGeocodeCity(dto.departureCity);
      if (resolved) {
        departureLat = resolved.lat;
        departureLng = resolved.lng;
      }
    }

    if (
      (arrivalLat === undefined || arrivalLng === undefined) &&
      dto.arrivalCity?.trim()
    ) {
      const resolved = await this.forwardGeocodeCity(dto.arrivalCity);
      if (resolved) {
        arrivalLat = resolved.lat;
        arrivalLng = resolved.lng;
      }
    }

    if (
      departureLat === undefined ||
      departureLng === undefined ||
      arrivalLat === undefined ||
      arrivalLng === undefined
    ) {
      throw new BadRequestException(
        "Maliyet hesabi icin kalkis ve varis konumu gerekli",
      );
    }

    this.validateTripCoordinates(
      departureLat,
      departureLng,
      arrivalLat,
      arrivalLng,
    );

    const routingProvider = this.routingProviderResolver.getProvider();
    let distanceKm = 0;
    let durationMin = 0;
    try {
      const paths = await routingProvider.getRouteAlternatives({
        departureLat,
        departureLng,
        arrivalLat,
        arrivalLng,
        alternatives: 1,
      });
      if (!paths.length) {
        throw new Error("No route");
      }
      distanceKm = paths[0].distanceKm;
      durationMin = paths[0].durationMin;
    } catch {
      distanceKm = Number(
        this.haversineDistanceKm(
          departureLat,
          departureLng,
          arrivalLat,
          arrivalLng,
        ).toFixed(1),
      );
      durationMin = Number(((distanceKm / 70) * 60).toFixed(1));
    }

    const baseFee = this.toMoney(
      this.configService.get<number>("FARE_BASE_FEE") ?? 40,
    );
    const perKm = this.toMoney(
      this.configService.get<number>("FARE_PER_KM") ?? 2.4,
    );
    const perMin = this.toMoney(
      this.configService.get<number>("FARE_PER_MIN") ?? 0.35,
    );
    const platformFee = this.toMoney(
      this.configService.get<number>("FARE_PLATFORM_FEE") ?? 8,
    );
    const peakTrafficMultiplier = this.toMoney(
      this.configService.get<number>("FARE_TRAFFIC_MULTIPLIER_PEAK") ?? 1.12,
    );
    const tripType = dto.tripType || "people";

    const tripTypeMultiplierMap: Record<string, number> = {
      people: 1,
      pets: 1.08,
      cargo: 1.16,
      food: 1.05,
    };
    const tripTypeMultiplier = this.toMoney(
      tripTypeMultiplierMap[tripType] ?? 1,
    );
    const trafficMultiplier = dto.peakTraffic ? peakTrafficMultiplier : 1;

    const distanceFee = this.toMoney(distanceKm * perKm);
    const durationFee = this.toMoney(durationMin * perMin);
    const raw =
      (baseFee + distanceFee + durationFee + platformFee) *
      tripTypeMultiplier *
      trafficMultiplier;
    const estimatedCost = this.toMoney(raw);

    return {
      provider: routingProvider.name,
      distanceKm,
      durationMin,
      estimatedCost,
      currency: "TRY",
      breakdown: {
        baseFee,
        distanceFee,
        durationFee,
        platformFee,
        tripTypeMultiplier,
        trafficMultiplier: this.toMoney(trafficMultiplier),
      },
    };
  }

  async findAll(query: SearchTripsDto): Promise<TripListResponseDto> {
    const cacheKey = this.buildSearchCacheKey(query);
    const cached = await this.getSearchCache(cacheKey);
    if (cached) {
      return cached;
    }

    const { from, to, date, seats, type, allowsPets, womenOnly } = query;
    const page =
      Number.isFinite(Number(query.page)) && Number(query.page) > 0
        ? Math.floor(Number(query.page))
        : 1;
    const limit =
      Number.isFinite(Number(query.limit)) && Number(query.limit) > 0
        ? Math.min(Math.floor(Number(query.limit)), 100)
        : 20;
    const seatsNumber =
      seats !== undefined && seats !== null && `${seats}`.trim() !== ""
        ? Number(seats)
        : undefined;
    if (
      seatsNumber !== undefined &&
      (!Number.isFinite(seatsNumber) || seatsNumber <= 0)
    ) {
      throw new BadRequestException("Koltuk sayisi gecersiz");
    }
    const hasFrom = typeof from === "string" && from.trim().length > 0;
    const hasTo = typeof to === "string" && to.trim().length > 0;
    const hasLocationQuery = hasFrom || hasTo;

    const where: any = {
      status: { in: ["published", "full"] },
      deletedAt: null,
    };
    if (date) {
      const startOfDay = new Date(`${date}T00:00:00.000Z`);
      const endOfDay = new Date(`${date}T23:59:59.999Z`);
      if (
        Number.isNaN(startOfDay.getTime()) ||
        Number.isNaN(endOfDay.getTime())
      ) {
        throw new BadRequestException("Tarih formati gecersiz");
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

    const candidateTake = hasLocationQuery
      ? Math.max(limit * 8, 250)
      : limit;
    const skip = hasLocationQuery ? 0 : (page - 1) * limit;

    const [trips, total] = await Promise.all([
      this.prisma.trip.findMany({
        where,
        skip,
        take: candidateTake,
        orderBy: { departureTime: "asc" },
        include: {
          driver: true,
          vehicle: true,
        },
      }),
      hasLocationQuery
        ? Promise.resolve(0)
        : this.prisma.trip.count({ where }),
    ]);

    let mappedTrips = trips.map((trip) => this.mapToResponse(trip));

    if (hasLocationQuery) {
      mappedTrips = mappedTrips
        .map((trip) => {
          const match = this.resolveTripSearchMatch(trip, from, to);
          if (!match) return null;
          return this.applySearchMatchToTrip(trip, match);
        })
        .filter(Boolean) as TripResponseDto[];

      mappedTrips.sort((a, b) => {
        if (a.matchType !== b.matchType) {
          return a.matchType === "full" ? -1 : 1;
        }
        return (
          new Date(a.departureTime).getTime() -
          new Date(b.departureTime).getTime()
        );
      });

      const totalMatched = mappedTrips.length;
      const start = (page - 1) * limit;
      const end = start + limit;
      const pagedTrips = mappedTrips.slice(start, end);

      const result: TripListResponseDto = {
        trips: pagedTrips,
        total: totalMatched,
        page,
        limit,
        totalPages: Math.max(1, Math.ceil(totalMatched / limit)),
      };

      await this.setSearchCache(cacheKey, result);
      return result;
    }

    const result: TripListResponseDto = {
      trips: mappedTrips,
      total,
      page,
      limit,
      totalPages: Math.max(1, Math.ceil(total / limit)),
    };

    await this.setSearchCache(cacheKey, result);
    return result;
  }

  async findById(
    id: string,
    viewerId?: string,
    from?: string,
    to?: string,
  ): Promise<TripResponseDto> {
    const trip = await this.prisma.trip.findUnique({
      where: { id },
      include: {
        driver: true,
        vehicle: true,
        bookings: {
          where: {
            status: {
              in: ["confirmed", "checked_in", "completed", "disputed"],
            },
            paymentStatus: "paid",
          },
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
      throw new NotFoundException("Yolculuk bulunamadı");
    }
    if (trip.deletedAt) {
      throw new NotFoundException("Yolculuk bulunamadı");
    }

    const isDriverViewer = Boolean(viewerId && trip.driverId === viewerId);
    const isConfirmedPassengerViewer = Boolean(
      viewerId &&
      trip.bookings.some(
        (booking: any) =>
          booking.passengerId === viewerId &&
          booking.paymentStatus === "paid" &&
          ["confirmed", "checked_in", "completed", "disputed"].includes(
            booking.status,
          ),
      ),
    );
    const canViewPassengerList = isDriverViewer || isConfirmedPassengerViewer;
    const canViewLiveLocation = isDriverViewer || isConfirmedPassengerViewer;

    const occupancy = trip.bookings.reduce(
      (
        acc: { confirmedSeats: number; passengerCount: number },
        booking: any,
      ) => {
        if (
          ["confirmed", "checked_in", "completed", "disputed"].includes(
            booking.status,
          )
        ) {
          acc.confirmedSeats += Number(booking.seats || 0);
          acc.passengerCount += 1;
        }
        return acc;
      },
      { confirmedSeats: 0, passengerCount: 0 },
    );

    let response = this.mapToResponse(trip, {
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

    const contextualMatch = this.resolveTripSearchMatch(response, from, to);
    if (contextualMatch) {
      response = this.applySearchMatchToTrip(response, contextualMatch);
    }

    // Get bus reference price from cache
    const busPrice = await this.getBusReferencePrice(
      trip.departureCity,
      trip.arrivalCity,
    );
    if (busPrice) {
      response.busReferencePrice = busPrice;
    }

    return response;
  }

  async findByDriver(
    driverId: string,
    options?: { includeDeleted?: boolean; status?: string },
  ): Promise<TripResponseDto[]> {
    const where: any = { driverId };
    if (!options?.includeDeleted) {
      where.deletedAt = null;
    }
    const statusFilter = String(options?.status || "").trim();
    if (statusFilter === "active") {
      where.status = { in: ["published", "full", "in_progress"] };
    } else if (statusFilter === "archived") {
      where.status = { in: ["completed", "cancelled"] };
    } else if (statusFilter.length > 0) {
      where.status = statusFilter;
    }

    const trips = await this.prisma.trip.findMany({
      where,
      orderBy: { createdAt: "desc" },
      include: {
        driver: true,
        vehicle: true,
      },
    });

    return trips.map((trip) => this.mapToResponse(trip));
  }

  async update(
    id: string,
    userId: string,
    dto: UpdateTripDto,
  ): Promise<TripResponseDto> {
    const trip = await this.prisma.trip.findUnique({
      where: { id },
    });

    if (!trip) {
      throw new NotFoundException("Yolculuk bulunamadı");
    }
    if (trip.deletedAt) {
      throw new NotFoundException("Yolculuk bulunamadı");
    }

    if (trip.driverId !== userId) {
      throw new ForbiddenException("Bu yolculuğu düzenleme yetkiniz yok");
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
        ...(dto.availableSeats !== undefined && {
          availableSeats: dto.availableSeats,
        }),
        ...(dto.pricePerSeat !== undefined && {
          pricePerSeat: dto.pricePerSeat,
        }),
        ...(dto.status && { status: dto.status as any }),
        ...(dto.departureAddress && { departureAddress: dto.departureAddress }),
        ...(dto.arrivalAddress && { arrivalAddress: dto.arrivalAddress }),
        ...(dto.departureLat !== undefined && {
          departureLat: dto.departureLat,
        }),
        ...(dto.departureLng !== undefined && {
          departureLng: dto.departureLng,
        }),
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
      throw new NotFoundException("Yolculuk bulunamadı");
    }
    if (trip.deletedAt) {
      return;
    }

    if (trip.driverId !== userId) {
      throw new ForbiddenException("Bu yolculuğu iptal etme yetkiniz yok");
    }

    const now = new Date();
    await this.prisma.trip.update({
      where: { id },
      data: {
        status: trip.status === "completed" ? "completed" : "cancelled",
        deletedAt: now,
      },
    });

    await this.invalidateSearchCache();
    await this.cancelTripBookings(
      trip.id,
      trip.departureCity,
      trip.arrivalCity,
    );
  }

  private async cancelTripBookings(
    tripId: string,
    from: string,
    to: string,
  ): Promise<void> {
    const bookings = await this.prisma.booking.findMany({
      where: {
        tripId,
        status: {
          in: ["pending", "awaiting_payment", "confirmed", "checked_in"],
        },
      },
      include: {
        passenger: true,
      },
    });

    for (const booking of bookings) {
      let refundAmount = 0;
      if (booking.paymentStatus === "paid" && booking.paymentId) {
        try {
          const refund = await this.iyzicoService.refundPayment(
            booking.paymentId,
            Number(booking.priceTotal),
            "Sürücü iptali",
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
            status: "cancelled_by_driver",
            cancellationTime: new Date(),
            cancellationPenalty: 0,
            paymentStatus: refundAmount > 0 ? "refunded" : booking.paymentStatus,
            expiresAt: null,
            paymentDueAt: null,
          },
        });

      await this.notifyTripCancelled(
        booking.passenger,
        { from, to },
        refundAmount,
      );
    }
  }

  private async notifyTripUpdated(trip: any): Promise<void> {
    const bookings = await this.prisma.booking.findMany({
      where: {
        tripId: trip.id,
        status: {
          in: ["pending", "awaiting_payment", "confirmed", "checked_in"],
        },
      },
      include: { passenger: true },
    });

    if (!bookings.length) return;

    try {
      await Promise.all(
        bookings.map(async (booking) => {
          const passenger = booking.passenger;
          const tokens = this.extractDeviceTokens(passenger?.preferences);

          if (tokens.length > 0) {
            await Promise.all(
              tokens.map((token) =>
                this.fcmService.notifyTripUpdated(token, {
                  from: trip.departureCity,
                  to: trip.arrivalCity,
                  tripId: trip.id,
                }),
              ),
            );
          }

          if (passenger?.phone) {
            await this.netgsmService.sendTripUpdated(passenger.phone, {
              from: trip.departureCity,
              to: trip.arrivalCity,
            });
          }
        }),
      );
    } catch {
      // Ignore notification errors
    }
  }

  private async notifyTripCancelled(
    passenger: any,
    tripInfo: { from: string; to: string },
    refundAmount: number,
  ) {
    try {
      const tokens = this.extractDeviceTokens(passenger?.preferences);
      if (tokens.length > 0) {
        await Promise.all(
          tokens.map((token) =>
            this.fcmService.notifyTripCancelled(token, {
              from: tripInfo.from,
              to: tripInfo.to,
            }),
          ),
        );
      }

      if (passenger?.phone) {
        await this.netgsmService.sendTripCancelled(passenger.phone, tripInfo);
        if (refundAmount > 0) {
          await this.netgsmService.sendCancellationNotice(
            passenger.phone,
            refundAmount,
          );
        }
      }
    } catch {
      // Ignore notification errors
    }
  }

  private async getBusReferencePrice(
    from: string,
    to: string,
  ): Promise<number | null> {
    return this.busPriceScraper.getPrice(from, to);
  }

  private buildSearchCacheKey(query: SearchTripsDto): string {
    const keyPayload = {
      from: this.normalizeForSearch(query.from || ""),
      to: this.normalizeForSearch(query.to || ""),
      date: query.date || "",
      seats: query.seats || "",
      type: query.type || "",
      allowsPets: query.allowsPets ?? "",
      womenOnly: query.womenOnly ?? "",
      page: query.page || 1,
      limit: query.limit || 20,
    };
    return `trips:search:${Buffer.from(JSON.stringify(keyPayload)).toString("base64")}`;
  }

  private async getSearchCache(
    key: string,
  ): Promise<TripListResponseDto | null> {
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

  private async setSearchCache(
    key: string,
    value: TripListResponseDto,
  ): Promise<void> {
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
      await this.redisService.delByPrefix("trips:search:");
    }
  }

  private mapToResponse(
    trip: any,
    options?: {
      occupancy?: { confirmedSeats: number; passengerCount: number };
      passengers?: Array<{
        id: string;
        fullName: string;
        profilePhotoUrl?: string;
        ratingAvg: number;
        seats: number;
      }>;
      canViewPassengerList?: boolean;
      canViewLiveLocation?: boolean;
      searchMatch?: TripSearchMatch;
    },
  ): TripResponseDto {
    const preferences = this.parseTripPreferences(trip.preferences);
    const bookingType = this.normalizeBookingType(
      trip.bookingType,
      trip.instantBooking,
    );
    const route = this.normalizeRouteSnapshot(preferences.routeSnapshot);
    const viaCities = this.normalizeViaCities(preferences.viaCities);
    const pickupPolicies = this.normalizePickupPolicies(
      preferences.pickupPolicies,
    );

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
      departureLat:
        trip.departureLat !== null && trip.departureLat !== undefined
          ? Number(trip.departureLat)
          : undefined,
      departureLng:
        trip.departureLng !== null && trip.departureLng !== undefined
          ? Number(trip.departureLng)
          : undefined,
      arrivalLat:
        trip.arrivalLat !== null && trip.arrivalLat !== undefined
          ? Number(trip.arrivalLat)
          : undefined,
      arrivalLng:
        trip.arrivalLng !== null && trip.arrivalLng !== undefined
          ? Number(trip.arrivalLng)
          : undefined,
      departureTime: trip.departureTime,
      estimatedArrivalTime: trip.estimatedArrivalTime,
      availableSeats: trip.availableSeats,
      pricePerSeat:
        options?.searchMatch?.segmentPricePerSeat ?? Number(trip.pricePerSeat),
      matchType: options?.searchMatch?.matchType,
      segmentDeparture: options?.searchMatch?.segmentDeparture,
      segmentArrival: options?.searchMatch?.segmentArrival,
      segmentDistanceKm: options?.searchMatch?.segmentDistanceKm,
      segmentRatio: options?.searchMatch?.segmentRatio,
      segmentPricePerSeat: options?.searchMatch?.segmentPricePerSeat,
      allowsPets: trip.allowsPets,
      allowsCargo: trip.allowsCargo,
      womenOnly: trip.womenOnly,
      instantBooking: bookingType === TripBookingType.INSTANT,
      bookingType,
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

  private applySearchMatchToTrip(
    trip: TripResponseDto,
    match: TripSearchMatch,
  ): TripResponseDto {
    return {
      ...trip,
      pricePerSeat: match.segmentPricePerSeat,
      matchType: match.matchType,
      segmentDeparture: match.segmentDeparture,
      segmentArrival: match.segmentArrival,
      segmentDistanceKm: match.segmentDistanceKm,
      segmentRatio: match.segmentRatio,
      segmentPricePerSeat: match.segmentPricePerSeat,
    };
  }

  private resolveTripSearchMatch(
    trip: TripResponseDto,
    from?: string,
    to?: string,
  ): TripSearchMatch | null {
    const fromQuery = String(from || "").trim();
    const toQuery = String(to || "").trim();
    const hasFrom = fromQuery.length > 0;
    const hasTo = toQuery.length > 0;
    if (!hasFrom && !hasTo) return null;

    const stops = this.buildTripStops(trip);
    if (stops.length < 2) return null;

    const startIndex = hasFrom
      ? this.findMatchingStopIndex(stops, fromQuery, 0)
      : 0;
    if (startIndex < 0) return null;

    const endIndex = hasTo
      ? this.findMatchingStopIndex(
          stops,
          toQuery,
          hasFrom ? startIndex + 1 : 0,
        )
      : stops.length - 1;
    if (endIndex < 0 || endIndex <= startIndex) return null;

    const isFullMatch = startIndex === 0 && endIndex === stops.length - 1;
    const startStop = stops[startIndex];
    const endStop = stops[endIndex];

    const totalDistanceKm = this.resolveTripDistanceKm(trip, stops);
    if (!Number.isFinite(totalDistanceKm) || totalDistanceKm <= 0) {
      return null;
    }

    const segmentDistanceKm = isFullMatch
      ? totalDistanceKm
      : this.resolveSegmentDistanceKm(
          trip,
          stops,
          startIndex,
          endIndex,
          totalDistanceKm,
        );
    if (!Number.isFinite(segmentDistanceKm) || segmentDistanceKm <= 0) {
      return null;
    }

    const segmentRatio = this.clamp01(segmentDistanceKm / totalDistanceKm);
    if (!Number.isFinite(segmentRatio) || segmentRatio <= 0) {
      return null;
    }

    const basePrice = Number(trip.pricePerSeat);
    if (!Number.isFinite(basePrice) || basePrice <= 0) {
      return null;
    }

    const segmentPricePerSeat = this.toMoney(basePrice * segmentRatio);

    return {
      matchType: isFullMatch ? "full" : "partial",
      segmentDeparture: startStop.city,
      segmentArrival: endStop.city,
      segmentDistanceKm: this.toMoney(segmentDistanceKm),
      segmentRatio: this.toMoney(segmentRatio),
      segmentPricePerSeat,
    };
  }

  private buildTripStops(trip: TripResponseDto): TripStop[] {
    const stops: TripStop[] = [];

    stops.push({
      city: trip.departureCity,
      lat: trip.departureLat,
      lng: trip.departureLng,
      searchText: trip.departureCity,
    });

    for (const via of trip.viaCities || []) {
      const city = String(via.city || "").trim();
      if (!city) continue;
      const district = via.district ? String(via.district).trim() : undefined;
      const key = this.normalizeForSearch(
        district ? `${city} ${district}` : city,
      );
      const duplicate = stops.some(
        (stop) => this.normalizeForSearch(stop.searchText) === key,
      );
      if (duplicate) continue;
      stops.push({
        city,
        district,
        lat: via.lat,
        lng: via.lng,
        searchText: district ? `${city} ${district}` : city,
      });
    }

    stops.push({
      city: trip.arrivalCity,
      lat: trip.arrivalLat,
      lng: trip.arrivalLng,
      searchText: trip.arrivalCity,
    });

    return stops;
  }

  private findMatchingStopIndex(
    stops: TripStop[],
    query: string,
    startIndex: number,
  ): number {
    for (let i = Math.max(0, startIndex); i < stops.length; i += 1) {
      if (this.matchesLocationQuery(query, stops[i].searchText)) {
        return i;
      }
    }
    return -1;
  }

  private matchesLocationQuery(query: string, candidate: string): boolean {
    const normalizedQuery = this.normalizeForSearch(query);
    const normalizedCandidate = this.normalizeForSearch(candidate);
    if (!normalizedQuery || !normalizedCandidate) return false;

    if (
      normalizedCandidate.includes(normalizedQuery) ||
      normalizedQuery.includes(normalizedCandidate)
    ) {
      return true;
    }

    const queryTokens = normalizedQuery.split(" ").filter(Boolean);
    const candidateTokens = normalizedCandidate.split(" ").filter(Boolean);
    if (!queryTokens.length || !candidateTokens.length) return false;

    return queryTokens.every((token) =>
      candidateTokens.some((candidateToken) =>
        this.isFuzzyTokenMatch(token, candidateToken),
      ),
    );
  }

  private isFuzzyTokenMatch(queryToken: string, candidateToken: string): boolean {
    if (
      candidateToken.includes(queryToken) ||
      queryToken.includes(candidateToken)
    ) {
      return true;
    }
    const maxDistance =
      queryToken.length <= 4 ? 1 : queryToken.length <= 8 ? 2 : 3;
    return (
      this.levenshteinDistance(queryToken, candidateToken, maxDistance) <=
      maxDistance
    );
  }

  private normalizeForSearch(value: string): string {
    return String(value || "")
      .trim()
      .toLocaleLowerCase("tr-TR")
      .replace(/ı/g, "i")
      .replace(/ğ/g, "g")
      .replace(/ş/g, "s")
      .replace(/ö/g, "o")
      .replace(/ü/g, "u")
      .replace(/ç/g, "c")
      .normalize("NFKD")
      .replace(/[\u0300-\u036f]/g, "")
      .replace(/[^a-z0-9\s]/g, " ")
      .replace(/\s+/g, " ")
      .trim();
  }

  private levenshteinDistance(
    left: string,
    right: string,
    maxDistance: number,
  ): number {
    if (left === right) return 0;
    if (!left.length) return right.length;
    if (!right.length) return left.length;
    if (Math.abs(left.length - right.length) > maxDistance) {
      return maxDistance + 1;
    }

    const previousRow = Array.from({ length: right.length + 1 }, (_, i) => i);
    const currentRow = new Array<number>(right.length + 1);

    for (let i = 1; i <= left.length; i += 1) {
      currentRow[0] = i;
      let rowMin = currentRow[0];

      for (let j = 1; j <= right.length; j += 1) {
        const insertCost = currentRow[j - 1] + 1;
        const deleteCost = previousRow[j] + 1;
        const replaceCost =
          previousRow[j - 1] + (left[i - 1] === right[j - 1] ? 0 : 1);
        const next = Math.min(insertCost, deleteCost, replaceCost);
        currentRow[j] = next;
        if (next < rowMin) {
          rowMin = next;
        }
      }

      if (rowMin > maxDistance) {
        return maxDistance + 1;
      }

      for (let j = 0; j <= right.length; j += 1) {
        previousRow[j] = currentRow[j];
      }
    }

    return previousRow[right.length];
  }

  private resolveTripDistanceKm(trip: TripResponseDto, stops: TripStop[]): number {
    const routeDistance = Number(trip.route?.distanceKm || 0);
    if (Number.isFinite(routeDistance) && routeDistance > 0) {
      return routeDistance;
    }

    const distanceKm = Number(trip.distanceKm || 0);
    if (Number.isFinite(distanceKm) && distanceKm > 0) {
      return distanceKm;
    }

    const first = stops[0];
    const last = stops[stops.length - 1];
    if (
      first?.lat !== undefined &&
      first?.lng !== undefined &&
      last?.lat !== undefined &&
      last?.lng !== undefined
    ) {
      return this.haversineDistanceKm(first.lat, first.lng, last.lat, last.lng);
    }
    return 0;
  }

  private resolveSegmentDistanceKm(
    trip: TripResponseDto,
    stops: TripStop[],
    startIndex: number,
    endIndex: number,
    totalDistanceKm: number,
  ): number {
    const start = stops[startIndex];
    const end = stops[endIndex];
    if (
      start?.lat !== undefined &&
      start?.lng !== undefined &&
      end?.lat !== undefined &&
      end?.lng !== undefined
    ) {
      const direct = this.haversineDistanceKm(start.lat, start.lng, end.lat, end.lng);
      if (Number.isFinite(direct) && direct > 0) {
        return Math.min(direct, totalDistanceKm);
      }
    }

    if (trip.route?.points && trip.route.points.length >= 2) {
      const ratioByIndex = (endIndex - startIndex) / (stops.length - 1);
      return totalDistanceKm * this.clamp01(ratioByIndex);
    }

    const fallbackRatio = (endIndex - startIndex) / (stops.length - 1);
    return totalDistanceKm * this.clamp01(fallbackRatio);
  }

  private clamp01(value: number): number {
    if (!Number.isFinite(value)) return 0;
    if (value < 0) return 0;
    if (value > 1) return 1;
    return value;
  }

  private buildTripPreferences(dto: CreateTripDto): Record<string, any> {
    const base =
      dto.preferences && typeof dto.preferences === "object"
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

  private resolveBookingType(dto: CreateTripDto): TripBookingType {
    if (dto.bookingType === TripBookingType.APPROVAL_REQUIRED) {
      return TripBookingType.APPROVAL_REQUIRED;
    }
    if (dto.bookingType === TripBookingType.INSTANT) {
      return TripBookingType.INSTANT;
    }
    if (dto.instantBooking === false) {
      return TripBookingType.APPROVAL_REQUIRED;
    }
    return TripBookingType.INSTANT;
  }

  private normalizeBookingType(
    value: any,
    instantBooking?: boolean,
  ): TripBookingType {
    if (value === TripBookingType.APPROVAL_REQUIRED) {
      return TripBookingType.APPROVAL_REQUIRED;
    }
    if (value === TripBookingType.INSTANT) {
      return TripBookingType.INSTANT;
    }
    if (instantBooking === false) {
      return TripBookingType.APPROVAL_REQUIRED;
    }
    return TripBookingType.INSTANT;
  }

  private parseTripPreferences(raw: any): Record<string, any> {
    if (!raw) return {};
    if (typeof raw === "string") {
      try {
        const parsed = JSON.parse(raw);
        return parsed && typeof parsed === "object" ? parsed : {};
      } catch {
        return {};
      }
    }
    return typeof raw === "object" ? raw : {};
  }

  private normalizeRouteSnapshot(raw: any): RouteSnapshotDto | undefined {
    if (!raw || typeof raw !== "object") return undefined;

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
          .filter(
            (point: any) =>
              Number.isFinite(point.lat) && Number.isFinite(point.lng),
          )
      : [];

    const bbox =
      raw.bbox && typeof raw.bbox === "object"
        ? {
            minLat: Number(raw.bbox.minLat),
            minLng: Number(raw.bbox.minLng),
            maxLat: Number(raw.bbox.maxLat),
            maxLng: Number(raw.bbox.maxLng),
          }
        : undefined;

    return {
      provider: String(raw.provider || "osrm"),
      distanceKm: Number(distanceKm.toFixed(1)),
      durationMin: Number(durationMin.toFixed(1)),
      points,
      bbox:
        bbox &&
        Number.isFinite(bbox.minLat) &&
        Number.isFinite(bbox.minLng) &&
        Number.isFinite(bbox.maxLat) &&
        Number.isFinite(bbox.maxLng)
          ? bbox
          : undefined,
    };
  }

  private normalizeViaCities(raw: any): ViaCityDto[] | undefined {
    if (!Array.isArray(raw)) return undefined;
    const dedupe = new Set<string>();
    const normalized = raw
      .map((entry: any) => {
        const city = String(entry?.city || "").trim();
        const district = String(entry?.district || "").trim();
        const pickupSuggestions = Array.isArray(entry?.pickupSuggestions)
          ? entry.pickupSuggestions
              .map((item: any) => String(item || "").trim())
              .filter((item: string) => item.length > 0)
          : [];
        if (!city) return null;
        const key = `${city.toLowerCase()}|${district.toLowerCase()}`;
        if (dedupe.has(key)) return null;
        dedupe.add(key);
        const lat =
          entry?.lat !== undefined ? Number(entry.lat) : undefined;
        const lng =
          entry?.lng !== undefined ? Number(entry.lng) : undefined;
        return {
          city,
          district: district || undefined,
          lat: Number.isFinite(lat) ? lat : undefined,
          lng: Number.isFinite(lng) ? lng : undefined,
          pickupSuggestions: pickupSuggestions.length
            ? pickupSuggestions
            : ["Otogar", "Dinlenme Tesisi", "Sehir Merkezi"],
        };
      })
      .filter(Boolean) as ViaCityDto[];
    return normalized.length ? normalized : undefined;
  }

  private normalizePickupPolicies(raw: any): PickupPolicyDto[] | undefined {
    if (!Array.isArray(raw)) return undefined;
    const normalized = raw
      .map((entry: any) => {
        const city = String(entry?.city || "").trim();
        const district = String(entry?.district || "").trim();
        if (!city) return null;
        const rawType = String(entry?.pickupType || "").trim();
        const pickupType = [
          "bus_terminal",
          "rest_stop",
          "city_center",
          "address",
        ].includes(rawType)
          ? rawType
          : "city_center";
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

  private async inferViaCities(
    points: Array<{ lat: number; lng: number }>,
  ): Promise<ViaCityDto[]> {
    const sampled = this.sampleRoutePoints(points, 6);
    const dedupe = new Set<string>();
    const viaCities: ViaCityDto[] = [];

    const resolvedCities = await Promise.all(
      sampled.map((point) => this.reverseGeocodeCity(point.lat, point.lng)),
    );

    for (let i = 0; i < resolvedCities.length; i += 1) {
      const resolved = resolvedCities[i];
      if (!resolved) continue;
      const key = `${resolved.city.toLowerCase()}|${(resolved.district || "").toLowerCase()}`;
      if (dedupe.has(key)) continue;
      dedupe.add(key);
      const samplePoint = sampled[i];
      viaCities.push({
        city: resolved.city,
        district: resolved.district,
        lat: samplePoint?.lat,
        lng: samplePoint?.lng,
        pickupSuggestions: ["Otogar", "Dinlenme Tesisi", "Sehir Merkezi"],
      });
    }

    return viaCities;
  }

  private sampleRoutePoints(
    points: Array<{ lat: number; lng: number }>,
    maxSamples: number,
  ): Array<{ lat: number; lng: number }> {
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

  private downsampleRoutePoints(
    points: Array<{ lat: number; lng: number }>,
    maxPoints: number,
  ): Array<{ lat: number; lng: number }> {
    if (!points.length) return [];
    if (points.length <= maxPoints) return points;

    const sampled = this.sampleRoutePoints(points, maxPoints);
    if (!sampled.length) return [];

    const first = points[0];
    const last = points[points.length - 1];
    if (sampled[0].lat !== first.lat || sampled[0].lng !== first.lng) {
      sampled[0] = first;
    }
    if (
      sampled[sampled.length - 1].lat !== last.lat ||
      sampled[sampled.length - 1].lng !== last.lng
    ) {
      sampled[sampled.length - 1] = last;
    }
    return sampled;
  }

  private computeBoundingBox(points: Array<{ lat: number; lng: number }>) {
    if (!points.length) return undefined;
    let minLat = Number.POSITIVE_INFINITY;
    let minLng = Number.POSITIVE_INFINITY;
    let maxLat = Number.NEGATIVE_INFINITY;
    let maxLng = Number.NEGATIVE_INFINITY;

    for (const point of points) {
      minLat = Math.min(minLat, point.lat);
      minLng = Math.min(minLng, point.lng);
      maxLat = Math.max(maxLat, point.lat);
      maxLng = Math.max(maxLng, point.lng);
    }

    if (
      !Number.isFinite(minLat) ||
      !Number.isFinite(minLng) ||
      !Number.isFinite(maxLat) ||
      !Number.isFinite(maxLng)
    ) {
      return undefined;
    }

    return { minLat, minLng, maxLat, maxLng };
  }

  private toMoney(value: number): number {
    return Number(Number(value).toFixed(2));
  }

  private haversineDistanceKm(
    lat1: number,
    lng1: number,
    lat2: number,
    lng2: number,
  ): number {
    const toRad = (deg: number) => (deg * Math.PI) / 180;
    const earthRadiusKm = 6371;
    const dLat = toRad(lat2 - lat1);
    const dLng = toRad(lng2 - lng1);
    const a =
      Math.sin(dLat / 2) ** 2 +
      Math.cos(toRad(lat1)) * Math.cos(toRad(lat2)) * Math.sin(dLng / 2) ** 2;
    const c = 2 * Math.atan2(Math.sqrt(a), Math.sqrt(1 - a));
    return earthRadiusKm * c;
  }

  private async reverseGeocodeCity(
    lat: number,
    lng: number,
  ): Promise<{ city: string; district?: string } | null> {
    try {
      const response = await axios.get(`${this.nominatimBaseUrl}/reverse`, {
        params: {
          format: "jsonv2",
          lat,
          lon: lng,
          zoom: 10,
          addressdetails: 1,
        },
        timeout: 8000,
        headers: {
          "User-Agent": "ridesharing-app/1.0",
        },
      });

      const address = response.data?.address || {};
      const city = String(
        address.city ||
          address.town ||
          address.state ||
          address.province ||
          address.county ||
          "",
      ).trim();
      const district = String(
        address.city_district ||
          address.district ||
          address.municipality ||
          address.suburb ||
          "",
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

  private async forwardGeocodeCity(
    query: string,
  ): Promise<{ lat: number; lng: number } | null> {
    const raw = String(query || "").trim();
    if (!raw) {
      return null;
    }

    const normalized = this.normalizeForSearch(raw);
    const variants = Array.from(
      new Set([
        raw,
        `${raw}, Turkiye`,
        normalized,
        normalized ? `${normalized}, Turkiye` : "",
      ].filter((item) => item.trim().length > 0)),
    );

    for (const variant of variants) {
      const resolved = await this.forwardGeocodeByQuery(variant);
      if (resolved) {
        return resolved;
      }
    }

    return null;
  }

  private async forwardGeocodeByQuery(
    query: string,
  ): Promise<{ lat: number; lng: number } | null> {
    try {
      const response = await axios.get(`${this.nominatimBaseUrl}/search`, {
        params: {
          format: "jsonv2",
          q: query,
          countrycodes: "tr",
          addressdetails: 1,
          limit: 3,
        },
        timeout: 8000,
        headers: {
          "User-Agent": "ridesharing-app/1.0",
        },
      });

      const rows = Array.isArray(response.data) ? response.data : [];
      for (const row of rows) {
        const lat = Number(row?.lat);
        const lng = Number(row?.lon);
        if (!Number.isFinite(lat) || !Number.isFinite(lng)) {
          continue;
        }
        if (!this.isWithinTurkey(lat, lng)) {
          continue;
        }
        return { lat, lng };
      }

      return null;
    } catch {
      return null;
    }
  }

  private extractDeviceTokens(preferences: any): string[] {
    if (!preferences) return [];
    const parsed =
      typeof preferences === "string"
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
      return tokens.filter((t) => typeof t === "string" && t.length > 0);
    }
    if (
      typeof parsed?.deviceToken === "string" &&
      parsed.deviceToken.length > 0
    ) {
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
    this.validateCoordinatePair("kalkis", departureLat, departureLng);
    this.validateCoordinatePair("varis", arrivalLat, arrivalLng);
  }

  private validateCoordinatePair(
    label: string,
    lat?: number,
    lng?: number,
  ): void {
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
    return (
      lat >= this.turkeyBounds.minLat &&
      lat <= this.turkeyBounds.maxLat &&
      lng >= this.turkeyBounds.minLng &&
      lng <= this.turkeyBounds.maxLng
    );
  }
}
