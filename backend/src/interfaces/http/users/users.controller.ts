import { Controller, Get, Put, Body, UseGuards, Request, Param } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { UsersService } from '@application/services/users/users.service';
import { UpdateProfileDto, UserProfileDto } from '@application/dto/users/users.dto';

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

    @Get(':id')
    @ApiOperation({ summary: 'Get user by ID (public profile)' })
    @ApiResponse({ status: 200, description: 'User profile', type: UserProfileDto })
    async getById(@Param('id') id: string): Promise<UserProfileDto> {
        return this.usersService.findById(id);
    }
}
