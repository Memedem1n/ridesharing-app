import { Test, TestingModule } from '@nestjs/testing';
import { AuthService } from '@application/services/auth/auth.service';
import { PrismaService } from '@infrastructure/database/prisma.service';
import { JwtService } from '@nestjs/jwt';
import { ConfigService } from '@nestjs/config';
import { ConflictException, UnauthorizedException } from '@nestjs/common';
import * as bcrypt from 'bcrypt';

describe('AuthService', () => {
    let service: AuthService;
    let prismaService: jest.Mocked<PrismaService>;

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
            };
            return config[key];
        }),
    };

    beforeEach(async () => {
        const module: TestingModule = await Test.createTestingModule({
            providers: [
                AuthService,
                { provide: PrismaService, useValue: mockPrismaService },
                { provide: JwtService, useValue: mockJwtService },
                { provide: ConfigService, useValue: mockConfigService },
            ],
        }).compile();

        service = module.get<AuthService>(AuthService);
        prismaService = module.get(PrismaService);

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
                verificationStatus: { phone: false, email: false },
            });

            const result = await service.register(registerDto);

            expect(result).toHaveProperty('user');
            expect(result).toHaveProperty('accessToken');
            expect(result).toHaveProperty('refreshToken');
            expect(mockPrismaService.user.create).toHaveBeenCalled();
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
                verificationStatus: {},
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
                bannedUntil: new Date(Date.now() + 86400000), // tomorrow
            });

            await expect(service.login(loginDto)).rejects.toThrow(UnauthorizedException);
        });
    });

    describe('verifyOtp', () => {
        it('should verify OTP successfully', async () => {
            mockPrismaService.user.findFirst.mockResolvedValue({
                id: 'user-1',
                verificationStatus: { phone: false },
            });
            mockPrismaService.user.update.mockResolvedValue({});

            const result = await service.verifyOtp({
                identifier: '+905551234567',
                code: '123456',
                type: 'phone',
            });

            expect(result.verified).toBe(true);
        });
    });
});
