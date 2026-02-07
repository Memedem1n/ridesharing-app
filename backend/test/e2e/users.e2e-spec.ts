import request from 'supertest';
import { INestApplication } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';
import { cleanupDatabase, createTestApp, uniqueEmail, uniquePhone } from './utils';

describe('Users E2E', () => {
    let app: INestApplication;
    let prisma: PrismaClient;
    let accessToken: string;

    beforeAll(async () => {
        const ctx = await createTestApp();
        app = ctx.app;
        prisma = ctx.prisma;
    });

    beforeEach(async () => {
        await cleanupDatabase(prisma);
        const phone = uniquePhone();
        const email = uniqueEmail();

        const registerRes = await request(app.getHttpServer())
            .post('/auth/register')
            .send({
                fullName: 'Profile User',
                phone,
                email,
                password: 'SecurePass123!',
            })
            .expect(201);

        accessToken = registerRes.body.accessToken;
    });

    afterAll(async () => {
        await app.close();
        await prisma.$disconnect();
    });

    it('gets and updates profile', async () => {
        const meRes = await request(app.getHttpServer())
            .get('/users/me')
            .set('Authorization', `Bearer ${accessToken}`)
            .expect(200);

        expect(meRes.body).toHaveProperty('id');
        expect(meRes.body).toHaveProperty('email');

        const updateRes = await request(app.getHttpServer())
            .put('/users/me')
            .set('Authorization', `Bearer ${accessToken}`)
            .send({
                bio: 'Test bio',
                preferences: { music: 'rock' },
            })
            .expect(200);

        expect(updateRes.body.bio).toBe('Test bio');
        expect(updateRes.body.preferences?.music).toBe('rock');
    });

    it('registers device token', async () => {
        const res = await request(app.getHttpServer())
            .post('/users/me/device-token')
            .set('Authorization', `Bearer ${accessToken}`)
            .send({ deviceToken: 'device-token-1', platform: 'android' })
            .expect(200);

        expect(res.body.preferences?.deviceTokens).toContain('device-token-1');
    });
});
