import { Module } from '@nestjs/common';
import { AdminController } from './admin.controller';
import { AdminService } from '@application/services/admin/admin.service';
import { PrismaService } from '@infrastructure/database/prisma.service';
import { BusPriceModule } from '@infrastructure/scraper/bus-price.module';
import { AdminKeyGuard } from './guards/admin-key.guard';

@Module({
    imports: [BusPriceModule],
    controllers: [AdminController],
    providers: [AdminService, PrismaService, AdminKeyGuard],
})
export class AdminModule { }
