import { Injectable, UnauthorizedException, ConflictException, BadRequestException, Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import * as bcrypt from 'bcrypt';
import { v4 as uuid } from 'uuid';
import { PrismaService } from '@infrastructure/database/prisma.service';
import { RedisService } from '@infrastructure/cache/redis.service';
import { NetgsmService } from '@infrastructure/notifications/netgsm.service';
import { RegisterDto, LoginDto, VerifyOtpDto, AuthResponseDto, UserResponseDto, SendOtpDto } from '@application/dto/auth/auth.dto';

@Injectable()
export class AuthService {
    private readonly logger = new Logger(AuthService.name);
    private static otpFallback = new Map<string, { code: string; expiresAt: number }>();

    constructor(
        private readonly prisma: PrismaService,
        private readonly jwtService: JwtService,
        private readonly configService: ConfigService,
        private readonly redisService: RedisService,
        private readonly netgsmService: NetgsmService,
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

        // Send OTP to phone (best effort)
        try {
            await this.generateAndSendOtp('phone', dto.phone);
        } catch (error) {
            this.logger.warn(`OTP send failed for ${dto.phone}: ${error?.message || error}`);
        }

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

    async sendOtp(dto: SendOtpDto): Promise<{ sent: boolean }> {
        const user = await this.prisma.user.findUnique({
            where: { phone: dto.phone },
        });

        if (!user) {
            throw new BadRequestException('Kullanıcı bulunamadı');
        }

        await this.generateAndSendOtp('phone', dto.phone);
        return { sent: true };
    }

    async verifyOtp(dto: VerifyOtpDto): Promise<AuthResponseDto> {
        const identifier = dto.identifier || dto.phone;
        if (!identifier) {
            throw new BadRequestException('Doğrulama için telefon veya e-posta gerekli');
        }

        const type: 'phone' | 'email' = dto.type
            ? dto.type
            : identifier.includes('@') ? 'email' : 'phone';

        if (dto.code.length !== 6) {
            throw new BadRequestException('Geçersiz doğrulama kodu');
        }

        const key = this.buildOtpKey(type, identifier);
        const stored = await this.getOtpCode(key);
        if (!stored || stored !== dto.code) {
            throw new BadRequestException('Geçersiz veya süresi dolmuş doğrulama kodu');
        }

        await this.deleteOtpCode(key);

        const user = await this.prisma.user.findFirst({
            where: type === 'email' ? { email: identifier } : { phone: identifier },
        });

        if (!user) {
            throw new BadRequestException('Kullanıcı bulunamadı');
        }

        const updated = await this.prisma.user.update({
            where: { id: user.id },
            data: { verified: true },
        });

        const tokens = await this.generateTokens(updated.id, updated.email);

        return {
            user: this.mapUserResponse(updated),
            ...tokens,
        };
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

    private buildOtpKey(type: 'phone' | 'email', identifier: string): string {
        return `otp:${type}:${identifier}`;
    }

    private async generateAndSendOtp(type: 'phone' | 'email', identifier: string): Promise<void> {
        const code = this.generateOtpCode();
        const ttlSeconds = Number(this.configService.get('OTP_TTL_SECONDS')) || 300;
        const key = this.buildOtpKey(type, identifier);

        await this.storeOtpCode(key, code, ttlSeconds);

        if (type === 'phone') {
            await this.netgsmService.sendOtp(identifier, code);
        }
    }

    private generateOtpCode(): string {
        return Math.floor(100000 + Math.random() * 900000).toString();
    }

    private async storeOtpCode(key: string, code: string, ttlSeconds: number): Promise<void> {
        if (this.redisService.isConfigured()) {
            await this.redisService.set(key, code, ttlSeconds);
            return;
        }

        const expiresAt = Date.now() + ttlSeconds * 1000;
        AuthService.otpFallback.set(key, { code, expiresAt });
    }

    private async getOtpCode(key: string): Promise<string | null> {
        if (this.redisService.isConfigured()) {
            return await this.redisService.get(key);
        }

        const entry = AuthService.otpFallback.get(key);
        if (!entry) return null;
        if (Date.now() > entry.expiresAt) {
            AuthService.otpFallback.delete(key);
            return null;
        }
        return entry.code;
    }

    private async deleteOtpCode(key: string): Promise<void> {
        if (this.redisService.isConfigured()) {
            await this.redisService.del(key);
            return;
        }
        AuthService.otpFallback.delete(key);
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
