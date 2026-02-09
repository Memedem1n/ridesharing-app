import { Controller, Get, Put, Post, Body, UseGuards, Request, Param, HttpCode, UseInterceptors, UploadedFile, BadRequestException } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth, ApiConsumes, ApiBody } from '@nestjs/swagger';
import { FileInterceptor } from '@nestjs/platform-express';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { UsersService } from '@application/services/users/users.service';
import { createUploadOptions } from '../uploads/upload.utils';
import {
    UpdateProfileDto,
    UserProfileDto,
    DeviceTokenDto,
    UpsertPayoutAccountDto,
    VerifyPayoutAccountDto,
    PayoutAccountDto,
} from '@application/dto/users/users.dto';

@ApiTags('Users')
@Controller('users')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class UsersController {
    constructor(private readonly usersService: UsersService) { }

    @Get('me')
    @ApiOperation({ summary: 'Get current user profile' })
    @ApiResponse({ status: 200, description: 'User profile', type: UserProfileDto })
    async getMe(@Request() req): Promise<UserProfileDto> {
        return this.usersService.findById(req.user.sub, true);
    }

    @Put('me')
    @ApiOperation({ summary: 'Update current user profile' })
    @ApiResponse({ status: 200, description: 'Profile updated', type: UserProfileDto })
    async updateMe(@Request() req, @Body() dto: UpdateProfileDto): Promise<UserProfileDto> {
        return this.usersService.updateProfile(req.user.sub, dto);
    }

    @Post('me/profile-photo')
    @HttpCode(200)
    @ApiOperation({ summary: 'Upload current user profile photo' })
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
    @ApiResponse({ status: 200, description: 'Profile photo updated', type: UserProfileDto })
    @UseInterceptors(
        FileInterceptor(
            'file',
            createUploadOptions('./uploads/profile', /\/(jpg|jpeg|png|webp)$/, 'Only image files are allowed!'),
        ),
    )
    async uploadProfilePhoto(@Request() req, @UploadedFile() file: Express.Multer.File): Promise<UserProfileDto> {
        if (!file) {
            throw new BadRequestException('File is required');
        }

        const fileUrl = `/uploads/profile/${file.filename}`;
        return this.usersService.updateProfile(req.user.sub, { profilePhotoUrl: fileUrl });
    }

    @Post('me/device-token')
    @HttpCode(200)
    @ApiOperation({ summary: 'Register device token for push notifications' })
    @ApiResponse({ status: 200, description: 'Device token registered', type: UserProfileDto })
    async registerDeviceToken(@Request() req, @Body() dto: DeviceTokenDto): Promise<UserProfileDto> {
        return this.usersService.registerDeviceToken(req.user.sub, dto);
    }

    @Get('me/payout-account')
    @ApiOperation({ summary: 'Get my payout account status' })
    @ApiResponse({ status: 200, description: 'Payout account', type: PayoutAccountDto })
    async getMyPayoutAccount(@Request() req): Promise<PayoutAccountDto> {
        return this.usersService.getPayoutAccount(req.user.sub);
    }

    @Post('me/payout-account')
    @HttpCode(200)
    @ApiOperation({ summary: 'Upsert payout IBAN account (identity verified users only)' })
    @ApiResponse({ status: 200, description: 'Payout account created/updated', type: UserProfileDto })
    async upsertPayoutAccount(@Request() req, @Body() dto: UpsertPayoutAccountDto): Promise<UserProfileDto> {
        return this.usersService.upsertPayoutAccount(req.user.sub, dto);
    }

    @Post('me/payout-account/verify')
    @HttpCode(200)
    @ApiOperation({ summary: 'Verify payout account via challenge code' })
    @ApiResponse({ status: 200, description: 'Payout account verified', type: UserProfileDto })
    async verifyPayoutAccount(@Request() req, @Body() dto: VerifyPayoutAccountDto): Promise<UserProfileDto> {
        return this.usersService.verifyPayoutAccount(req.user.sub, dto);
    }

    @Get(':id')
    @ApiOperation({ summary: 'Get user by ID (public profile)' })
    @ApiResponse({ status: 200, description: 'User profile', type: UserProfileDto })
    async getById(@Param('id') id: string): Promise<UserProfileDto> {
        return this.usersService.findById(id);
    }
}
