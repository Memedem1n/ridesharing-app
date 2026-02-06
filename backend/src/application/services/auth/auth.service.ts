import { Injectable, UnauthorizedException, ConflictException, BadRequestException } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcrypt';
import { v4 as uuid } from 'uuid';
import { PrismaService } from '@infrastructure/database/prisma.service';
import { RegisterDto, LoginDto, VerifyOtpDto, AuthResponseDto, UserResponseDto } from '@application/dto/auth/auth.dto';

@Injectable()
export class AuthService {
    constructor(
        private readonly prisma: PrismaService,
        private readonly jwtService: JwtService,
        private readonly configService: ConfigService,
    ) { }

    async register(dto: RegisterDto): Promise<AuthResponseDto> {
        // Check if user exists
        const existingUser = await this.prisma.user.findFirst({
            where: {
                OR: [{ email: dto.email }, { phone: dto.phone }],
            },
        });

        if (existingUser) {
            throw new ConflictException('Bu e-posta veya telefon numarası zaten kayıtlı');
        }

        // Hash password
        const passwordHash = await bcrypt.hash(dto.password, 12);

        // Generate referral code
        const referralCode = this.generateReferralCode();

        // Create user
        const user = await this.prisma.user.create({
            data: {
                id: uuid(),
                phone: dto.phone,
                email: dto.email,
                passwordHash,
                fullName: dto.fullName,
                referralCode,
                identityStatus: 'pending',
                licenseStatus: 'pending',
                verified: false,
                preferences: {},
            },
        });

        // Generate tokens
        const tokens = await this.generateTokens(user.id, user.email);

        // TODO: Send OTP to phone

        return {
            user: this.mapUserResponse(user),
            ...tokens,
        };
    }

    async login(dto: LoginDto): Promise<AuthResponseDto> {
        // Find user by email or phone
        const user = await this.prisma.user.findFirst({
            where: {
                OR: [{ email: dto.identifier }, { phone: dto.identifier }],
            },
        });

        if (!user) {
            throw new UnauthorizedException('Geçersiz kullanıcı adı veya şifre');
        }

        // Check if banned
        if (user.bannedUntil && new Date() < user.bannedUntil) {
            throw new UnauthorizedException('Hesabınız askıya alınmış');
        }

        // Verify password
        const isPasswordValid = await bcrypt.compare(dto.password, user.passwordHash);
        if (!isPasswordValid) {
            throw new UnauthorizedException('Geçersiz kullanıcı adı veya şifre');
        }

        // Generate tokens
        const tokens = await this.generateTokens(user.id, user.email);

        return {
            user: this.mapUserResponse(user),
            ...tokens,
        };
    }

    async verifyOtp(dto: VerifyOtpDto): Promise<{ verified: boolean }> {
        // TODO: Implement OTP verification with Redis
        // For now, accept any 6-digit code for development
        if (dto.code.length !== 6) {
            throw new BadRequestException('Geçersiz doğrulama kodu');
        }

        // Update verification status
        const user = await this.prisma.user.findFirst({
            where: {
                OR: [{ email: dto.identifier }, { phone: dto.identifier }],
            },
        });

        if (!user) {
            throw new BadRequestException('Kullanıcı bulunamadı');
        }

        // Mark contact verification (single flag for now)
        await this.prisma.user.update({
            where: { id: user.id },
            data: { verified: true },
        });

        // OTP verified - identity/license verification happens through VerificationController
        return { verified: true };
    }

    async refreshTokens(refreshToken: string): Promise<{ accessToken: string; refreshToken: string }> {
        try {
            const payload = await this.jwtService.verifyAsync(refreshToken, {
                secret: this.configService.get('JWT_SECRET'),
            });

            return this.generateTokens(payload.sub, payload.email);
        } catch {
            throw new UnauthorizedException('Geçersiz refresh token');
        }
    }

    async validateUser(userId: string): Promise<UserResponseDto> {
        const user = await this.prisma.user.findUnique({
            where: { id: userId },
        });

        if (!user) {
            throw new UnauthorizedException('Kullanıcı bulunamadı');
        }

        return this.mapUserResponse(user);
    }

    private async generateTokens(userId: string, email: string) {
        const [accessToken, refreshToken] = await Promise.all([
            this.jwtService.signAsync(
                { sub: userId, email },
                {
                    secret: this.configService.get('JWT_SECRET'),
                    expiresIn: this.configService.get('JWT_ACCESS_EXPIRY') || '15m',
                },
            ),
            this.jwtService.signAsync(
                { sub: userId, email },
                {
                    secret: this.configService.get('JWT_SECRET'),
                    expiresIn: this.configService.get('JWT_REFRESH_EXPIRY') || '7d',
                },
            ),
        ]);

        return { accessToken, refreshToken };
    }

    private generateReferralCode(): string {
        const chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
        let code = '';
        for (let i = 0; i < 8; i++) {
            code += chars.charAt(Math.floor(Math.random() * chars.length));
        }
        return code;
    }

    private mapUserResponse(user: any): UserResponseDto {
        return {
            id: user.id,
            phone: user.phone,
            email: user.email,
            fullName: user.fullName,
            profilePhotoUrl: user.profilePhotoUrl,
            ratingAvg: user.ratingAvg,
            totalTrips: user.totalTrips,
            verificationStatus: this.buildVerificationStatus(user),
        };
    }

    private buildVerificationStatus(user: any) {
        return {
            phone: Boolean(user.verified),
            email: Boolean(user.verified),
            identity: user.identityStatus === 'verified',
            selfie: false,
            vehicle: user.licenseStatus === 'verified',
        };
    }
}
