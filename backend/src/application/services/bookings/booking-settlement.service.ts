import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { BookingsService } from './bookings.service';

@Injectable()
export class BookingSettlementService {
    private readonly logger = new Logger(BookingSettlementService.name);

    constructor(private readonly bookingsService: BookingsService) { }

    @Cron('*/5 * * * *')
    async autoCompleteCheckedInBookings() {
        const completed = await this.bookingsService.autoCompleteEligibleBookings();
        if (completed > 0) {
            this.logger.log(`Auto-completed bookings: ${completed}`);
        }
    }

    @Cron('30 */5 * * * *')
    async releaseScheduledPayouts() {
        const result = await this.bookingsService.releasePendingPayouts();
        if (result.stage10Released > 0 || result.stage90Released > 0) {
            this.logger.log(`Released payouts stage10=${result.stage10Released}, stage90=${result.stage90Released}`);
        }
    }
}
