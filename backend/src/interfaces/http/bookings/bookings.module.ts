import { Module } from '@nestjs/common';
import { BookingsController } from './bookings.controller';
import { BookingsService } from '@application/services/bookings/bookings.service';
import { IyzicoService } from '@infrastructure/payment/iyzico.service';
import { PrismaService } from '@infrastructure/database/prisma.service';

@Module({
    controllers: [BookingsController],
    providers: [BookingsService, IyzicoService, PrismaService],
    exports: [BookingsService],
})
export class BookingsModule { }
