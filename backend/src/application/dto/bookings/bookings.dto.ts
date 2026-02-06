import { IsString, IsNotEmpty, IsNumber, IsOptional, IsUUID, IsEnum, Min, Max } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export enum BookingStatus {
    PENDING = 'pending',
    CONFIRMED = 'confirmed',
    CHECKED_IN = 'checked_in',
    COMPLETED = 'completed',
    EXPIRED = 'expired',
    CANCELLED_BY_PASSENGER = 'cancelled_by_passenger',
    CANCELLED_BY_DRIVER = 'cancelled_by_driver',
}

export enum PaymentStatus {
    PENDING = 'pending',
    PAID = 'paid',
    REFUNDED = 'refunded',
    PARTIALLY_REFUNDED = 'partially_refunded',
}

export enum ItemType {
    PERSON = 'person',
    PET = 'pet',
    CARGO = 'cargo',
    FOOD = 'food',
}

export class CreateBookingDto {
    @ApiProperty()
    @IsNotEmpty()
    @IsUUID()
    tripId: string;

    @ApiProperty({ example: 2 })
    @IsNotEmpty()
    @IsNumber()
    @Min(1)
    @Max(8)
    seats: number;

    @ApiProperty({ enum: ItemType, default: ItemType.PERSON })
    @IsOptional()
    @IsEnum(ItemType)
    itemType?: ItemType = ItemType.PERSON;

    @ApiPropertyOptional({ description: 'Pet/cargo details' })
    @IsOptional()
    itemDetails?: PetDetails | CargoDetails;
}

export class PetDetails {
    @ApiProperty()
    name: string;

    @ApiProperty()
    species: string;

    @ApiProperty()
    breed?: string;

    @ApiProperty()
    weight?: number;

    @ApiProperty()
    vaccinationProof?: boolean;
}

export class CargoDetails {
    @ApiProperty()
    description: string;

    @ApiProperty()
    weight: number;

    @ApiProperty()
    dimensions?: string;

    @ApiProperty()
    fragile?: boolean;
}

export class ProcessPaymentDto {
    @ApiProperty()
    @IsNotEmpty()
    @IsUUID()
    bookingId: string;

    @ApiProperty({ description: 'Credit card token from İyzico' })
    @IsNotEmpty()
    @IsString()
    cardToken: string;
}

export class CheckInDto {
    @ApiProperty({ description: 'QR code content' })
    @IsNotEmpty()
    @IsString()
    qrCode: string;
}

export class BookingResponseDto {
    @ApiProperty()
    id: string;

    @ApiProperty()
    tripId: string;

    @ApiProperty()
    trip: {
        departureCity: string;
        arrivalCity: string;
        departureTime: Date;
        pricePerSeat: number;
    };

    @ApiProperty()
    passengerId: string;

    @ApiProperty()
    passenger: {
        fullName: string;
        phone: string;
        profilePhotoUrl?: string;
    };

    @ApiProperty({ enum: BookingStatus })
    status: BookingStatus;

    @ApiProperty()
    seats: number;

    @ApiProperty()
    priceTotal: number;

    @ApiProperty()
    commissionAmount: number;

    @ApiProperty({ enum: ItemType })
    itemType: ItemType;

    @ApiPropertyOptional()
    itemDetails?: any;

    @ApiProperty()
    qrCode: string;

    @ApiPropertyOptional()
    checkedInAt?: Date;

    @ApiPropertyOptional()
    expiresAt?: Date;

    @ApiProperty({ enum: PaymentStatus })
    paymentStatus: PaymentStatus;

    @ApiProperty()
    createdAt: Date;
}

export class BookingListResponseDto {
    @ApiProperty({ type: [BookingResponseDto] })
    bookings: BookingResponseDto[];

    @ApiProperty()
    total: number;
}
