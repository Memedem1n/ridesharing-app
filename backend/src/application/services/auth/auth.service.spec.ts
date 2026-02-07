import { Test, TestingModule } from '@nestjs/testing';
import { AuthService } from '@application/services/auth/auth.service';
import { PrismaService } from '@infrastructure/database/prisma.service';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { RedisService } from '@infrastructure/cache/redis.service';
import { NetgsmService } from '@infrastructure/notifications/netgsm.service';
import { BadRequestException, ConflictException, UnauthorizedException } from '@nestjs/common';
import * as bcrypt from 'bcrypt';

describe('AuthService', () => {
    let service: AuthService;
    let prismaService: jest.Mocked<PrismaService>;
    let redisService: jest.Mocked<RedisService>;
    let netgsmService: jest.Mocked<NetgsmService>;

    const mockPrismaService = {
        user: {
            findFirst: jest.fn(),
            findUnique: jest.fn(),
            create: jest.fn(),
            update: jest.fn(),
        },
    };

    const mockJwtService = {
        signAsync: jest.fn().mockResolvedValue('mock-token'),
        verifyAsync: jest.fn(),
    };

    const mockConfigService = {
        get: jest.fn((key: string) => {
            const config: Record<string, string> = {
                JWT_SECRET: 'test-secret',
                JWT_ACCESS_EXPIRY: '15m',
                JWT_REFRESH_EXPIRY: '7d',
                OTP_TTL_SECONDS: '300',
            };
            return config[key];
        }),
    };

    const mockRedisService = {
        isConfigured: jest.fn().mockReturnValue(true),
        get: jest.fn(),
        set: jest.fn(),
        del: jest.fn(),
    };

    const mockNetgsmService = {
        sendOtp: jest.fn().mockResolvedValue({ success: true, messageId: 'SMS_1' }),
    };

    beforeEach(async () => {
        const module: TestingModule = await Test.createTestingModule({
            providers: [
                AuthService,
                { provide: PrismaService, useValue: mockPrismaService },
                { provide: JwtService, useValue: mockJwtService },
                { provide: ConfigService, useValue: mockConfigService },
                { provide: RedisService, useValue: mockRedisService },
                { provide: NetgsmService, useValue: mockNetgsmService },
            ],
        }).compile();

        service = module.get<AuthService>(AuthService);
        prismaService = module.get(PrismaService);
        redisService = module.get(RedisService);
        netgsmService = module.get(NetgsmService);

        jest.clearAllMocks();
    });

    describe('register', () => {
        const registerDto = {
            phone: '+905551234567',
            email: 'test@example.com',
            password: 'SecurePass123!',
            fullName: 'Test User',
        };

        it('should register a new user successfully', async () => {
            mockPrismaService.user.findFirst.mockResolvedValue(null);
            mockPrismaService.user.create.mockResolvedValue({
                id: 'user-1',
                ...registerDto,
                passwordHash: 'hashed',
                referralCode: 'ABC12345',
                ratingAvg: 0,
                totalTrips: 0,
                verified: false,
                identityStatus: 'pending',
                licenseStatus: 'pending',
            });

            const result = await service.register(registerDto);

            expect(result).toHaveProperty('user');
            expect(result).toHaveProperty('accessToken');
            expect(result).toHaveProperty('refreshToken');
            expect(mockPrismaService.user.create).toHaveBeenCalled();
            expect(netgsmService.sendOtp).toHaveBeenCalled();
        });

        it('should still register if OTP send fails', async () => {
            mockPrismaService.user.findFirst.mockResolvedValue(null);
            mockPrismaService.user.create.mockResolvedValue({
                id: 'user-1',
                ...registerDto,
                passwordHash: 'hashed',
                referralCode: 'ABC12345',
                ratingAvg: 0,
                totalTrips: 0,
                verified: false,
                identityStatus: 'pending',
                licenseStatus: 'pending',
            });
            mockNetgsmService.sendOtp.mockRejectedValueOnce(new Error('sms failed'));

            const result = await service.register(registerDto);

            expect(result).toHaveProperty('user');
        });

        it('should throw ConflictException if email already exists', async () => {
            mockPrismaService.user.findFirst.mockResolvedValue({ id: 'existing-user' });

            await expect(service.register(registerDto)).rejects.toThrow(ConflictException);
        });
    });

    describe('login', () => {
        const loginDto = {
            identifier: 'test@example.com',
            password: 'SecurePass123!',
        };

        it('should login successfully with correct credentials', async () => {
            const hashedPassword = await bcrypt.hash('SecurePass123!', 12);
            mockPrismaService.user.findFirst.mockResolvedValue({
                id: 'user-1',
                email: 'test@example.com',
                passwordHash: hashedPassword,
                fullName: 'Test User',
                ratingAvg: 0,
                totalTrips: 0,
                bannedUntil: null,
                verified: false,
                identityStatus: 'pending',
                licenseStatus: 'pending',
            });

            const result = await service.login(loginDto);

            expect(result).toHaveProperty('user');
            expect(result).toHaveProperty('accessToken');
        });

        it('should throw UnauthorizedException for wrong password', async () => {
            mockPrismaService.user.findFirst.mockResolvedValue({
                id: 'user-1',
                passwordHash: await bcrypt.hash('different-password', 12),
                bannedUntil: null,
            });

            await expect(service.login(loginDto)).rejects.toThrow(UnauthorizedException);
        });

        it('should throw UnauthorizedException for non-existent user', async () => {
            mockPrismaService.user.findFirst.mockResolvedValue(null);

            await expect(service.login(loginDto)).rejects.toThrow(UnauthorizedException);
        });

        it('should throw UnauthorizedException for banned user', async () => {
            mockPrismaService.user.findFirst.mockResolvedValue({
                id: 'user-1',
                passwordHash: await bcrypt.hash('SecurePass123!', 12),
                bannedUntil: new Date(Date.now() + 86400000),
            });

            await expect(service.login(loginDto)).rejects.toThrow(UnauthorizedException);
        });
    });

    describe('sendOtp', () => {
        it('should send OTP when user exists (redis)', async () => {
            mockPrismaService.user.findUnique.mockResolvedValue({ id: 'user-1' });
            mockRedisService.isConfigured.mockReturnValue(true);

            await service.sendOtp({ phone: '+905551234567' });

            expect(redisService.set).toHaveBeenCalled();
            expect(netgsmService.sendOtp).toHaveBeenCalledWith('+905551234567', expect.any(String));
        });

        it('should send OTP when user exists (fallback)', async () => {
            mockPrismaService.user.findUnique.mockResolvedValue({ id: 'user-1' });
            mockRedisService.isConfigured.mockReturnValue(false);

            await service.sendOtp({ phone: '+905551234567' });

            expect(netgsmService.sendOtp).toHaveBeenCalledWith('+905551234567', expect.any(String));
        });

        it('should throw if user not found', async () => {
            mockPrismaService.user.findUnique.mockResolvedValue(null);

            await expect(service.sendOtp({ phone: '+905551234567' })).rejects.toThrow(BadRequestException);
        });
    });

    describe('verifyOtp', () => {
        it('should verify OTP successfully (redis)', async () => {
            mockRedisService.isConfigured.mockReturnValue(true);
            mockRedisService.get.mockResolvedValue('123456');
            mockPrismaService.user.findFirst.mockResolvedValue({
                id: 'user-1',
                email: 'test@example.com',
                phone: '+905551234567',
                verified: false,
                identityStatus: 'pending',
                licenseStatus: 'pending',
            });
            mockPrismaService.user.update.mockResolvedValue({
                id: 'user-1',
                email: 'test@example.com',
                phone: '+905551234567',
                verified: true,
                identityStatus: 'pending',
                licenseStatus: 'pending',
            });

            const result = await service.verifyOtp({
                identifier: '+905551234567',
                code: '123456',
                type: 'phone',
            });

            expect(result).toHaveProperty('user');
            expect(result).toHaveProperty('accessToken');
            expect(redisService.del).toHaveBeenCalled();
        });

        it('should verify OTP successfully (fallback)', async () => {
            mockRedisService.isConfigured.mockReturnValue(false);
            mockPrismaService.user.findUnique.mockResolvedValue({ id: 'user-1' });
            mockPrismaService.user.findFirst.mockResolvedValue({
                id: 'user-1',
                email: 'test@example.com',
                phone: '+905551234567',
                verified: false,
                identityStatus: 'pending',
                licenseStatus: 'pending',
            });
            mockPrismaService.user.update.mockResolvedValue({
                id: 'user-1',
                email: 'test@example.com',
                phone: '+905551234567',
                verified: true,
                identityStatus: 'pending',
                licenseStatus: 'pending',
            });

            await service.sendOtp({ phone: '+905551234567' });

            const storedCode = (mockNetgsmService.sendOtp as jest.Mock).mock.calls[0][1];

            const result = await service.verifyOtp({
                phone: '+905551234567',
                code: storedCode,
            });

            expect(result).toHaveProperty('user');
        });

        it('should throw for missing identifier', async () => {
            await expect(service.verifyOtp({ code: '123456' } as any)).rejects.toThrow(BadRequestException);
        });

        it('should throw for invalid code', async () => {
            mockRedisService.isConfigured.mockReturnValue(true);
            mockRedisService.get.mockResolvedValue('654321');

            await expect(service.verifyOtp({
                identifier: '+905551234567',
                code: '123456',
                type: 'phone',
            })).rejects.toThrow(BadRequestException);
        });
    });
});
