import {
    Controller,
    Post,
    UseInterceptors,
    UploadedFile,
    UseGuards,
    Req,
    BadRequestException,
    Get
} from '@nestjs/common';
import { FileInterceptor } from '@nestjs/platform-express';
import { ApiTags, ApiOperation, ApiConsumes, ApiBody, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../interfaces/http/auth/guards/jwt-auth.guard';
import { PrismaService } from '../infrastructure/database/prisma.service';
import { createUploadOptions } from '../interfaces/http/uploads/upload.utils';

@ApiTags('Verification')
@ApiBearerAuth()
@UseGuards(JwtAuthGuard)
@Controller('verification')
export class VerificationController {
    constructor(private prisma: PrismaService) { }

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

        const userId = req.user.id;
        const fileUrl = `/uploads/identity/${file.filename}`;

        await this.prisma.user.update({
            where: { id: userId },
            data: {
                identityDocumentUrl: fileUrl,
                identityStatus: 'pending', // Set to pending for admin review
            },
        });

        return {
            message: 'Identity document uploaded successfully',
            url: fileUrl,
            status: 'pending'
        };
    }

    @Post('upload-license')
    @ApiOperation({ summary: 'Upload driver license' })
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
    @UseInterceptors(FileInterceptor('file', createUploadOptions('./uploads/license', /\/(jpg|jpeg|png)$/, 'Only image files are allowed!')))
    async uploadLicense(@UploadedFile() file: Express.Multer.File, @Req() req: any) {
        if (!file) {
            throw new BadRequestException('File is required');
        }

        const userId = req.user.id;
        const fileUrl = `/uploads/license/${file.filename}`;

        await this.prisma.user.update({
            where: { id: userId },
            data: {
                licenseDocumentUrl: fileUrl,
                licenseStatus: 'pending',
            },
        });

        return {
            message: 'License document uploaded successfully',
            url: fileUrl,
            status: 'pending'
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

        const userId = req.user.id;
        const fileUrl = `/uploads/criminal-records/${file.filename}`;

        await this.prisma.user.update({
            where: { id: userId },
            data: {
                criminalRecordDocumentUrl: fileUrl,
                criminalRecordStatus: 'pending',
            },
        });

        return {
            message: 'Criminal record document uploaded successfully',
            url: fileUrl,
            status: 'pending'
        };
    }

    @Get('status')
    @ApiOperation({ summary: 'Get current verification status' })
    async getStatus(@Req() req: any) {
        const user = await this.prisma.user.findUnique({
            where: { id: req.user.id },
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
