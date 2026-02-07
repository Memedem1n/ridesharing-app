import { Body, Controller, Get, Param, Post, Query, UseGuards } from '@nestjs/common';
import { ApiBearerAuth, ApiHeader, ApiOperation, ApiTags } from '@nestjs/swagger';
import { AdminService } from '@application/services/admin/admin.service';
import { AdminBusPriceDto, AdminVerificationUpdateDto, AdminVerificationUserDto } from '@application/dto/admin/admin.dto';
import { AdminKeyGuard } from './guards/admin-key.guard';

@ApiTags('Admin')
@ApiHeader({ name: 'x-admin-key', required: true })
@ApiBearerAuth()
@UseGuards(AdminKeyGuard)
@Controller('admin')
export class AdminController {
    constructor(private readonly adminService: AdminService) { }

    @Get('verifications')
    @ApiOperation({ summary: 'List verification requests' })
    async listVerifications(
        @Query('status') status?: 'pending' | 'verified' | 'rejected',
    ): Promise<AdminVerificationUserDto[]> {
        return this.adminService.listVerifications(status);
    }

    @Post('verifications/:userId/identity')
    @ApiOperation({ summary: 'Update identity verification status' })
    async updateIdentity(
        @Param('userId') userId: string,
        @Body() dto: AdminVerificationUpdateDto,
    ) {
        return this.adminService.updateVerification(userId, 'identity', dto.status);
    }

    @Post('verifications/:userId/license')
    @ApiOperation({ summary: 'Update license verification status' })
    async updateLicense(
        @Param('userId') userId: string,
        @Body() dto: AdminVerificationUpdateDto,
    ) {
        return this.adminService.updateVerification(userId, 'license', dto.status);
    }

    @Post('verifications/:userId/criminal-record')
    @ApiOperation({ summary: 'Update criminal record verification status' })
    async updateCriminalRecord(
        @Param('userId') userId: string,
        @Body() dto: AdminVerificationUpdateDto,
    ) {
        return this.adminService.updateVerification(userId, 'criminal-record', dto.status);
    }

    @Get('bus-prices')
    @ApiOperation({ summary: 'List cached bus prices' })
    async listBusPrices() {
        return this.adminService.listBusPrices();
    }

    @Post('bus-prices')
    @ApiOperation({ summary: 'Set manual bus price' })
    async setBusPrice(@Body() dto: AdminBusPriceDto) {
        return this.adminService.setBusPrice(dto.from, dto.to, dto.price, dto.source);
    }
}

