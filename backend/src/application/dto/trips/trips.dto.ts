import { IsString, IsNotEmpty, IsNumber, IsOptional, IsBoolean, IsEnum, IsDateString, IsUUID, Min, Max } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';

export enum TripType {
    PEOPLE = 'people',
    PETS = 'pets',
    CARGO = 'cargo',
    FOOD = 'food',
}

export enum TripStatus {
    DRAFT = 'draft',
    PUBLISHED = 'published',
    FULL = 'full',
    IN_PROGRESS = 'in_progress',
    COMPLETED = 'completed',
    CANCELLED = 'cancelled',
}

export enum PetLocation {
    FRONT = 'front',
    BACK = 'back',
    TRUNK = 'trunk',
}

export class CreateTripDto {
    @ApiProperty()
    @IsNotEmpty()
    @IsUUID()
    vehicleId: string;

    @ApiProperty({ enum: TripType, default: TripType.PEOPLE })
    @IsEnum(TripType)
    type: TripType = TripType.PEOPLE;

    @ApiProperty({ example: 'İstanbul' })
    @IsNotEmpty()
    @IsString()
    departureCity: string;

    @ApiProperty({ example: 'Ankara' })
    @IsNotEmpty()
    @IsString()
    arrivalCity: string;

    @ApiPropertyOptional({ example: 'Kadıköy, Moda' })
    @IsOptional()
    @IsString()
    departureAddress?: string;

    @ApiPropertyOptional({ example: 'Kızılay' })
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

    @ApiProperty({ example: '2026-02-05T09:00:00Z' })
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
    preferences?: Record<string, any>;
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
}

export class SearchTripsDto {
    @ApiPropertyOptional({ example: 'İstanbul' })
    @IsOptional()
    @IsString()
    from?: string;

    @ApiPropertyOptional({ example: 'Ankara' })
    @IsOptional()
    @IsString()
    to?: string;

    @ApiPropertyOptional({ example: '2026-02-05' })
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

    @ApiProperty()
    departureTime: Date;

    @ApiPropertyOptional()
    estimatedArrivalTime?: Date;

    @ApiProperty()
    availableSeats: number;

    @ApiProperty()
    pricePerSeat: number;

    @ApiProperty()
    allowsPets: boolean;

    @ApiProperty()
    womenOnly: boolean;

    @ApiPropertyOptional()
    distanceKm?: number;

    @ApiPropertyOptional()
    busReferencePrice?: number;

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
