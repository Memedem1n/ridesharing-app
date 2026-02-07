import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '@infrastructure/database/prisma.service';
import { UpdateProfileDto, UserProfileDto, DeviceTokenDto } from '@application/dto/users/users.dto';

@Injectable()
export class UsersService {
    constructor(private readonly prisma: PrismaService) { }

    async findById(id: string): Promise<UserProfileDto> {
        const user = await this.prisma.user.findUnique({
            where: { id },
        });

        if (!user) {
            throw new NotFoundException('Kullanıcı bulunamadı');
        }

        return this.mapToDto(user);
    }

    async updateProfile(id: string, dto: UpdateProfileDto): Promise<UserProfileDto> {
        const user = await this.prisma.user.findUnique({
            where: { id },
        });

        if (!user) {
            throw new NotFoundException('Kullanıcı bulunamadı');
        }

        const updated = await this.prisma.user.update({
            where: { id },
            data: {
                ...(dto.fullName && { fullName: dto.fullName }),
                ...(dto.bio !== undefined && { bio: dto.bio }),
                ...(dto.dateOfBirth && { dateOfBirth: new Date(dto.dateOfBirth) }),
                ...(dto.gender && { gender: dto.gender as any }),
                ...(dto.womenOnlyMode !== undefined && { womenOnlyMode: dto.womenOnlyMode }),
                ...(dto.preferences && {
                    preferences: { ...this.parsePreferences(user.preferences), ...dto.preferences }
                }),
            },
        });

        return this.mapToDto(updated);
    }

    async registerDeviceToken(id: string, dto: DeviceTokenDto): Promise<UserProfileDto> {
        const user = await this.prisma.user.findUnique({
            where: { id },
        });

        if (!user) {
            throw new NotFoundException('Kullanıcı bulunamadı');
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

        return this.mapToDto(updated);
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
            throw new NotFoundException('Kullanıcı bulunamadı');
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

    private mapToDto(user: any): UserProfileDto {
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
}
