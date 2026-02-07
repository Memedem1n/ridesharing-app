import { Test, TestingModule } from '@nestjs/testing';
import { UsersService } from '@application/services/users/users.service';
import { PrismaService } from '@infrastructure/database/prisma.service';
import { NotFoundException } from '@nestjs/common';

describe('UsersService', () => {
    let service: UsersService;
    let prismaService: jest.Mocked<PrismaService>;

    const mockPrismaService = {
        user: {
            findUnique: jest.fn(),
            update: jest.fn(),
        },
    };

    beforeEach(async () => {
        const module: TestingModule = await Test.createTestingModule({
            providers: [
                UsersService,
                { provide: PrismaService, useValue: mockPrismaService },
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
});
