import { IsString, IsOptional, IsBoolean, IsEnum, IsDateString, IsNotEmpty, MinLength, MaxLength, IsUrl } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';

// Define UserPreferencesDto FIRST
export class UserPreferencesDto {
    @ApiPropertyOptional()
    @IsOptional()
    @IsString()
    music?: string;

    @ApiPropertyOptional()
    @IsOptional()
    @IsBoolean()
    smoking?: boolean;

    @ApiPropertyOptional()
    @IsOptional()
    @IsBoolean()
    pets?: boolean;

    @ApiPropertyOptional({ enum: ['quiet', 'normal', 'chatty'] })
    @IsOptional()
    @IsEnum(['quiet', 'normal', 'chatty'])
    chattiness?: string;

    @ApiPropertyOptional()
    @IsOptional()
    @IsBoolean()
    ac?: boolean;
}

export class UpdateProfileDto {
    @ApiPropertyOptional()
    @IsOptional()
    @IsString()
    fullName?: string;

    @ApiPropertyOptional()
    @IsOptional()
    @IsString()
    bio?: string;

    @ApiPropertyOptional()
    @IsOptional()
    @IsUrl({
        require_tld: false,
        protocols: ['http', 'https'],
    })
    profilePhotoUrl?: string;

    @ApiPropertyOptional()
    @IsOptional()
    @IsDateString()
    dateOfBirth?: string;

    @ApiPropertyOptional({ enum: ['male', 'female', 'other', 'prefer_not_to_say'] })
    @IsOptional()
    @IsEnum(['male', 'female', 'other', 'prefer_not_to_say'])
    gender?: string;

    @ApiPropertyOptional()
    @IsOptional()
    preferences?: UserPreferencesDto;

    @ApiPropertyOptional()
    @IsOptional()
    @IsBoolean()
    womenOnlyMode?: boolean;
}

export class DeviceTokenDto {
    @ApiProperty()
    @IsNotEmpty()
    @IsString()
    deviceToken: string;

    @ApiPropertyOptional()
    @IsOptional()
    @IsString()
    platform?: string;
}

export class UpsertPayoutAccountDto {
    @ApiProperty({ description: 'TR IBAN. Example: TRXXXXXXXXXXXXXXXXXXXXXX' })
    @IsNotEmpty()
    @IsString()
    @MinLength(26)
    @MaxLength(34)
    iban: string;

    @ApiProperty({ description: 'Account holder full name (must match verified identity)' })
    @IsNotEmpty()
    @IsString()
    accountHolderName: string;
}

export class VerifyPayoutAccountDto {
    @ApiProperty({ description: 'Micro verification code' })
    @IsNotEmpty()
    @IsString()
    @MinLength(4)
    @MaxLength(8)
    challengeCode: string;
}

export class PayoutAccountDto {
    @ApiPropertyOptional()
    ibanMasked?: string;

    @ApiPropertyOptional()
    accountHolderName?: string;

    @ApiProperty()
    verificationStatus: string;

    @ApiPropertyOptional()
    verifiedAt?: Date;

    @ApiPropertyOptional()
    blockedUntil?: Date;

    @ApiProperty()
    riskLevel: string;
}

export class UserProfileDto {
    @ApiProperty()
    id: string;

    @ApiProperty()
    phone: string;

    @ApiProperty()
    email: string;

    @ApiProperty()
    fullName: string;

    @ApiPropertyOptional()
    dateOfBirth?: Date;

    @ApiPropertyOptional()
    gender?: string;

    @ApiPropertyOptional()
    profilePhotoUrl?: string;

    @ApiPropertyOptional()
    bio?: string;

    @ApiProperty()
    ratingAvg: number;

    @ApiProperty()
    ratingCount: number;

    @ApiProperty()
    totalTrips: number;

    @ApiProperty()
    verificationStatus: {
        phone: boolean;
        email: boolean;
        identity: boolean;
        selfie: boolean;
        vehicle: boolean;
    };

    @ApiPropertyOptional()
    preferences?: UserPreferencesDto;

    @ApiProperty()
    womenOnlyMode: boolean;

    @ApiProperty()
    walletBalance: number;

    @ApiProperty()
    referralCode: string;

    @ApiPropertyOptional({ type: PayoutAccountDto })
    payoutAccount?: PayoutAccountDto;

    @ApiProperty()
    createdAt: Date;
}
