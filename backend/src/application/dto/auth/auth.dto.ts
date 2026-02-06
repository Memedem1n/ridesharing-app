import { IsEmail, IsNotEmpty, IsString, MinLength, Matches, IsOptional } from 'class-validator';
import { ApiProperty } from '@nestjs/swagger';

export class RegisterDto {
    @ApiProperty({ example: '+905551234567' })
    @IsNotEmpty()
    @IsString()
    @Matches(/^\+90[0-9]{10}$/, { message: 'Geçerli bir Türkiye telefon numarası girin' })
    phone: string;

    @ApiProperty({ example: 'user@example.com' })
    @IsNotEmpty()
    @IsEmail({}, { message: 'Geçerli bir e-posta adresi girin' })
    email: string;

    @ApiProperty({ example: 'SecurePass123!' })
    @IsNotEmpty()
    @IsString()
    @MinLength(8, { message: 'Şifre en az 8 karakter olmalı' })
    password: string;

    @ApiProperty({ example: 'Ali Yılmaz' })
    @IsNotEmpty()
    @IsString()
    fullName: string;
}

export class LoginDto {
    @ApiProperty({ example: 'user@example.com veya +905551234567' })
    @IsNotEmpty()
    @IsString()
    identifier: string;

    @ApiProperty({ example: 'SecurePass123!' })
    @IsNotEmpty()
    @IsString()
    password: string;
}

export class VerifyOtpDto {
    @ApiProperty({ example: '+905551234567' })
    @IsNotEmpty()
    @IsString()
    identifier: string;

    @ApiProperty({ example: '123456' })
    @IsNotEmpty()
    @IsString()
    @MinLength(6)
    code: string;

    @ApiProperty({ example: 'phone', enum: ['phone', 'email'] })
    @IsNotEmpty()
    @IsString()
    type: 'phone' | 'email';
}

export class RefreshTokenDto {
    @ApiProperty()
    @IsNotEmpty()
    @IsString()
    refreshToken: string;
}

// UserResponseDto must be defined before AuthResponseDto
export class UserResponseDto {
    @ApiProperty()
    id: string;

    @ApiProperty()
    phone: string;

    @ApiProperty()
    email: string;

    @ApiProperty()
    fullName: string;

    @ApiProperty()
    profilePhotoUrl?: string;

    @ApiProperty()
    ratingAvg: number;

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
}

export class AuthResponseDto {
    @ApiProperty()
    user: UserResponseDto;

    @ApiProperty()
    accessToken: string;

    @ApiProperty()
    refreshToken: string;
}
