import { BadRequestException } from "@nestjs/common";
import { Test, TestingModule } from "@nestjs/testing";
import { ConfigService } from "@nestjs/config";
import { TripsService } from "./trips.service";
import { PrismaService } from "@infrastructure/database/prisma.service";
import { BusPriceScraperService } from "@infrastructure/scraper/bus-price-scraper.service";
import { RedisService } from "@infrastructure/cache/redis.service";
import { FcmService } from "@infrastructure/notifications/fcm.service";
import { NetgsmService } from "@infrastructure/notifications/netgsm.service";
import { IyzicoService } from "@infrastructure/payment/iyzico.service";
import { RoutingProviderResolver } from "@infrastructure/maps/routing-provider-resolver.service";

describe("TripsService", () => {
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
      if (key === "TRIP_SEARCH_CACHE_TTL_SECONDS") return 120;
      return undefined;
    }),
  };

  const mockIyzicoService = {
    refundPayment: jest.fn().mockResolvedValue({ success: true }),
  };

  const mockRoutingProvider = {
    name: "osrm",
    getRouteAlternatives: jest.fn(),
  };

  const mockRoutingProviderResolver = {
    getProvider: jest.fn().mockReturnValue(mockRoutingProvider),
  };

  const baseTrip = {
    id: "trip-1",
    driverId: "driver-1",
    status: "published",
    type: "people",
    departureCity: "Istanbul",
    arrivalCity: "Ankara",
    departureAddress: "Kadikoy",
    arrivalAddress: "Kizilay",
    departureTime: new Date("2026-02-09T08:00:00Z"),
    availableSeats: 3,
    pricePerSeat: 150,
    allowsPets: false,
    allowsCargo: false,
    womenOnly: false,
    instantBooking: true,
    description: null,
    distanceKm: null,
    createdAt: new Date("2026-02-08T10:00:00Z"),
    driver: {
      id: "driver-1",
      fullName: "Driver",
      profilePhotoUrl: null,
      ratingAvg: 4.6,
      totalTrips: 20,
    },
    vehicle: {
      id: "vehicle-1",
      brand: "Toyota",
      model: "Corolla",
      color: "White",
      licensePlate: "34ABC123",
    },
  };

  beforeEach(async () => {
    const module: TestingModule = await Test.createTestingModule({
      providers: [
        TripsService,
        { provide: PrismaService, useValue: mockPrismaService },
        {
          provide: BusPriceScraperService,
          useValue: mockBusPriceScraperService,
        },
        { provide: RedisService, useValue: mockRedisService },
        { provide: FcmService, useValue: mockFcmService },
        { provide: NetgsmService, useValue: mockNetgsmService },
        { provide: ConfigService, useValue: mockConfigService },
        { provide: IyzicoService, useValue: mockIyzicoService },
        {
          provide: RoutingProviderResolver,
          useValue: mockRoutingProviderResolver,
        },
      ],
    }).compile();

    service = module.get<TripsService>(TripsService);
    jest.clearAllMocks();
  });

  afterEach(() => {
    jest.restoreAllMocks();
  });

  it("accepts coordinates inside Turkiye bounds on create", async () => {
    mockPrismaService.vehicle.findFirst.mockResolvedValue({ id: "vehicle-1" });
    mockPrismaService.trip.create.mockResolvedValue(baseTrip);

    const result = await service.create("driver-1", {
      vehicleId: "vehicle-1",
      type: "people" as any,
      departureCity: "Istanbul",
      arrivalCity: "Ankara",
      departureAddress: "Kadikoy",
      arrivalAddress: "Kizilay",
      departureLat: 41.01,
      departureLng: 29.0,
      arrivalLat: 39.92,
      arrivalLng: 32.85,
      departureTime: "2026-02-09T08:00:00Z",
      availableSeats: 3,
      pricePerSeat: 150,
    });

    expect(result.id).toBe("trip-1");
  });

  it("rejects coordinates outside Turkiye bounds on create", async () => {
    mockPrismaService.vehicle.findFirst.mockResolvedValue({ id: "vehicle-1" });

    await expect(
      service.create("driver-1", {
        vehicleId: "vehicle-1",
        type: "people" as any,
        departureCity: "Paris",
        arrivalCity: "Ankara",
        departureLat: 48.85,
        departureLng: 2.35,
        arrivalLat: 39.92,
        arrivalLng: 32.85,
        departureTime: "2026-02-09T08:00:00Z",
        availableSeats: 3,
        pricePerSeat: 150,
      }),
    ).rejects.toThrow(BadRequestException);
  });

  it("rejects partial coordinates on update", async () => {
    mockPrismaService.trip.findUnique.mockResolvedValue({
      id: "trip-1",
      driverId: "driver-1",
    });

    await expect(
      service.update("trip-1", "driver-1", {
        departureLat: 41.01,
      }),
    ).rejects.toThrow(BadRequestException);
  });

  it("builds route preview by geocoding departure and arrival city names", async () => {
    jest
      .spyOn(service as any, "forwardGeocodeCity")
      .mockImplementation(async (query: string) => {
        if (query === "Istanbul") return { lat: 41.0082, lng: 28.9784 };
        if (query === "Ankara") return { lat: 39.9208, lng: 32.8541 };
        return null;
      });
    jest.spyOn(service as any, "inferViaCities").mockResolvedValue([
      {
        city: "Eskisehir",
        district: "Odunpazari",
        pickupSuggestions: ["Otogar"],
      },
    ]);
    mockRoutingProvider.getRouteAlternatives.mockResolvedValue([
      {
        provider: "osrm",
        distanceKm: 451.2,
        durationMin: 290,
        points: [
          { lat: 41.0082, lng: 28.9784 },
          { lat: 40.6, lng: 30.5 },
          { lat: 39.9208, lng: 32.8541 },
        ],
      },
    ]);

    const result = await service.routePreview({
      departureCity: "Istanbul",
      arrivalCity: "Ankara",
    });

    expect(result.provider).toBe("osrm");
    expect(result.alternatives).toHaveLength(1);
    expect(result.alternatives[0].id).toBe("route_1");
    expect(result.alternatives[0].route.points).toHaveLength(3);
    expect(result.alternatives[0].viaCities).toHaveLength(1);
    expect(mockRoutingProvider.getRouteAlternatives).toHaveBeenCalledWith(
      expect.objectContaining({
        alternatives: 5,
      }),
    );
  });

  it("returns all unique alternatives from provider up to max limit", async () => {
    jest
      .spyOn(service as any, "forwardGeocodeCity")
      .mockImplementation(async (query: string) => {
        if (query === "Istanbul") return { lat: 41.0082, lng: 28.9784 };
        if (query === "Ankara") return { lat: 39.9208, lng: 32.8541 };
        return null;
      });
    jest.spyOn(service as any, "inferViaCities").mockResolvedValue([]);
    mockRoutingProvider.getRouteAlternatives.mockResolvedValue([
      {
        provider: "osrm",
        distanceKm: 451.2,
        durationMin: 290,
        points: [
          { lat: 41.0082, lng: 28.9784 },
          { lat: 40.8, lng: 30.2 },
          { lat: 39.9208, lng: 32.8541 },
        ],
      },
      {
        provider: "osrm",
        distanceKm: 472.4,
        durationMin: 315,
        points: [
          { lat: 41.0082, lng: 28.9784 },
          { lat: 40.4, lng: 31.4 },
          { lat: 39.9208, lng: 32.8541 },
        ],
      },
      {
        provider: "osrm",
        distanceKm: 498.6,
        durationMin: 339,
        points: [
          { lat: 41.0082, lng: 28.9784 },
          { lat: 40.2, lng: 32.1 },
          { lat: 39.9208, lng: 32.8541 },
        ],
      },
    ]);

    const result = await service.routePreview({
      departureCity: "Istanbul",
      arrivalCity: "Ankara",
    });

    expect(result.provider).toBe("osrm");
    expect(result.alternatives).toHaveLength(3);
    expect(mockRoutingProvider.getRouteAlternatives).toHaveBeenCalledTimes(1);
    expect(mockRoutingProvider.getRouteAlternatives).toHaveBeenCalledWith(
      expect.objectContaining({
        alternatives: 5,
      }),
    );
  });

  it("builds fallback route variants when provider returns a single route", async () => {
    jest
      .spyOn(service as any, "forwardGeocodeCity")
      .mockImplementation(async (query: string) => {
        if (query === "Istanbul") return { lat: 41.0082, lng: 28.9784 };
        if (query === "Ankara") return { lat: 39.9208, lng: 32.8541 };
        return null;
      });
    jest
      .spyOn(service as any, "inferViaCities")
      .mockResolvedValue([
        {
          city: "Eskisehir",
          lat: 39.7767,
          lng: 30.5206,
          pickupSuggestions: ["Otogar"],
        },
      ]);

    const primaryPath = {
      provider: "osrm",
      distanceKm: 451.2,
      durationMin: 290,
      points: [
        { lat: 41.0082, lng: 28.9784 },
        { lat: 40.6, lng: 30.5 },
        { lat: 39.9208, lng: 32.8541 },
      ],
    };
    const variantPath = {
      provider: "osrm",
      distanceKm: 478.6,
      durationMin: 322,
      points: [
        { lat: 41.0082, lng: 28.9784 },
        { lat: 39.7767, lng: 30.5206 },
        { lat: 39.9208, lng: 32.8541 },
      ],
    };

    mockRoutingProvider.getRouteAlternatives.mockImplementation(
      async (input: any) => {
        if (Array.isArray(input?.viaPoints) && input.viaPoints.length > 0) {
          return [variantPath];
        }
        return [primaryPath];
      },
    );

    const result = await service.routePreview({
      departureCity: "Istanbul",
      arrivalCity: "Ankara",
    });

    expect(result.alternatives.length).toBeGreaterThan(1);
    const waypointCalls = mockRoutingProvider.getRouteAlternatives.mock.calls
      .map((call) => call[0])
      .filter(
        (payload: any) =>
          Array.isArray(payload?.viaPoints) && payload.viaPoints.length > 0,
      );
    expect(waypointCalls.length).toBeGreaterThan(0);
  });

  it("keeps via cities at city level and excludes departure/arrival cities", async () => {
    jest
      .spyOn(service as any, "reverseGeocodeCity")
      .mockResolvedValueOnce({ city: "Istanbul", district: "Kadikoy" })
      .mockResolvedValueOnce({ city: "Kocaeli", district: "Gebze" })
      .mockResolvedValueOnce({ city: "Kocaeli", district: "Izmit" })
      .mockResolvedValueOnce({ city: "Eskisehir", district: "Tepebasi" })
      .mockResolvedValueOnce({ city: "Ankara", district: "Cankaya" });

    const viaCities = await (service as any).inferViaCities(
      [
        { lat: 41.0082, lng: 28.9784 },
        { lat: 40.9, lng: 29.5 },
        { lat: 40.2, lng: 30.3 },
        { lat: 39.8, lng: 30.6 },
        { lat: 39.9208, lng: 32.8541 },
      ],
      {
        departureCity: "Istanbul",
        arrivalCity: "Ankara",
        sampleSize: 5,
        maxCities: 5,
      },
    );

    expect(viaCities).toHaveLength(2);
    expect(viaCities.map((city: any) => city.city)).toEqual([
      "Kocaeli",
      "Eskisehir",
    ]);
    expect(viaCities.every((city: any) => city.district === undefined)).toBe(
      true,
    );
  });

  it("rejects route preview when no departure/arrival info is provided", async () => {
    await expect(service.routePreview({})).rejects.toThrow(BadRequestException);
  });

  it("estimates route distance, duration and cost", async () => {
    jest
      .spyOn(service as any, "forwardGeocodeCity")
      .mockImplementation(async (query: string) => {
        if (query === "Istanbul") return { lat: 41.0082, lng: 28.9784 };
        if (query === "Ankara") return { lat: 39.9208, lng: 32.8541 };
        return null;
      });
    mockRoutingProvider.getRouteAlternatives.mockResolvedValue([
      {
        provider: "osrm",
        distanceKm: 451.2,
        durationMin: 290,
        points: [
          { lat: 41.0082, lng: 28.9784 },
          { lat: 39.9208, lng: 32.8541 },
        ],
      },
    ]);

    const result = await service.estimateRouteCost({
      departureCity: "Istanbul",
      arrivalCity: "Ankara",
      tripType: "people" as any,
      peakTraffic: false,
    });

    expect(result.provider).toBe("osrm");
    expect(result.distanceKm).toBe(451.2);
    expect(result.durationMin).toBe(290);
    expect(result.estimatedCost).toBeGreaterThan(0);
    expect(result.currency).toBe("TRY");
    expect(result.breakdown.distanceFee).toBeGreaterThan(0);
  });
});
