import request from 'supertest';
import { INestApplication } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';
import { cleanupDatabase, createTestApp, uniqueEmail, uniquePhone } from './utils';

describe('Messages E2E', () => {
    let app: INestApplication;
    let prisma: PrismaClient;

    beforeAll(async () => {
        const ctx = await createTestApp();
        app = ctx.app;
        prisma = ctx.prisma;
    });

    beforeEach(async () => {
        await cleanupDatabase(prisma);
    });

    afterAll(async () => {
        await app.close();
        await prisma.$disconnect();
    });

    it('sends message and lists conversation', async () => {
        const driverPhone = uniquePhone();
        const driverEmail = uniqueEmail('driver');
        const passengerPhone = uniquePhone();
        const passengerEmail = uniqueEmail('passenger');

        const driverReg = await request(app.getHttpServer())
            .post('/auth/register')
            .send({
                fullName: 'Driver User',
                phone: driverPhone,
                email: driverEmail,
                password: 'SecurePass123!',
            })
            .expect(201);

        const passengerReg = await request(app.getHttpServer())
            .post('/auth/register')
            .send({
                fullName: 'Passenger User',
                phone: passengerPhone,
                email: passengerEmail,
                password: 'SecurePass123!',
            })
            .expect(201);

        const driverToken = driverReg.body.accessToken;
        const passengerToken = passengerReg.body.accessToken;

        const vehicleRes = await request(app.getHttpServer())
            .post('/vehicles')
            .set('Authorization', `Bearer ${driverToken}`)
            .send({
                brand: 'Toyota',
                model: 'Corolla',
                year: 2020,
                color: 'White',
                seats: 4,
                licensePlate: `34MSG${Math.floor(Math.random() * 1000)}`,
                hasAc: true,
                allowsPets: false,
                allowsSmoking: false,
            })
            .expect(201);

        const departureTime = new Date(Date.now() + 24 * 60 * 60 * 1000);
        const tripRes = await request(app.getHttpServer())
            .post('/trips')
            .set('Authorization', `Bearer ${driverToken}`)
            .send({
                vehicleId: vehicleRes.body.id,
                type: 'people',
                departureCity: 'Istanbul',
                arrivalCity: 'Ankara',
                departureTime: departureTime.toISOString(),
                availableSeats: 3,
                pricePerSeat: 150,
            })
            .expect(201);

        const bookingRes = await request(app.getHttpServer())
            .post('/bookings')
            .set('Authorization', `Bearer ${passengerToken}`)
            .send({
                tripId: tripRes.body.id,
                seats: 1,
                itemType: 'person',
            })
            .expect(201);

        await request(app.getHttpServer())
            .post('/bookings/payment')
            .set('Authorization', `Bearer ${passengerToken}`)
            .send({ bookingId: bookingRes.body.id, cardToken: 'TEST_TOKEN' })
            .expect(200);

        const sendRes = await request(app.getHttpServer())
            .post('/messages')
            .set('Authorization', `Bearer ${passengerToken}`)
            .send({ bookingId: bookingRes.body.id, message: 'Merhaba!' })
            .expect(201);

        expect(sendRes.body.message).toBe('Merhaba!');

        const convRes = await request(app.getHttpServer())
            .get('/messages/conversations')
            .set('Authorization', `Bearer ${driverToken}`)
            .expect(200);

        expect(convRes.body.conversations.length).toBeGreaterThan(0);

        const msgRes = await request(app.getHttpServer())
            .get(`/messages/conversation/${bookingRes.body.id}`)
            .set('Authorization', `Bearer ${driverToken}`)
            .expect(200);

        expect(msgRes.body.messages.length).toBeGreaterThan(0);
    });
});
