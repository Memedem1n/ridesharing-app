import { IsString, IsNotEmpty, IsNumber, IsOptional, IsUUID, IsEnum, Min, Max, MinLength, MaxLength } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export enum BookingStatus {
    PENDING = 'pending',
    AWAITING_PAYMENT = 'awaiting_payment',
    CONFIRMED = 'confirmed',
    CHECKED_IN = 'checked_in',
    COMPLETED = 'completed',
    DISPUTED = 'disputed',
    REJECTED = 'rejected',
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

    @ApiPropertyOptional({ description: 'Optional segment departure query (for partial route pricing)' })
    @IsOptional()
    @IsString()
    requestedFrom?: string;

    @ApiPropertyOptional({ description: 'Optional segment arrival query (for partial route pricing)' })
    @IsOptional()
    @IsString()
    requestedTo?: string;
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

export class CheckInByPnrDto {
    @ApiProperty({ description: '6-character PNR code' })
    @IsNotEmpty()
    @IsString()
    @MinLength(6)
    @MaxLength(6)
    pnrCode: string;

    @ApiProperty({ description: 'Trip id that this PNR belongs to' })
    @IsNotEmpty()
    @IsUUID()
    tripId: string;
}

export class RejectBookingDto {
    @ApiPropertyOptional({ description: 'Optional reject reason for moderation/audit' })
    @IsOptional()
    @IsString()
    reason?: string;
}

export class RaiseDisputeDto {
    @ApiProperty({ description: 'Dispute reason' })
    @IsNotEmpty()
    @IsString()
    @MinLength(5)
    @MaxLength(500)
    reason: string;
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

    @ApiPropertyOptional({
        type: Object,
        example: {
            departure: 'Izmir',
            arrival: 'Mugla',
            distanceKm: 92.4,
            ratio: 0.33,
            pricePerSeat: 500,
        },
    })
    segment?: {
        departure: string;
        arrival: string;
        distanceKm: number;
        ratio: number;
        pricePerSeat: number;
    };

    @ApiProperty()
    qrCode: string;

    @ApiPropertyOptional()
    pnrCode?: string;

    @ApiPropertyOptional()
    checkedInAt?: Date;

    @ApiPropertyOptional()
    acceptedAt?: Date;

    @ApiPropertyOptional()
    paidAt?: Date;

    @ApiPropertyOptional()
    completedAt?: Date;

    @ApiPropertyOptional()
    completionSource?: string;

    @ApiPropertyOptional()
    disputeStatus?: string;

    @ApiPropertyOptional()
    disputedAt?: Date;

    @ApiPropertyOptional()
    disputeReason?: string;

    @ApiPropertyOptional()
    disputeDeadlineAt?: Date;

    @ApiPropertyOptional()
    payout10ReleasedAt?: Date;

    @ApiPropertyOptional()
    payout90ReleasedAt?: Date;

    @ApiPropertyOptional()
    payoutHoldReason?: string;

    @ApiPropertyOptional()
    expiresAt?: Date;

    @ApiPropertyOptional()
    paymentDueAt?: Date;

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
