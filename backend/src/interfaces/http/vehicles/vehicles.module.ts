import { Module } from '@nestjs/common';
import { VehiclesController } from './vehicles.controller';
import { VehiclesService } from '@application/services/vehicles/vehicles.service';
import { PrismaService } from '@infrastructure/database/prisma.service';

@Module({
    controllers: [VehiclesController],
    providers: [VehiclesService, PrismaService],
    exports: [VehiclesService],
})
export class VehiclesModule { }
