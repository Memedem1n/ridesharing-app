import { Test, TestingModule } from '@nestjs/testing';
import { MessagesService } from '@application/services/messages/messages.service';
import { PrismaService } from '@infrastructure/database/prisma.service';
import { FcmService } from '@infrastructure/notifications/fcm.service';

describe('MessagesService', () => {
    let service: MessagesService;
    let prismaService: jest.Mocked<PrismaService>;
    let fcmService: jest.Mocked<FcmService>;

    const mockPrismaService = {
        booking: {
            findUnique: jest.fn(),
        },
        message: {
            create: jest.fn(),
            count: jest.fn(),
            findMany: jest.fn(),
            updateMany: jest.fn(),
        },
    };

    const mockFcmService = {
        notifyNewMessage: jest.fn().mockResolvedValue({ success: true, messageId: 'FCM_1' }),
    };

    beforeEach(async () => {
        const module: TestingModule = await Test.createTestingModule({
            providers: [
                MessagesService,
                { provide: PrismaService, useValue: mockPrismaService },
                { provide: FcmService, useValue: mockFcmService },
            ],
        }).compile();

        service = module.get<MessagesService>(MessagesService);
        prismaService = module.get(PrismaService);
        fcmService = module.get(FcmService);

        jest.clearAllMocks();
    });

    describe('sendMessage', () => {
        it('should notify receiver when device tokens exist', async () => {
            mockPrismaService.booking.findUnique.mockResolvedValue({
                id: 'booking-1',
                passengerId: 'user-passenger',
                passenger: { id: 'user-passenger', preferences: {} },
                trip: {
                    driverId: 'user-driver',
                    driver: { id: 'user-driver', preferences: { deviceTokens: ['token-1', 'token-2'] } },
                },
            });

            mockPrismaService.message.create.mockResolvedValue({
                id: 'msg-1',
                bookingId: 'booking-1',
                senderId: 'user-passenger',
                receiverId: 'user-driver',
                message: 'Hello',
                read: false,
                createdAt: new Date(),
                sender: { id: 'user-passenger', fullName: 'Test', profilePhotoUrl: null },
            });

            await service.sendMessage('user-passenger', { bookingId: 'booking-1', message: 'Hello' });

            expect(fcmService.notifyNewMessage).toHaveBeenCalledTimes(2);
        });

        it('should not notify when no tokens', async () => {
            mockPrismaService.booking.findUnique.mockResolvedValue({
                id: 'booking-1',
                passengerId: 'user-passenger',
                passenger: { id: 'user-passenger', preferences: {} },
                trip: {
                    driverId: 'user-driver',
                    driver: { id: 'user-driver', preferences: {} },
                },
            });

            mockPrismaService.message.create.mockResolvedValue({
                id: 'msg-1',
                bookingId: 'booking-1',
                senderId: 'user-passenger',
                receiverId: 'user-driver',
                message: 'Hello',
                read: false,
                createdAt: new Date(),
                sender: { id: 'user-passenger', fullName: 'Test', profilePhotoUrl: null },
            });

            await service.sendMessage('user-passenger', { bookingId: 'booking-1', message: 'Hello' });

            expect(fcmService.notifyNewMessage).not.toHaveBeenCalled();
        });
    });
});
