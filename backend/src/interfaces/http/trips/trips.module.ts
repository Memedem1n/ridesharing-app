import { Module } from "@nestjs/common";
import { TripsController } from "./trips.controller";
import { TripsService } from "@application/services/trips/trips.service";
import { PrismaService } from "@infrastructure/database/prisma.service";
import { NotificationsModule } from "@infrastructure/notifications/notifications.module";
import { BusPriceModule } from "@infrastructure/scraper/bus-price.module";
import { CacheModule } from "@infrastructure/cache/cache.module";
import { IyzicoService } from "@infrastructure/payment/iyzico.service";
import { MapsModule } from "@infrastructure/maps/maps.module";
import { RoutesController } from "./routes.controller";

@Module({
  imports: [NotificationsModule, BusPriceModule, CacheModule, MapsModule],
  controllers: [TripsController, RoutesController],
  providers: [TripsService, PrismaService, IyzicoService],
  exports: [TripsService],
})
export class TripsModule {}
