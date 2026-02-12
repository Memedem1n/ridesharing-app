import {
  IsString,
  IsNotEmpty,
  IsNumber,
  IsOptional,
  IsBoolean,
  IsEnum,
  IsDateString,
  IsUUID,
  Min,
  Max,
  IsArray,
  ValidateNested,
} from "class-validator";
import { ApiProperty, ApiPropertyOptional } from "@nestjs/swagger";
import { Type } from "class-transformer";

export enum TripType {
  PEOPLE = "people",
  PETS = "pets",
  CARGO = "cargo",
  FOOD = "food",
}

export enum TripStatus {
  DRAFT = "draft",
  PUBLISHED = "published",
  FULL = "full",
  IN_PROGRESS = "in_progress",
  COMPLETED = "completed",
  CANCELLED = "cancelled",
}

export enum PetLocation {
  FRONT = "front",
  BACK = "back",
  TRUNK = "trunk",
}

export enum PickupType {
  BUS_TERMINAL = "bus_terminal",
  REST_STOP = "rest_stop",
  CITY_CENTER = "city_center",
  ADDRESS = "address",
}

export class RoutePointDto {
  @ApiProperty()
  @IsNumber()
  lat: number;

  @ApiProperty()
  @IsNumber()
  lng: number;
}

export class RouteBoundingBoxDto {
  @ApiProperty()
  @IsNumber()
  minLat: number;

  @ApiProperty()
  @IsNumber()
  minLng: number;

  @ApiProperty()
  @IsNumber()
  maxLat: number;

  @ApiProperty()
  @IsNumber()
  maxLng: number;
}

export class ViaCityDto {
  @ApiProperty({ example: "Eskisehir" })
  @IsString()
  city: string;

  @ApiPropertyOptional({ example: "Tepebasi" })
  @IsOptional()
  @IsString()
  district?: string;

  @ApiPropertyOptional({ example: 39.7767 })
  @IsOptional()
  @IsNumber()
  lat?: number;

  @ApiPropertyOptional({ example: 30.5206 })
  @IsOptional()
  @IsNumber()
  lng?: number;

  @ApiPropertyOptional({ type: [String] })
  @IsOptional()
  @IsArray()
  @IsString({ each: true })
  pickupSuggestions?: string[];
}

export class RouteSnapshotDto {
  @ApiProperty({ example: "osrm" })
  @IsString()
  provider: string;

  @ApiProperty({ example: 452.4 })
  @IsNumber()
  distanceKm: number;

  @ApiProperty({ example: 296.3 })
  @IsNumber()
  durationMin: number;

  @ApiPropertyOptional({ type: [RoutePointDto] })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => RoutePointDto)
  points?: RoutePointDto[];

  @ApiPropertyOptional({ type: RouteBoundingBoxDto })
  @IsOptional()
  @ValidateNested()
  @Type(() => RouteBoundingBoxDto)
  bbox?: RouteBoundingBoxDto;
}

export class PickupPolicyDto {
  @ApiProperty({ example: "Eskisehir" })
  @IsString()
  city: string;

  @ApiPropertyOptional({ example: "Tepebasi" })
  @IsOptional()
  @IsString()
  district?: string;

  @ApiProperty({ example: true })
  @IsBoolean()
  pickupAllowed: boolean;

  @ApiProperty({ enum: PickupType })
  @IsEnum(PickupType)
  pickupType: PickupType;

  @ApiPropertyOptional({ example: "Eskisehir Otogar kuzey girisi" })
  @IsOptional()
  @IsString()
  note?: string;
}

export class RoutePreviewDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  departureLat?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  departureLng?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  arrivalLat?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  arrivalLng?: number;

  @ApiPropertyOptional({ example: "Istanbul" })
  @IsOptional()
  @IsString()
  departureCity?: string;

  @ApiPropertyOptional({ example: "Ankara" })
  @IsOptional()
  @IsString()
  arrivalCity?: string;
}

export class RouteAlternativeDto {
  @ApiProperty()
  id: string;

  @ApiProperty({ type: RouteSnapshotDto })
  route: RouteSnapshotDto;

  @ApiProperty({ type: [ViaCityDto] })
  viaCities: ViaCityDto[];
}

export class RoutePreviewResponseDto {
  @ApiProperty({ example: "osrm" })
  provider: string;

  @ApiProperty({ type: [RouteAlternativeDto] })
  alternatives: RouteAlternativeDto[];
}

export class RouteEstimateDto {
  @ApiPropertyOptional({ example: "Istanbul" })
  @IsOptional()
  @IsString()
  departureCity?: string;

  @ApiPropertyOptional({ example: "Ankara" })
  @IsOptional()
  @IsString()
  arrivalCity?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  departureLat?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  departureLng?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  arrivalLat?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  arrivalLng?: number;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  @Min(1)
  @Max(8)
  seats?: number;

