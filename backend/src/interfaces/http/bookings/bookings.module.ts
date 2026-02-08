import { Module } from '@nestjs/common';
import { BookingsController } from './bookings.controller';
import { BookingsService } from '@application/services/bookings/bookings.service';
import { BookingExpiryService } from '@application/services/bookings/booking-expiry.service';
import { BookingSettlementService } from '@application/services/bookings/booking-settlement.service';
import { IyzicoService } from '@infrastructure/payment/iyzico.service';
import { PrismaService } from '@infrastructure/database/prisma.service';
import { NotificationsModule } from '@infrastructure/notifications/notifications.module';

@Module({
    imports: [NotificationsModule],
    controllers: [BookingsController],
    providers: [BookingsService, BookingExpiryService, BookingSettlementService, IyzicoService, PrismaService],
    exports: [BookingsService],
})
export class BookingsModule { }
