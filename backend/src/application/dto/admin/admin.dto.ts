import { IsEnum, IsNotEmpty, IsNumber, IsOptional, IsString, Min } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

export class AdminVerificationUpdateDto {
    @ApiProperty({ enum: ['pending', 'verified', 'rejected'] })
    @IsEnum(['pending', 'verified', 'rejected'])
    status: 'pending' | 'verified' | 'rejected';

    @ApiPropertyOptional()
    @IsOptional()
    @IsString()
    note?: string;
}

export class AdminBusPriceDto {
    @ApiProperty()
    @IsNotEmpty()
    @IsString()
    from: string;

    @ApiProperty()
    @IsNotEmpty()
    @IsString()
    to: string;

    @ApiProperty()
    @IsNumber()
    @Min(0)
    price: number;

    @ApiPropertyOptional()
    @IsOptional()
    @IsString()
    source?: string;
}

export class AdminVerificationUserDto {
    @ApiProperty()
    id: string;

    @ApiProperty()
    fullName: string;

    @ApiProperty()
    phone: string;

    @ApiProperty()
    email: string;

    @ApiProperty()
    identityStatus: string;

    @ApiProperty()
    licenseStatus: string;

    @ApiProperty()
    criminalRecordStatus: string;

    @ApiPropertyOptional()
    identityDocumentUrl?: string;

    @ApiPropertyOptional()
    licenseDocumentUrl?: string;

    @ApiPropertyOptional()
    criminalRecordDocumentUrl?: string;

    @ApiProperty()
    verified: boolean;

    @ApiProperty()
    createdAt: Date;
}
