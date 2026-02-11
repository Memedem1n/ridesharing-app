import {
    IsString,
    IsNotEmpty,
    IsNumber,
    IsBoolean,
    IsOptional,
    Min,
    Max,
    IsEnum,
} from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export enum VehicleOwnershipType {
    SELF = 'self',
    RELATIVE = 'relative',
}

export enum VehicleOwnerRelation {
    FATHER = 'father',
    MOTHER = 'mother',
    UNCLE = 'uncle',
    AUNT = 'aunt',
    SIBLING = 'sibling',
    SPOUSE = 'spouse',
    GRANDPARENT = 'grandparent',
}

export class CreateVehicleDto {
    @ApiProperty({ example: '34ABC123' })
    @IsNotEmpty()
    @IsString()
    licensePlate: string;

    @ApiProperty({ example: '34-AB-123456' })
    @IsNotEmpty()
    @IsString()
    registrationNumber: string;

    @ApiProperty({ enum: VehicleOwnershipType, default: VehicleOwnershipType.SELF })
    @IsNotEmpty()
    @IsEnum(VehicleOwnershipType)
    ownershipType: VehicleOwnershipType;

    @ApiPropertyOptional({ example: 'Ahmet Yilmaz' })
    @IsOptional()
    @IsString()
    ownerFullName?: string;

    @ApiPropertyOptional({ enum: VehicleOwnerRelation })
    @IsOptional()
    @IsEnum(VehicleOwnerRelation)
    ownerRelation?: VehicleOwnerRelation;

    @ApiProperty({ example: '/uploads/registrations/sample.png' })
    @IsNotEmpty()
    @IsString()
    registrationImage: string;

    @ApiProperty({ example: 'Toyota' })
    @IsNotEmpty()
    @IsString()
    brand: string;

    @ApiProperty({ example: 'Corolla' })
    @IsNotEmpty()
    @IsString()
    model: string;

    @ApiProperty({ example: 2022 })
    @IsNotEmpty()
    @IsNumber()
    year: number;

    @ApiPropertyOptional({ example: 'Beyaz' })
    @IsOptional()
    @IsString()
    color?: string;

    @ApiProperty({ example: 4 })
    @IsNotEmpty()
    @IsNumber()
    @Min(1)
    @Max(8)
    seats: number;

    @ApiPropertyOptional({ default: true })
    @IsOptional()
    @IsBoolean()
    hasAc?: boolean;

    @ApiPropertyOptional({ default: false })
    @IsOptional()
    @IsBoolean()
    allowsPets?: boolean;

    @ApiPropertyOptional({ default: false })
    @IsOptional()
    @IsBoolean()
    allowsSmoking?: boolean;
}

export class UpdateVehicleDto {
    @ApiPropertyOptional()
    @IsOptional()
    @IsString()
    color?: string;

    @ApiPropertyOptional()
    @IsOptional()
    @IsNumber()
    seats?: number;

    @ApiPropertyOptional()
    @IsOptional()
    @IsBoolean()
    hasAc?: boolean;

    @ApiPropertyOptional()
    @IsOptional()
    @IsBoolean()
    allowsPets?: boolean;

    @ApiPropertyOptional()
    @IsOptional()
    @IsBoolean()
    allowsSmoking?: boolean;

    @ApiPropertyOptional()
    @IsOptional()
    @IsString()
    registrationImage?: string;

    @ApiPropertyOptional({ enum: VehicleOwnershipType })
    @IsOptional()
    @IsEnum(VehicleOwnershipType)
    ownershipType?: VehicleOwnershipType;

    @ApiPropertyOptional()
    @IsOptional()
    @IsString()
    ownerFullName?: string;

    @ApiPropertyOptional({ enum: VehicleOwnerRelation })
    @IsOptional()
    @IsEnum(VehicleOwnerRelation)
    ownerRelation?: VehicleOwnerRelation;

    @ApiPropertyOptional()
    @IsOptional()
    @IsString()
    registrationNumber?: string;
}

export class VehicleResponseDto {
    @ApiProperty()
    id: string;

    @ApiProperty()
    licensePlate: string;

    @ApiPropertyOptional()
    registrationNumber?: string;

    @ApiProperty({ enum: VehicleOwnershipType })
    ownershipType: VehicleOwnershipType;

    @ApiPropertyOptional()
    ownerFullName?: string;

    @ApiPropertyOptional({ enum: VehicleOwnerRelation })
    ownerRelation?: VehicleOwnerRelation;

    @ApiProperty()
    brand: string;

    @ApiProperty()
    model: string;

    @ApiProperty()
    year: number;

    @ApiPropertyOptional()
    color?: string;

    @ApiProperty()
    seats: number;

    @ApiProperty()
    hasAc: boolean;

    @ApiProperty()
    allowsPets: boolean;

    @ApiProperty()
    allowsSmoking: boolean;

    @ApiProperty()
    verified: boolean;

    @ApiPropertyOptional()
    registrationImage?: string;

    @ApiProperty()
    createdAt: Date;
}
