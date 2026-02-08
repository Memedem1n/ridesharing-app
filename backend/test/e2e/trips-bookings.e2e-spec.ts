import * as request from 'supertest';
import { INestApplication } from '@nestjs/common';
import { PrismaClient } from '@prisma/client';
import { cleanupDatabase, createTestApp, uniqueEmail, uniquePhone } from './utils';

describe('Trips + Bookings E2E', () => {
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

    it('creates trip, books, pays, checks in', async () => {
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
                licensePlate: `34TEST${Math.floor(Math.random() * 1000)}`,
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
                womenOnly: false,
                instantBooking: true,
            })
            .expect(201);

        const dateParam = departureTime.toISOString().slice(0, 10);
        const searchRes = await request(app.getHttpServer())
            .get('/trips')
            .query({ from: 'Istanbul', to: 'Ankara', date: dateParam, seats: 1, type: 'people' })
            .expect(200);

        expect(searchRes.body.trips.length).toBeGreaterThan(0);

        const bookingRes = await request(app.getHttpServer())
            .post('/bookings')
            .set('Authorization', `Bearer ${passengerToken}`)
            .send({
                tripId: tripRes.body.id,
                seats: 1,
                itemType: 'person',
            })
            .expect(201);

        expect(bookingRes.body.status).toBe('awaiting_payment');
        expect(bookingRes.body.qrCode).toBeTruthy();

        const paymentRes = await request(app.getHttpServer())
            .post('/bookings/payment')
            .set('Authorization', `Bearer ${passengerToken}`)
            .send({
                bookingId: bookingRes.body.id,
                cardToken: 'TEST_TOKEN',
            })
            .expect(200);

        expect(paymentRes.body.status).toBe('confirmed');

        const checkInRes = await request(app.getHttpServer())
            .post('/bookings/check-in')
            .set('Authorization', `Bearer ${driverToken}`)
            .send({ qrCode: bookingRes.body.qrCode })
            .expect(200);

        expect(checkInRes.body.status).toBe('checked_in');

        const myBookings = await request(app.getHttpServer())
            .get('/bookings/my')
            .set('Authorization', `Bearer ${passengerToken}`)
            .expect(200);

        expect(myBookings.body.bookings.length).toBeGreaterThan(0);

        const tripBookings = await request(app.getHttpServer())
            .get(`/bookings/trip/${tripRes.body.id}`)
            .set('Authorization', `Bearer ${driverToken}`)
            .expect(200);

        expect(tripBookings.body.bookings.length).toBeGreaterThan(0);
    });

    it('checks in with pnr code for matching trip', async () => {
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
                licensePlate: `34PNR${Math.floor(Math.random() * 1000)}`,
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

        expect(bookingRes.body.pnrCode).toBeTruthy();

        await request(app.getHttpServer())
            .post('/bookings/payment')
            .set('Authorization', `Bearer ${passengerToken}`)
            .send({
                bookingId: bookingRes.body.id,
                cardToken: 'TEST_TOKEN',
            })
            .expect(200);

        const checkInByPnrRes = await request(app.getHttpServer())
            .post('/bookings/check-in/pnr')
            .set('Authorization', `Bearer ${driverToken}`)
            .send({
                pnrCode: bookingRes.body.pnrCode,
                tripId: tripRes.body.id,
            })
            .expect(200);

        expect(checkInByPnrRes.body.status).toBe('checked_in');
    });
});