  @ApiPropertyOptional({ enum: TripType, default: TripType.PEOPLE })
  @IsOptional()
  @IsEnum(TripType)
  tripType?: TripType;

  @ApiPropertyOptional({ example: false, default: false })
  @IsOptional()
  @Type(() => Boolean)
  @IsBoolean()
  peakTraffic?: boolean;
}

export class RouteEstimateBreakdownDto {
  @ApiProperty()
  @IsNumber()
  baseFee: number;

  @ApiProperty()
  @IsNumber()
  distanceFee: number;

  @ApiProperty()
  @IsNumber()
  durationFee: number;

  @ApiProperty()
  @IsNumber()
  platformFee: number;

  @ApiProperty()
  @IsNumber()
  tripTypeMultiplier: number;

  @ApiProperty()
  @IsNumber()
  trafficMultiplier: number;
}

export class RouteEstimateResponseDto {
  @ApiProperty({ example: "osrm" })
  provider: string;

  @ApiProperty({ example: 451.2 })
  distanceKm: number;

  @ApiProperty({ example: 290.4 })
  durationMin: number;

  @ApiProperty({ example: 1240.5 })
  estimatedCost: number;

  @ApiProperty({ example: "TRY" })
  currency: string;

  @ApiProperty({ type: RouteEstimateBreakdownDto })
  breakdown: RouteEstimateBreakdownDto;
}

export class CreateTripDto {
  @ApiProperty()
  @IsNotEmpty()
  @IsUUID()
  vehicleId: string;

  @ApiProperty({ enum: TripType, default: TripType.PEOPLE })
  @IsEnum(TripType)
  type: TripType = TripType.PEOPLE;

  @ApiProperty({ example: "İstanbul" })
  @IsNotEmpty()
  @IsString()
  departureCity: string;

  @ApiProperty({ example: "Ankara" })
  @IsNotEmpty()
  @IsString()
  arrivalCity: string;

  @ApiPropertyOptional({ example: "Kadıköy, Moda" })
  @IsOptional()
  @IsString()
  departureAddress?: string;

  @ApiPropertyOptional({ example: "Kızılay" })
  @IsOptional()
  @IsString()
  arrivalAddress?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  departureLat?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  departureLng?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  arrivalLat?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  arrivalLng?: number;

  @ApiProperty({ example: "2026-02-05T09:00:00Z" })
  @IsNotEmpty()
  @IsDateString()
  departureTime: string;

  @ApiProperty({ example: 3 })
  @IsNotEmpty()
  @IsNumber()
  @Min(1)
  @Max(8)
  availableSeats: number;

  @ApiProperty({ example: 150 })
  @IsNotEmpty()
  @IsNumber()
  @Min(0)
  pricePerSeat: number;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  allowsPets?: boolean;

  @ApiPropertyOptional({ enum: PetLocation })
  @IsOptional()
  @IsEnum(PetLocation)
  petLocation?: PetLocation;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  allowsCargo?: boolean;

  @ApiPropertyOptional({ example: 50 })
  @IsOptional()
  @IsNumber()
  maxCargoWeight?: number;

  @ApiPropertyOptional({ default: false })
  @IsOptional()
  @IsBoolean()
  womenOnly?: boolean;

  @ApiPropertyOptional({ default: true })
  @IsOptional()
  @IsBoolean()
  instantBooking?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  description?: string;

  @ApiPropertyOptional()
  @IsOptional()
  preferences?: Record<string, any>;

  @ApiPropertyOptional({ type: RouteSnapshotDto })
  @IsOptional()
  @ValidateNested()
  @Type(() => RouteSnapshotDto)
  routeSnapshot?: RouteSnapshotDto;

  @ApiPropertyOptional({ type: [ViaCityDto] })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => ViaCityDto)
  viaCities?: ViaCityDto[];

  @ApiPropertyOptional({ type: [PickupPolicyDto] })
  @IsOptional()
  @IsArray()
  @ValidateNested({ each: true })
  @Type(() => PickupPolicyDto)
  pickupPolicies?: PickupPolicyDto[];
}

export class UpdateTripDto {
  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  availableSeats?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  pricePerSeat?: number;

  @ApiPropertyOptional({ enum: TripStatus })
  @IsOptional()
  @IsEnum(TripStatus)
  status?: TripStatus;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  departureAddress?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsString()
  arrivalAddress?: string;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  departureLat?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  departureLng?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  arrivalLat?: number;

  @ApiPropertyOptional()
  @IsOptional()
  @IsNumber()
  arrivalLng?: number;
}

