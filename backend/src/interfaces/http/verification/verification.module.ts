import { Module } from '@nestjs/common';
import { VerificationController } from '../../../controllers/VerificationController';
import { PrismaService } from '../../../infrastructure/database/prisma.service';
import { OcrService } from '../../../infrastructure/ocr/ocr.service';
import { VerificationService } from '../../../application/services/verification/verification.service';

@Module({
    controllers: [VerificationController],
    providers: [PrismaService, OcrService, VerificationService],
})
export class VerificationModule { }
