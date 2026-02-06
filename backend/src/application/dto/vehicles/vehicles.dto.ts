import { IsString, IsNotEmpty, IsNumber, IsBoolean, IsOptional, Min, Max } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class CreateVehicleDto {
    @ApiProperty({ example: '34ABC123' })
    @IsNotEmpty()
    @IsString()
    licensePlate: string;

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
}

export class VehicleResponseDto {
    @ApiProperty()
    id: string;

    @ApiProperty()
    licensePlate: string;

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
