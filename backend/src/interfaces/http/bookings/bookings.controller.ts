import { Controller, Get, Post, Body, Param, UseGuards, Request, Delete } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { BookingsService } from '@application/services/bookings/bookings.service';
import {
    CreateBookingDto,
    ProcessPaymentDto,
    CheckInDto,
    CheckInByPnrDto,
    BookingResponseDto,
    BookingListResponseDto
} from '@application/dto/bookings/bookings.dto';

@ApiTags('Bookings')
@Controller('bookings')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class BookingsController {
    constructor(private readonly bookingsService: BookingsService) { }

    @Post()
    @ApiOperation({ summary: 'Create booking' })
    @ApiResponse({ status: 201, description: 'Booking created', type: BookingResponseDto })
    async create(@Request() req, @Body() dto: CreateBookingDto): Promise<BookingResponseDto> {
        return this.bookingsService.create(req.user.sub, dto);
    }

    @Post('payment')
    @ApiOperation({ summary: 'Process payment for booking' })
    @ApiResponse({ status: 200, description: 'Payment processed', type: BookingResponseDto })
    async processPayment(@Request() req, @Body() dto: ProcessPaymentDto): Promise<BookingResponseDto> {
        return this.bookingsService.processPayment(req.user.sub, dto);
    }

    @Post('check-in')
    @ApiOperation({ summary: 'Check in passenger via QR code' })
    @ApiResponse({ status: 200, description: 'Checked in', type: BookingResponseDto })
    async checkIn(@Request() req, @Body() dto: CheckInDto): Promise<BookingResponseDto> {
        return this.bookingsService.checkIn(req.user.sub, dto.qrCode);
    }

    @Post('check-in/pnr')
    @ApiOperation({ summary: 'Check in passenger via PNR code' })
    @ApiResponse({ status: 200, description: 'Checked in', type: BookingResponseDto })
    async checkInByPnr(@Request() req, @Body() dto: CheckInByPnrDto): Promise<BookingResponseDto> {
        return this.bookingsService.checkInByPnr(req.user.sub, dto.pnrCode, dto.tripId);
    }

    @Get('my')
    @ApiOperation({ summary: 'Get my bookings' })
    @ApiResponse({ status: 200, description: 'My bookings', type: BookingListResponseDto })
    async getMyBookings(@Request() req): Promise<BookingListResponseDto> {
        return this.bookingsService.findMyBookings(req.user.sub);
    }

    @Get('trip/:tripId')
    @ApiOperation({ summary: 'Get bookings for a trip (driver only)' })
    @ApiResponse({ status: 200, description: 'Trip bookings', type: BookingListResponseDto })
    async getTripBookings(@Request() req, @Param('tripId') tripId: string): Promise<BookingListResponseDto> {
        return this.bookingsService.findTripBookings(tripId, req.user.sub);
    }

    @Get(':id')
    @ApiOperation({ summary: 'Get booking by ID' })
    @ApiResponse({ status: 200, description: 'Booking detail', type: BookingResponseDto })
    async getById(@Request() req, @Param('id') id: string): Promise<BookingResponseDto> {
        return this.bookingsService.findById(id, req.user.sub);
    }

    @Delete(':id')
    @ApiOperation({ summary: 'Cancel booking' })
    @ApiResponse({ status: 200, description: 'Booking cancelled' })
    async cancel(@Request() req, @Param('id') id: string): Promise<void> {
        return this.bookingsService.cancel(id, req.user.sub);
    }
}
