import { Controller, Get, Post, Put, Delete, Body, Param, UseGuards, Request } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { VehiclesService } from '@application/services/vehicles/vehicles.service';
import { CreateVehicleDto, UpdateVehicleDto, VehicleResponseDto } from '@application/dto/vehicles/vehicles.dto';

@ApiTags('Vehicles')
@Controller('vehicles')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class VehiclesController {
    constructor(private readonly vehiclesService: VehiclesService) { }

    @Post()
    @ApiOperation({ summary: 'Add new vehicle' })
    @ApiResponse({ status: 201, description: 'Vehicle added', type: VehicleResponseDto })
    async create(@Request() req, @Body() dto: CreateVehicleDto): Promise<VehicleResponseDto> {
        return this.vehiclesService.create(req.user.sub, dto);
    }

    @Get()
    @ApiOperation({ summary: 'Get my vehicles' })
    @ApiResponse({ status: 200, description: 'My vehicles', type: [VehicleResponseDto] })
    async getMyVehicles(@Request() req): Promise<VehicleResponseDto[]> {
        return this.vehiclesService.findByUser(req.user.sub);
    }

    @Get(':id')
    @ApiOperation({ summary: 'Get vehicle by ID' })
    @ApiResponse({ status: 200, description: 'Vehicle details', type: VehicleResponseDto })
    async getById(@Request() req, @Param('id') id: string): Promise<VehicleResponseDto> {
        return this.vehiclesService.findById(id, req.user.sub);
    }

    @Put(':id')
    @ApiOperation({ summary: 'Update vehicle' })
    @ApiResponse({ status: 200, description: 'Vehicle updated', type: VehicleResponseDto })
    async update(
        @Request() req,
        @Param('id') id: string,
        @Body() dto: UpdateVehicleDto,
    ): Promise<VehicleResponseDto> {
        return this.vehiclesService.update(id, req.user.sub, dto);
    }

    @Delete(':id')
    @ApiOperation({ summary: 'Delete vehicle' })
    @ApiResponse({ status: 200, description: 'Vehicle deleted' })
    async delete(@Request() req, @Param('id') id: string): Promise<void> {
        return this.vehiclesService.delete(id, req.user.sub);
    }
}
