import { Module } from '@nestjs/common';
import { ConfigModule } from '@nestjs/config';
import { ThrottlerModule } from '@nestjs/throttler';
import { ScheduleModule } from '@nestjs/schedule';
import { ServeStaticModule } from '@nestjs/serve-static';
import { join } from 'path';
import { AuthModule } from './interfaces/http/auth/auth.module';
import { UsersModule } from './interfaces/http/users/users.module';
import { TripsModule } from './interfaces/http/trips/trips.module';
import { BookingsModule } from './interfaces/http/bookings/bookings.module';
import { VehiclesModule } from './interfaces/http/vehicles/vehicles.module';
import { MessagesModule } from './interfaces/http/messages/messages.module';
import { VerificationModule } from './interfaces/http/verification/verification.module';
import { AdminModule } from './interfaces/http/admin/admin.module';
import { HealthController } from './interfaces/http/health/health.controller';
import { PrismaService } from './infrastructure/database/prisma.service';
import { CacheModule } from './infrastructure/cache/cache.module';
import { BusPriceModule } from './infrastructure/scraper/bus-price.module';
import { LocationModule } from './interfaces/websocket/location.module';

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

        // Static uploads (local dev)
        ServeStaticModule.forRoot({
            rootPath: join(process.cwd(), 'uploads'),
            serveRoot: '/uploads',
        }),

        // Shared infrastructure
        CacheModule,
        BusPriceModule,

        // Feature modules
        AuthModule,
        UsersModule,
        VehiclesModule,
        TripsModule,
        BookingsModule,
        MessagesModule,
        VerificationModule,
        AdminModule,
        LocationModule,
    ],
    controllers: [HealthController],
    providers: [PrismaService],
})
export class AppModule { }
