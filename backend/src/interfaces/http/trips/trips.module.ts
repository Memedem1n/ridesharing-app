import { Module } from '@nestjs/common';
import { TripsController } from './trips.controller';
import { TripsService } from '@application/services/trips/trips.service';
import { PrismaService } from '@infrastructure/database/prisma.service';

@Module({
    controllers: [TripsController],
    providers: [TripsService, PrismaService],
    exports: [TripsService],
})
export class TripsModule { }
