import request from 'supertest';
import { INestApplication } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';
import { cleanupDatabase, createTestApp, uniqueEmail, uniquePhone } from './utils';

describe('Auth E2E', () => {
    let app: INestApplication;
    let prisma: PrismaClient;
    let lastOtp: { value: string | null };

    beforeAll(async () => {
        const ctx = await createTestApp();
        app = ctx.app;
        prisma = ctx.prisma;
        lastOtp = ctx.lastOtp;
    });

    beforeEach(async () => {
        await cleanupDatabase(prisma);
    });

    afterAll(async () => {
        await app.close();
        await prisma.$disconnect();
    });

    it('registers, logs in, refreshes token', async () => {
        const phone = uniquePhone();
        const email = uniqueEmail();

        const registerRes = await request(app.getHttpServer())
            .post('/auth/register')
            .send({
                fullName: 'Test User',
                phone,
                email,
                password: 'SecurePass123!',
            })
            .expect(201);

        expect(registerRes.body).toHaveProperty('accessToken');
        expect(registerRes.body).toHaveProperty('refreshToken');

        const loginRes = await request(app.getHttpServer())
            .post('/auth/login')
            .send({ identifier: email, password: 'SecurePass123!' })
            .expect(200);

        expect(loginRes.body).toHaveProperty('accessToken');
        expect(loginRes.body).toHaveProperty('refreshToken');

        const refreshRes = await request(app.getHttpServer())
            .post('/auth/refresh')
            .send({ refreshToken: loginRes.body.refreshToken })
            .expect(200);

        expect(refreshRes.body).toHaveProperty('accessToken');
        expect(refreshRes.body).toHaveProperty('refreshToken');
    });

    it('sends and verifies OTP', async () => {
        const phone = uniquePhone();
        const email = uniqueEmail();

        await request(app.getHttpServer())
            .post('/auth/register')
            .send({
                fullName: 'OTP User',
                phone,
                email,
                password: 'SecurePass123!',
            })
            .expect(201);

        await request(app.getHttpServer())
            .post('/auth/send-otp')
            .send({ phone })
            .expect(200);

        expect(lastOtp.value).toBeTruthy();

        const verifyRes = await request(app.getHttpServer())
            .post('/auth/verify-otp')
            .send({ phone, code: lastOtp.value })
            .expect(200);

        expect(verifyRes.body).toHaveProperty('accessToken');
        expect(verifyRes.body).toHaveProperty('refreshToken');
    });
});
