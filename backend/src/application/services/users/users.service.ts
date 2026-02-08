import { Injectable, NotFoundException, BadRequestException, ForbiddenException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import { createHash } from 'crypto';
import { PrismaService } from '@infrastructure/database/prisma.service';
import { IyzicoService } from '@infrastructure/payment/iyzico.service';
import {
    UpdateProfileDto,
    UserProfileDto,
    DeviceTokenDto,
    PayoutAccountDto,
    UpsertPayoutAccountDto,
    VerifyPayoutAccountDto,
} from '@application/dto/users/users.dto';

type PayoutVerificationMeta = {
    challengeHash?: string;
    expiresAt?: string;
    attempts?: number;
};

@Injectable()
export class UsersService {
    private readonly payoutFreezeHours: number;
    private readonly payoutChallengeTtlMinutes: number;
    private readonly payoutMaxAttempts: number;
    private readonly payoutVerificationSalt: string;

    constructor(
        private readonly prisma: PrismaService,
        private readonly iyzicoService: IyzicoService,
        private readonly configService: ConfigService,
    ) {
        this.payoutFreezeHours = Number(this.configService.get('PAYOUT_CHANGE_FREEZE_HOURS') || 24);
        this.payoutChallengeTtlMinutes = Number(this.configService.get('PAYOUT_CHALLENGE_TTL_MINUTES') || 30);
        this.payoutMaxAttempts = Number(this.configService.get('PAYOUT_CHALLENGE_MAX_ATTEMPTS') || 5);
        this.payoutVerificationSalt = this.configService.get('PAYOUT_VERIFICATION_SALT') || 'payout-verification-salt';
    }

    async findById(id: string, includePayout = false): Promise<UserProfileDto> {
        const user = await this.prisma.user.findUnique({
            where: { id },
        });

        if (!user) {
            throw new NotFoundException('Kullanici bulunamadi');
        }

        return this.mapToDto(user, includePayout);
    }

    async updateProfile(id: string, dto: UpdateProfileDto): Promise<UserProfileDto> {
        const user = await this.prisma.user.findUnique({
            where: { id },
        });

        if (!user) {
            throw new NotFoundException('Kullanici bulunamadi');
        }

        const updated = await this.prisma.user.update({
            where: { id },
            data: {
                ...(dto.fullName && { fullName: dto.fullName }),
                ...(dto.bio !== undefined && { bio: dto.bio }),
                ...(dto.profilePhotoUrl !== undefined && { profilePhotoUrl: dto.profilePhotoUrl }),
                ...(dto.dateOfBirth && { dateOfBirth: new Date(dto.dateOfBirth) }),
                ...(dto.gender && { gender: dto.gender as any }),
                ...(dto.womenOnlyMode !== undefined && { womenOnlyMode: dto.womenOnlyMode }),
                ...(dto.preferences && {
                    preferences: { ...this.parsePreferences(user.preferences), ...dto.preferences }
                }),
            },
        });

        return this.mapToDto(updated, true);
    }

    async registerDeviceToken(id: string, dto: DeviceTokenDto): Promise<UserProfileDto> {
        const user = await this.prisma.user.findUnique({
            where: { id },
        });

        if (!user) {
            throw new NotFoundException('Kullanici bulunamadi');
        }

        const preferences = this.parsePreferences(user.preferences);
        const existing = Array.isArray(preferences.deviceTokens) ? preferences.deviceTokens : [];
        const tokens = existing.includes(dto.deviceToken)
            ? existing
            : [...existing, dto.deviceToken];

        const updated = await this.prisma.user.update({
            where: { id },
            data: {
                preferences: {
                    ...preferences,
                    deviceTokens: tokens,
                    ...(dto.platform ? { devicePlatform: dto.platform } : {}),
                },
            },
        });

        return this.mapToDto(updated, true);
    }

    async getPayoutAccount(id: string): Promise<PayoutAccountDto> {
        const user = await this.prisma.user.findUnique({
            where: { id },
            select: {
                payoutIbanMasked: true,
                payoutAccountHolderName: true,
                payoutVerificationStatus: true,
                payoutVerifiedAt: true,
                payoutBlockedUntil: true,
                payoutRiskLevel: true,
            },
        });

        if (!user) {
            throw new NotFoundException('Kullanici bulunamadi');
        }

        return {
            ibanMasked: user.payoutIbanMasked || undefined,
            accountHolderName: user.payoutAccountHolderName || undefined,
            verificationStatus: user.payoutVerificationStatus,
            verifiedAt: user.payoutVerifiedAt || undefined,
            blockedUntil: user.payoutBlockedUntil || undefined,
            riskLevel: user.payoutRiskLevel,
        };
    }

    async upsertPayoutAccount(id: string, dto: UpsertPayoutAccountDto): Promise<UserProfileDto> {
        const user = await this.prisma.user.findUnique({
            where: { id },
        });

        if (!user) {
            throw new NotFoundException('Kullanici bulunamadi');
        }

        if (user.identityStatus !== 'verified') {
            throw new BadRequestException('Kimlik dogrulamasi tamamlanmadan payout hesabi eklenemez');
        }

        if (user.payoutBlockedUntil && user.payoutBlockedUntil.getTime() > Date.now()) {
            throw new ForbiddenException('Payout hesabi guvenlik nedeniyle gecici olarak kilitli');
        }

        const normalizedIban = this.normalizeIban(dto.iban);
        if (!this.isValidTurkishIban(normalizedIban)) {
            throw new BadRequestException('Gecersiz TR IBAN');
        }

        const holderFromInput = this.normalizePersonName(dto.accountHolderName);
        const holderFromIdentity = this.normalizePersonName(user.fullName);
        if (holderFromInput !== holderFromIdentity) {
            throw new BadRequestException('IBAN hesap sahibi adi kimlik adi ile eslesmiyor');
        }

        const registerResult = await this.iyzicoService.registerPayoutAccount(
            user.id,
            normalizedIban,
            dto.accountHolderName,
        );

        if (!registerResult.success || !registerResult.providerAccountId) {
            throw new BadRequestException(registerResult.errorMessage || 'Payout hesabi olusturulamadi');
        }

        const now = new Date();
        const oldHash = user.payoutIbanHash;
        const newHash = this.hashValue(normalizedIban);
        const isChangingExistingIban = Boolean(oldHash && oldHash !== newHash);
        const blockedUntil = isChangingExistingIban
            ? new Date(now.getTime() + this.payoutFreezeHours * 60 * 60 * 1000)
            : null;

        const challengeCode = registerResult.verificationCode || this.generateChallengeCode();
        const preferences = this.parsePreferences(user.preferences);
        const payoutVerification: PayoutVerificationMeta = {
            challengeHash: this.hashValue(challengeCode),
            expiresAt: new Date(now.getTime() + this.payoutChallengeTtlMinutes * 60 * 1000).toISOString(),
            attempts: 0,
        };

        const updated = await this.prisma.user.update({
            where: { id },
            data: {
                payoutIbanMasked: this.maskIban(normalizedIban),
                payoutIbanHash: newHash,
                payoutAccountHolderName: dto.accountHolderName.trim(),
                payoutProviderAccountId: registerResult.providerAccountId,
                payoutVerificationStatus: 'pending',
                payoutVerifiedAt: null,
                payoutBlockedUntil: blockedUntil,
                payoutRiskLevel: isChangingExistingIban ? 'medium' : 'low',
                payoutUpdatedAt: now,
                preferences: {
                    ...preferences,
                    payoutVerification,
                },
            },
        });

        return this.mapToDto(updated, true);
    }

    async verifyPayoutAccount(id: string, dto: VerifyPayoutAccountDto): Promise<UserProfileDto> {
        const user = await this.prisma.user.findUnique({
            where: { id },
        });

        if (!user) {
            throw new NotFoundException('Kullanici bulunamadi');
        }

        if (user.payoutVerificationStatus !== 'pending') {
            throw new BadRequestException('Dogrulanacak aktif payout hesabi yok');
        }

        if (user.payoutBlockedUntil && user.payoutBlockedUntil.getTime() > Date.now()) {
            throw new ForbiddenException('Payout hesabi guvenlik nedeniyle gecici olarak kilitli');
        }

        const preferences = this.parsePreferences(user.preferences);
        const payoutVerification = (preferences.payoutVerification || {}) as PayoutVerificationMeta;
        if (!payoutVerification.challengeHash || !payoutVerification.expiresAt) {
            throw new BadRequestException('Dogrulama kodu bulunamadi, hesabi tekrar kaydedin');
        }

        const now = new Date();
        const expiresAt = new Date(payoutVerification.expiresAt);
        if (Number.isNaN(expiresAt.getTime()) || expiresAt.getTime() < now.getTime()) {
            throw new BadRequestException('Dogrulama kodunun suresi doldu');
        }

        const attempts = Number(payoutVerification.attempts || 0);
        const isMatch = this.hashValue(dto.challengeCode.trim()) === payoutVerification.challengeHash;

        if (!isMatch) {
            const nextAttempts = attempts + 1;
            const nextPreferences = {
                ...preferences,
                payoutVerification: {
                    ...payoutVerification,
                    attempts: nextAttempts,
                },
            };
            await this.prisma.user.update({
                where: { id },
                data: {
                    preferences: nextPreferences,
                    ...(nextAttempts >= this.payoutMaxAttempts
                        ? {
                            payoutVerificationStatus: 'rejected',
                            payoutRiskLevel: 'high',
                            payoutBlockedUntil: new Date(now.getTime() + this.payoutFreezeHours * 60 * 60 * 1000),
                        }
                        : {}),
                },
            });
            throw new BadRequestException('Dogrulama kodu gecersiz');
        }

        const nextPreferences = { ...preferences };
        delete nextPreferences.payoutVerification;

        const updated = await this.prisma.user.update({
            where: { id },
            data: {
                preferences: nextPreferences,
                payoutVerificationStatus: 'verified',
                payoutVerifiedAt: now,
                payoutBlockedUntil: null,
                payoutRiskLevel: 'low',
            },
        });

        return this.mapToDto(updated, true);
    }

    async getStats(id: string) {
        const user = await this.prisma.user.findUnique({
            where: { id },
            select: {
                totalTrips: true,
                ratingAvg: true,
                ratingCount: true,
                walletBalance: true,
                _count: {
                    select: {
                        bookings: true,
                        tripsAsDriver: true,
                        reviewsGiven: true,
                    },
                },
            },
        });

        if (!user) {
            throw new NotFoundException('Kullanici bulunamadi');
        }

        return {
            totalTrips: user.totalTrips,
            ratingAvg: user.ratingAvg,
            ratingCount: user.ratingCount,
            walletBalance: user.walletBalance,
            tripsAsDriver: user._count.tripsAsDriver,
            tripsAsPassenger: user._count.bookings,
            reviewsGiven: user._count.reviewsGiven,
        };
    }

    private mapToDto(user: any, includePayout = false): UserProfileDto {
        return {
            id: user.id,
            phone: user.phone,
            email: user.email,
            fullName: user.fullName,
            dateOfBirth: user.dateOfBirth,
            gender: user.gender,
            profilePhotoUrl: user.profilePhotoUrl,
            bio: user.bio,
            ratingAvg: Number(user.ratingAvg),
            ratingCount: user.ratingCount,
            totalTrips: user.totalTrips,
            verificationStatus: this.buildVerificationStatus(user),
            preferences: this.parsePreferences(user.preferences),
            womenOnlyMode: user.womenOnlyMode,
            walletBalance: Number(user.walletBalance),
            referralCode: user.referralCode,
            payoutAccount: includePayout
                ? {
                    ibanMasked: user.payoutIbanMasked || undefined,
                    accountHolderName: user.payoutAccountHolderName || undefined,
                    verificationStatus: user.payoutVerificationStatus || 'none',
                    verifiedAt: user.payoutVerifiedAt || undefined,
                    blockedUntil: user.payoutBlockedUntil || undefined,
                    riskLevel: user.payoutRiskLevel || 'low',
                }
                : undefined,
            createdAt: user.createdAt,
        };
    }

    private parsePreferences(preferences: any) {
        if (!preferences) return {};
        if (typeof preferences === 'string') {
            try {
                return JSON.parse(preferences);
            } catch {
                return {};
            }
        }
        return preferences;
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

    private normalizeIban(value: string): string {
        return (value || '').toUpperCase().replace(/\s+/g, '');
    }

    private isValidTurkishIban(iban: string): boolean {
        if (!/^TR[0-9A-Z]{24}$/.test(iban)) {
            return false;
        }

        const rearranged = `${iban.slice(4)}${iban.slice(0, 4)}`;
        let numeric = '';
        for (const ch of rearranged) {
            if (/[A-Z]/.test(ch)) {
                numeric += `${ch.charCodeAt(0) - 55}`;
            } else {
                numeric += ch;
            }
        }

        let remainder = 0;
        for (const digit of numeric) {
            remainder = (remainder * 10 + Number(digit)) % 97;
        }
        return remainder === 1;
    }

    private normalizePersonName(value: string): string {
        const map: Record<string, string> = {
            'ç': 'c', 'Ç': 'c',
            'ğ': 'g', 'Ğ': 'g',
            'ı': 'i', 'İ': 'i',
            'ö': 'o', 'Ö': 'o',
            'ş': 's', 'Ş': 's',
            'ü': 'u', 'Ü': 'u',
        };
        const normalized = (value || '')
            .split('')
            .map((ch) => map[ch] || ch)
            .join('')
            .toLowerCase()
            .replace(/[^a-z\s]/g, ' ')
            .replace(/\s+/g, ' ')
            .trim();
        return normalized;
    }

    private maskIban(iban: string): string {
        if (iban.length < 10) return 'TR****';
        return `${iban.slice(0, 4)}**************${iban.slice(-4)}`;
    }

    private hashValue(value: string): string {
        return createHash('sha256')
            .update(`${this.payoutVerificationSalt}:${value}`)
            .digest('hex');
    }

    private generateChallengeCode(): string {
        return `${Math.floor(Math.random() * 9000) + 1000}`;
    }
}
