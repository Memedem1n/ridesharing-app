import { Module } from '@nestjs/common';
import { VerificationController } from '../../../controllers/VerificationController';
import { PrismaService } from '../../../infrastructure/database/prisma.service';

@Module({
    controllers: [VerificationController],
    providers: [PrismaService],
})
export class VerificationModule { }
