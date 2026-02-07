import { Controller, Get, Put, Post, Body, UseGuards, Request, Param } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { UsersService } from '@application/services/users/users.service';
import { UpdateProfileDto, UserProfileDto, DeviceTokenDto } from '@application/dto/users/users.dto';

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
        return this.usersService.findById(req.user.sub);
    }

    @Put('me')
    @ApiOperation({ summary: 'Update current user profile' })
    @ApiResponse({ status: 200, description: 'Profile updated', type: UserProfileDto })
    async updateMe(@Request() req, @Body() dto: UpdateProfileDto): Promise<UserProfileDto> {
        return this.usersService.updateProfile(req.user.sub, dto);
    }

    @Post('me/device-token')
    @ApiOperation({ summary: 'Register device token for push notifications' })
    @ApiResponse({ status: 200, description: 'Device token registered', type: UserProfileDto })
    async registerDeviceToken(@Request() req, @Body() dto: DeviceTokenDto): Promise<UserProfileDto> {
        return this.usersService.registerDeviceToken(req.user.sub, dto);
    }

    @Get(':id')
    @ApiOperation({ summary: 'Get user by ID (public profile)' })
    @ApiResponse({ status: 200, description: 'User profile', type: UserProfileDto })
    async getById(@Param('id') id: string): Promise<UserProfileDto> {
        return this.usersService.findById(id);
    }
}
