import { INestApplication } from '@nestjs/common';
import { Test } from '@nestjs/testing';
import { PrismaClient } from '@prisma/client';
import { AppModule } from '../../src/app.module';
import { NetgsmService } from '@infrastructure/notifications/netgsm.service';
import { FcmService } from '@infrastructure/notifications/fcm.service';

export type TestContext = {
    app: INestApplication;
    prisma: PrismaClient;
    lastOtp: { value: string | null };
};

const withTimeout = async <T>(promise: Promise<T>, ms: number, message: string): Promise<T> => {
    let timeout: NodeJS.Timeout | null = null;
    const timeoutPromise = new Promise<never>((_, reject) => {
        timeout = setTimeout(() => reject(new Error(message)), ms);
    });
    try {
        return await Promise.race([promise, timeoutPromise]);
    } finally {
        if (timeout) clearTimeout(timeout);
    }
};

export const createTestApp = async (): Promise<TestContext> => {
    const lastOtp = { value: null as string | null };
    const netgsmMock = {
        sendOtp: jest.fn(async (_phone: string, code: string) => {
            lastOtp.value = code;
            return { success: true, messageId: `SMS_${Date.now()}` };
        }),
    };
    const fcmMock = {
        notifyNewMessage: jest.fn(async () => ({ success: true, messageId: `FCM_${Date.now()}` })),
        sendToDevice: jest.fn(async () => ({ success: true, messageId: `FCM_${Date.now()}` })),
        sendToTopic: jest.fn(async () => ({ success: true, messageId: `FCM_${Date.now()}` })),
    };

    const moduleFixture = await Test.createTestingModule({
        imports: [AppModule],
    })
        .overrideProvider(NetgsmService)
        .useValue(netgsmMock)
        .overrideProvider(FcmService)
        .useValue(fcmMock)
        .compile();

    const app = moduleFixture.createNestApplication();
    await app.init();

    const prisma = new PrismaClient();
    await withTimeout(
        prisma.$connect(),
        5000,
        'Prisma could not connect to the test database. Ensure postgres is running and DATABASE_URL points to ridesharing_test.',
    );

    return { app, prisma, lastOtp };
};

export const cleanupDatabase = async (prisma: PrismaClient) => {
    await prisma.message.deleteMany();
    await prisma.review.deleteMany();
    await prisma.booking.deleteMany();
    await prisma.trip.deleteMany();
    await prisma.vehicle.deleteMany();
    await prisma.user.deleteMany();
};

export const uniqueEmail = (prefix = 'user') => `${prefix}_${Date.now()}_${Math.floor(Math.random() * 1000)}@test.local`;
export const uniquePhone = () => `+90${Math.floor(1000000000 + Math.random() * 9000000000)}`;

