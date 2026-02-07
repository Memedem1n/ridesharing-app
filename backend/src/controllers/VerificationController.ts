import {
    Controller,
    Post,
    UseInterceptors,
    UploadedFile,
    UploadedFiles,
    UseGuards,
    Req,
    BadRequestException,
    Get
} from '@nestjs/common';
import { FileInterceptor, FileFieldsInterceptor } from '@nestjs/platform-express';
import { ApiTags, ApiOperation, ApiConsumes, ApiBody, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../interfaces/http/auth/guards/jwt-auth.guard';
import { createUploadOptions } from '../interfaces/http/uploads/upload.utils';
import { VerificationService } from '../application/services/verification/verification.service';
import { PrismaService } from '../infrastructure/database/prisma.service';

@ApiTags('Verification')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('verification')
export class VerificationController {
    constructor(
        private readonly verificationService: VerificationService,
        private readonly prisma: PrismaService,
    ) { }

    @Post('upload-identity')
    @ApiOperation({ summary: 'Upload identity document (ID Card)' })
    @ApiConsumes('multipart/form-data')
    @ApiBody({
        schema: {
            type: 'object',
            properties: {
                file: {
                    type: 'string',
                    format: 'binary',
                },
            },
        },
    })
    @UseInterceptors(FileInterceptor('file', createUploadOptions('./uploads/identity', /\/(jpg|jpeg|png)$/, 'Only image files are allowed!')))
    async uploadIdentity(@UploadedFile() file: Express.Multer.File, @Req() req: any) {
        if (!file) {
            throw new BadRequestException('File is required');
        }

        const userId = req.user.sub;
        const fileUrl = `/uploads/identity/${file.filename}`;

        const ocr = await this.verificationService.verifyIdentity(userId, file.path, fileUrl);

        return {
            message: 'Identity document uploaded successfully',
            url: fileUrl,
            status: ocr.status,
            ocr,
        };
    }

    @Post('upload-license')
    @ApiOperation({ summary: 'Upload driver license (front/back)' })
    @ApiConsumes('multipart/form-data')
    @ApiBody({
        schema: {
            type: 'object',
            properties: {
                front: {
                    type: 'string',
                    format: 'binary',
                },
                back: {
                    type: 'string',
                    format: 'binary',
                },
                file: {
                    type: 'string',
                    format: 'binary',
                },
            },
        },
    })
    @UseInterceptors(FileFieldsInterceptor([
        { name: 'front', maxCount: 1 },
        { name: 'back', maxCount: 1 },
        { name: 'file', maxCount: 1 },
    ], createUploadOptions('./uploads/license', /\/(jpg|jpeg|png)$/, 'Only image files are allowed!')))
    async uploadLicense(
        @UploadedFiles() files: { front?: Express.Multer.File[]; back?: Express.Multer.File[]; file?: Express.Multer.File[] },
        @Req() req: any,
    ) {
        const front = files?.front?.[0];
        const back = files?.back?.[0];
        const single = files?.file?.[0];
        const selected = [front, back, single].filter(Boolean) as Express.Multer.File[];

        if (selected.length === 0) {
            throw new BadRequestException('File is required');
        }

        const userId = req.user.sub;
        const primary = front || single || back;
        const fileUrl = `/uploads/license/${primary.filename}`;

        const filePaths = selected.map((item) => item.path);
        const ocr = await this.verificationService.verifyLicense(userId, filePaths, fileUrl);

        return {
            message: 'License document uploaded successfully',
            url: fileUrl,
            status: ocr.status,
            ocr,
        };
    }

    @Post('upload-vehicle-registration')
    @ApiOperation({ summary: 'Upload vehicle registration document' })
    @ApiConsumes('multipart/form-data')
    @ApiBody({
        schema: {
            type: 'object',
            properties: {
                file: {
                    type: 'string',
                    format: 'binary',
                },
            },
        },
    })
    @UseInterceptors(FileInterceptor('file', createUploadOptions('./uploads/registrations', /\/(jpg|jpeg|png)$/, 'Only image files are allowed!')))
    async uploadVehicleRegistration(@UploadedFile() file: Express.Multer.File) {
        if (!file) {
            throw new BadRequestException('File is required');
        }

        const fileUrl = `/uploads/registrations/${file.filename}`;

        return {
            message: 'Registration document uploaded successfully',
            url: fileUrl,
        };
    }

    @Post('upload-criminal-record')
    @ApiOperation({ summary: 'Upload criminal record document' })
    @ApiConsumes('multipart/form-data')
    @ApiBody({
        schema: {
            type: 'object',
            properties: {
                file: {
                    type: 'string',
                    format: 'binary',
                },
            },
        },
    })
    @UseInterceptors(FileInterceptor('file', createUploadOptions('./uploads/criminal-records', /\/(jpg|jpeg|png|pdf)$/, 'Only image files or PDFs are allowed!')))
    async uploadCriminalRecord(@UploadedFile() file: Express.Multer.File, @Req() req: any) {
        if (!file) {
            throw new BadRequestException('File is required');
        }

        const userId = req.user.sub;
        const fileUrl = `/uploads/criminal-records/${file.filename}`;

        const ocr = await this.verificationService.verifyCriminalRecord(userId, file.path, fileUrl);

        return {
            message: 'Criminal record document uploaded successfully',
            url: fileUrl,
            status: ocr.status,
            ocr,
        };
    }

    @Get('status')
    @ApiOperation({ summary: 'Get current verification status' })
    async getStatus(@Req() req: any) {
        const user = await this.prisma.user.findUnique({
            where: { id: req.user.sub },
            select: {
                identityStatus: true,
                licenseStatus: true,
                criminalRecordStatus: true,
                identityDocumentUrl: true,
                licenseDocumentUrl: true,
                criminalRecordDocumentUrl: true,
                verified: true,
            }
        });

        return user;
    }
}

