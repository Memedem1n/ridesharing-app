import { Test, TestingModule } from '@nestjs/testing';
import { UsersService } from '@application/services/users/users.service';
import { PrismaService } from '@infrastructure/database/prisma.service';
import { NotFoundException } from '@nestjs/common';
import { IyzicoService } from '@infrastructure/payment/iyzico.service';
import { ConfigService } from '@nestjs/config';

describe('UsersService', () => {
    let service: UsersService;
    let prismaService: jest.Mocked<PrismaService>;

    const mockPrismaService = {
        user: {
            findUnique: jest.fn(),
            update: jest.fn(),
        },
    };

    const mockIyzicoService = {
        registerPayoutAccount: jest.fn(),
    };

    const mockConfigService = {
        get: jest.fn((key: string) => {
            if (key === 'PAYOUT_CHANGE_FREEZE_HOURS') return 24;
            if (key === 'PAYOUT_CHALLENGE_TTL_MINUTES') return 30;
            if (key === 'PAYOUT_CHALLENGE_MAX_ATTEMPTS') return 5;
            if (key === 'PAYOUT_VERIFICATION_SALT') return 'test-salt';
            return undefined;
        }),
    };

    beforeEach(async () => {
        const module: TestingModule = await Test.createTestingModule({
            providers: [
                UsersService,
                { provide: PrismaService, useValue: mockPrismaService },
                { provide: IyzicoService, useValue: mockIyzicoService },
                { provide: ConfigService, useValue: mockConfigService },
            ],
        }).compile();

        service = module.get<UsersService>(UsersService);
        prismaService = module.get(PrismaService);

        jest.clearAllMocks();
    });

    describe('registerDeviceToken', () => {
        it('should throw if user not found', async () => {
            mockPrismaService.user.findUnique.mockResolvedValue(null);

            await expect(
                service.registerDeviceToken('user-1', { deviceToken: 'token-1' }),
            ).rejects.toThrow(NotFoundException);
        });

        it('should add new token to preferences', async () => {
            mockPrismaService.user.findUnique.mockResolvedValue({
                id: 'user-1',
                preferences: {},
            });
            mockPrismaService.user.update.mockResolvedValue({
                id: 'user-1',
                preferences: { deviceTokens: ['token-1'] },
            });

            const result = await service.registerDeviceToken('user-1', { deviceToken: 'token-1' });

            expect(prismaService.user.update).toHaveBeenCalledWith(expect.objectContaining({
                data: expect.objectContaining({
                    preferences: expect.objectContaining({
                        deviceTokens: ['token-1'],
                    }),
                }),
            }));
            expect(result).toBeDefined();
        });

        it('should not duplicate token', async () => {
            mockPrismaService.user.findUnique.mockResolvedValue({
                id: 'user-1',
                preferences: { deviceTokens: ['token-1'] },
            });
            mockPrismaService.user.update.mockResolvedValue({
                id: 'user-1',
                preferences: { deviceTokens: ['token-1'] },
            });

            await service.registerDeviceToken('user-1', { deviceToken: 'token-1' });

            const call = (prismaService.user.update as jest.Mock).mock.calls[0][0];
            expect(call.data.preferences.deviceTokens).toEqual(['token-1']);
        });

        it('should store platform when provided', async () => {
            mockPrismaService.user.findUnique.mockResolvedValue({
                id: 'user-1',
                preferences: {},
            });
            mockPrismaService.user.update.mockResolvedValue({
                id: 'user-1',
                preferences: { deviceTokens: ['token-1'], devicePlatform: 'android' },
            });

            await service.registerDeviceToken('user-1', { deviceToken: 'token-1', platform: 'android' });

            const call = (prismaService.user.update as jest.Mock).mock.calls[0][0];
            expect(call.data.preferences.devicePlatform).toBe('android');
        });
    });

    describe('upsertPayoutAccount', () => {
        it('rejects when identity is not verified', async () => {
            mockPrismaService.user.findUnique.mockResolvedValue({
                id: 'user-1',
                fullName: 'Ali Veli',
                identityStatus: 'pending',
            });

            await expect(
                service.upsertPayoutAccount('user-1', {
                    iban: 'TR330006100519786457841326',
                    accountHolderName: 'Ali Veli',
                }),
            ).rejects.toThrow();
        });

        it('rejects when account holder does not match identity name', async () => {
            mockPrismaService.user.findUnique.mockResolvedValue({
                id: 'user-1',
                fullName: 'Ali Veli',
                identityStatus: 'verified',
            });

            await expect(
                service.upsertPayoutAccount('user-1', {
                    iban: 'TR330006100519786457841326',
                    accountHolderName: 'Mehmet Yilmaz',
                }),
            ).rejects.toThrow();
        });

        it('stores masked/hash payout account when verification starts', async () => {
            mockPrismaService.user.findUnique.mockResolvedValue({
                id: 'user-1',
                fullName: 'Ali Veli',
                identityStatus: 'verified',
                payoutIbanHash: null,
                payoutBlockedUntil: null,
                preferences: {},
            });
            mockIyzicoService.registerPayoutAccount.mockResolvedValue({
                success: true,
                providerAccountId: 'SUB_123',
                verificationCode: '1234',
            });
            mockPrismaService.user.update.mockResolvedValue({
                id: 'user-1',
                phone: '+905551111111',
                email: 'ali@example.com',
                fullName: 'Ali Veli',
                ratingAvg: 0,
                ratingCount: 0,
                totalTrips: 0,
                verified: true,
                identityStatus: 'verified',
                licenseStatus: 'verified',
                preferences: {},
                womenOnlyMode: false,
                walletBalance: 0,
                referralCode: 'ABC123',
                payoutIbanMasked: 'TR33**************1326',
                payoutAccountHolderName: 'Ali Veli',
                payoutVerificationStatus: 'pending',
                payoutVerifiedAt: null,
                payoutBlockedUntil: null,
                payoutRiskLevel: 'low',
                createdAt: new Date(),
            });

            await service.upsertPayoutAccount('user-1', {
                iban: 'TR330006100519786457841326',
                accountHolderName: 'Ali Veli',
            });

            expect(prismaService.user.update).toHaveBeenCalled();
            const call = (prismaService.user.update as jest.Mock).mock.calls[0][0];
            expect(call.data.payoutIbanMasked).toContain('TR33');
            expect(call.data.payoutIbanHash).toBeTruthy();
            expect(call.data.payoutVerificationStatus).toBe('pending');
        });
    });
});
