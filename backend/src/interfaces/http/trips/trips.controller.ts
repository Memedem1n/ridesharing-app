import { Controller, Get, Post, Put, Delete, Body, Param, Query, UseGuards, Request } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth, ApiQuery } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { TripsService } from '@application/services/trips/trips.service';
import {
    CreateTripDto,
    UpdateTripDto,
    SearchTripsDto,
    TripResponseDto,
    TripListResponseDto
} from '@application/dto/trips/trips.dto';

@ApiTags('Trips')
@Controller('trips')
export class TripsController {
    constructor(private readonly tripsService: TripsService) { }

    @Get()
    @ApiOperation({ summary: 'Search trips' })
    @ApiResponse({ status: 200, description: 'List of trips', type: TripListResponseDto })
    async search(@Query() query: SearchTripsDto): Promise<TripListResponseDto> {
        return this.tripsService.findAll(query);
    }

    @Get('my')
    @UseGuards(JwtAuthGuard)
    @ApiBearerAuth()
    @ApiOperation({ summary: 'Get my trips (as driver)' })
    @ApiResponse({ status: 200, description: 'My trips', type: [TripResponseDto] })
    async getMyTrips(@Request() req): Promise<TripResponseDto[]> {
        return this.tripsService.findByDriver(req.user.sub);
    }

    @Get(':id')
    @ApiOperation({ summary: 'Get trip details' })
    @ApiResponse({ status: 200, description: 'Trip details', type: TripResponseDto })
    @ApiResponse({ status: 404, description: 'Trip not found' })
    async getById(@Param('id') id: string): Promise<TripResponseDto> {
        return this.tripsService.findById(id);
    }

    @Post()
    @UseGuards(JwtAuthGuard)
    @ApiBearerAuth()
    @ApiOperation({ summary: 'Create new trip' })
    @ApiResponse({ status: 201, description: 'Trip created', type: TripResponseDto })
    async create(@Request() req, @Body() dto: CreateTripDto): Promise<TripResponseDto> {
        return this.tripsService.create(req.user.sub, dto);
    }

    @Put(':id')
    @UseGuards(JwtAuthGuard)
    @ApiBearerAuth()
    @ApiOperation({ summary: 'Update trip' })
    @ApiResponse({ status: 200, description: 'Trip updated', type: TripResponseDto })
    async update(
        @Param('id') id: string,
        @Request() req,
        @Body() dto: UpdateTripDto,
    ): Promise<TripResponseDto> {
        return this.tripsService.update(id, req.user.sub, dto);
    }

    @Delete(':id')
    @UseGuards(JwtAuthGuard)
    @ApiBearerAuth()
    @ApiOperation({ summary: 'Cancel trip' })
    @ApiResponse({ status: 200, description: 'Trip cancelled' })
    async cancel(@Param('id') id: string, @Request() req): Promise<void> {
        return this.tripsService.cancel(id, req.user.sub);
    }
}
