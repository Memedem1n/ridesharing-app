import request from 'supertest';
import { INestApplication } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';
import { cleanupDatabase, createTestApp, uniqueEmail, uniquePhone } from './utils';

describe('Verification E2E', () => {
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
        const registerRes = await request(app.getHttpServer())
            .post('/auth/register')
            .send({
                fullName: 'Verify User',
                phone: uniquePhone(),
                email: uniqueEmail(),
                password: 'SecurePass123!',
            })
            .expect(201);

        accessToken = registerRes.body.accessToken;
    });

    afterAll(async () => {
        await app.close();
        await prisma.$disconnect();
    });

    it('gets verification status', async () => {
        const res = await request(app.getHttpServer())
            .get('/verification/status')
            .set('Authorization', `Bearer ${accessToken}`)
            .expect(200);

        expect(res.body).toHaveProperty('identityStatus');
        expect(res.body).toHaveProperty('licenseStatus');
        expect(res.body).toHaveProperty('criminalRecordStatus');
    });
});
