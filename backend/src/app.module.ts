import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ThrottlerModule } from '@nestjs/throttler';
import { ScheduleModule } from '@nestjs/schedule';
import { AuthModule } from './interfaces/http/auth/auth.module';
import { UsersModule } from './interfaces/http/users/users.module';
import { TripsModule } from './interfaces/http/trips/trips.module';
import { BookingsModule } from './interfaces/http/bookings/bookings.module';
import { VehiclesModule } from './interfaces/http/vehicles/vehicles.module';
import { MessagesModule } from './interfaces/http/messages/messages.module';
import { VerificationModule } from './interfaces/http/verification/verification.module';
import { HealthController } from './interfaces/http/health/health.controller';

@Module({
    imports: [
        // Environment configuration
        ConfigModule.forRoot({
            isGlobal: true,
            envFilePath: '.env',
        }),

        // Rate limiting
        ThrottlerModule.forRoot([{
            ttl: 900000, // 15 minutes
            limit: 100,
        }]),

        // Scheduled tasks (cron jobs)
        ScheduleModule.forRoot(),

        // Feature modules
        AuthModule,
        UsersModule,
        VehiclesModule,
        TripsModule,
        BookingsModule,
        MessagesModule,
        VerificationModule,
    ],
    controllers: [HealthController],
    providers: [],
})
export class AppModule { }
