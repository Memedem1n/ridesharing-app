import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { PrismaService } from '@infrastructure/database/prisma.service';

@Injectable()
export class BookingExpiryService {
    private readonly logger = new Logger(BookingExpiryService.name);

    constructor(private readonly prisma: PrismaService) { }

    @Cron('*/5 * * * *')
    async expirePendingBookings() {
        const now = new Date();

        const expiredBookings = await this.prisma.booking.findMany({
            where: {
                status: 'pending',
                expiresAt: { lt: now },
            },
            include: { trip: true },
        });

        if (expiredBookings.length === 0) return;

        for (const booking of expiredBookings) {
            await this.prisma.$transaction(async (tx) => {
                await tx.booking.update({
                    where: { id: booking.id },
                    data: {
                        status: 'expired',
                        cancellationTime: now,
                        cancellationPenalty: 0,
                        paymentStatus: 'pending',
                        expiresAt: null,
                    },
                });

                await tx.trip.updateMany({
                    where: {
                        id: booking.tripId,
                        status: { in: ['published', 'full'] },
                    },
                    data: {
                        availableSeats: { increment: booking.seats },
                        status: 'published',
                    },
                });
            });
        }

        this.logger.warn(`Expired ${expiredBookings.length} pending bookings.`);
    }
}