export class SearchTripsDto {
  @ApiPropertyOptional({ example: "İstanbul" })
  @IsOptional()
  @IsString()
  from?: string;

  @ApiPropertyOptional({ example: "Ankara" })
  @IsOptional()
  @IsString()
  to?: string;

  @ApiPropertyOptional({ example: "2026-02-05" })
  @IsOptional()
  @IsString()
  date?: string;

  @ApiPropertyOptional({ example: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  seats?: number;

  @ApiPropertyOptional({ enum: TripType })
  @IsOptional()
  @IsEnum(TripType)
  type?: TripType;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Boolean)
  @IsBoolean()
  allowsPets?: boolean;

  @ApiPropertyOptional()
  @IsOptional()
  @Type(() => Boolean)
  @IsBoolean()
  womenOnly?: boolean;

  @ApiPropertyOptional({ default: 1 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  page?: number = 1;

  @ApiPropertyOptional({ default: 20 })
  @IsOptional()
  @Type(() => Number)
  @IsNumber()
  limit?: number = 20;
}

export class TripResponseDto {
  @ApiProperty()
  id: string;

  @ApiProperty()
  driverId: string;

  @ApiProperty()
  driver: {
    id: string;
    fullName: string;
    profilePhotoUrl?: string;
    ratingAvg: number;
    totalTrips: number;
  };

  @ApiProperty()
  vehicle: {
    id: string;
    brand: string;
    model: string;
    color?: string;
    licensePlate: string;
  };

  @ApiProperty({ enum: TripStatus })
  status: TripStatus;

  @ApiProperty({ enum: TripType })
  type: TripType;

  @ApiProperty()
  departureCity: string;

  @ApiProperty()
  arrivalCity: string;

  @ApiPropertyOptional()
  departureAddress?: string;

  @ApiPropertyOptional()
  arrivalAddress?: string;

  @ApiPropertyOptional()
  departureLat?: number;

  @ApiPropertyOptional()
  departureLng?: number;

  @ApiPropertyOptional()
  arrivalLat?: number;

  @ApiPropertyOptional()
  arrivalLng?: number;

  @ApiProperty()
  departureTime: Date;

  @ApiPropertyOptional()
  estimatedArrivalTime?: Date;

  @ApiProperty()
  availableSeats: number;

  @ApiProperty()
  pricePerSeat: number;

  @ApiPropertyOptional({ enum: ["full", "partial"] })
  matchType?: "full" | "partial";

  @ApiPropertyOptional({ example: "Izmir" })
  segmentDeparture?: string;

  @ApiPropertyOptional({ example: "Mugla" })
  segmentArrival?: string;

  @ApiPropertyOptional({ example: 92.4 })
  segmentDistanceKm?: number;

  @ApiPropertyOptional({ example: 0.33 })
  segmentRatio?: number;

  @ApiPropertyOptional({ example: 500 })
  segmentPricePerSeat?: number;

  @ApiProperty()
  allowsPets: boolean;

  @ApiProperty()
  allowsCargo: boolean;

  @ApiProperty()
  womenOnly: boolean;

  @ApiProperty()
  instantBooking: boolean;

  @ApiPropertyOptional()
  description?: string;

  @ApiPropertyOptional()
  distanceKm?: number;

  @ApiPropertyOptional()
  busReferencePrice?: number;

  @ApiPropertyOptional({ type: RouteSnapshotDto })
  route?: RouteSnapshotDto;

  @ApiPropertyOptional({ type: [ViaCityDto] })
  viaCities?: ViaCityDto[];

  @ApiPropertyOptional({ type: [PickupPolicyDto] })
  pickupPolicies?: PickupPolicyDto[];

  @ApiPropertyOptional({
    type: Object,
    example: { confirmedSeats: 2, passengerCount: 1 },
  })
  occupancy?: {
    confirmedSeats: number;
    passengerCount: number;
  };

  @ApiPropertyOptional({
    type: [Object],
    example: [
      {
        id: "user-id",
        fullName: "Ali Veli",
        profilePhotoUrl: null,
        ratingAvg: 4.7,
        seats: 1,
      },
    ],
  })
  passengers?: Array<{
    id: string;
    fullName: string;
    profilePhotoUrl?: string;
    ratingAvg: number;
    seats: number;
  }>;

  @ApiPropertyOptional()
  canViewPassengerList?: boolean;

  @ApiPropertyOptional()
  canViewLiveLocation?: boolean;

  @ApiProperty()
  createdAt: Date;
}

export class TripListResponseDto {
  @ApiProperty({ type: [TripResponseDto] })
  trips: TripResponseDto[];

  @ApiProperty()
  total: number;

  @ApiProperty()
  page: number;

  @ApiProperty()
  limit: number;

  @ApiProperty()
  totalPages: number;
}
