import { Controller, Get, Post, Body, Param, UseGuards, Request, Delete, HttpCode } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { BookingsService } from '@application/services/bookings/bookings.service';
import {
    CreateBookingDto,
    ProcessPaymentDto,
    CheckInDto,
    CheckInByPnrDto,
    RejectBookingDto,
    RaiseDisputeDto,
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
    @HttpCode(200)
    @ApiOperation({ summary: 'Process payment for booking' })
    @ApiResponse({ status: 200, description: 'Payment processed', type: BookingResponseDto })
    async processPayment(@Request() req, @Body() dto: ProcessPaymentDto): Promise<BookingResponseDto> {
        return this.bookingsService.processPayment(req.user.sub, dto);
    }

    @Post('check-in')
    @HttpCode(200)
    @ApiOperation({ summary: 'Check in passenger via QR code' })
    @ApiResponse({ status: 200, description: 'Checked in', type: BookingResponseDto })
    async checkIn(@Request() req, @Body() dto: CheckInDto): Promise<BookingResponseDto> {
        return this.bookingsService.checkIn(req.user.sub, dto.qrCode);
    }

    @Post('check-in/pnr')
    @HttpCode(200)
    @ApiOperation({ summary: 'Check in passenger via PNR code' })
    @ApiResponse({ status: 200, description: 'Checked in', type: BookingResponseDto })
    async checkInByPnr(@Request() req, @Body() dto: CheckInByPnrDto): Promise<BookingResponseDto> {
        return this.bookingsService.checkInByPnr(req.user.sub, dto.pnrCode, dto.tripId);
    }

    @Post(':id/accept')
    @HttpCode(200)
    @ApiOperation({ summary: 'Accept a booking request (driver only)' })
    @ApiResponse({ status: 200, description: 'Booking accepted', type: BookingResponseDto })
    async accept(@Request() req, @Param('id') id: string): Promise<BookingResponseDto> {
        return this.bookingsService.accept(id, req.user.sub);
    }

    @Post(':id/reject')
    @HttpCode(200)
    @ApiOperation({ summary: 'Reject a booking request (driver only)' })
    @ApiResponse({ status: 200, description: 'Booking rejected', type: BookingResponseDto })
    async reject(@Request() req, @Param('id') id: string, @Body() dto: RejectBookingDto): Promise<BookingResponseDto> {
        return this.bookingsService.reject(id, req.user.sub, dto.reason);
    }

    @Post(':id/complete')
    @HttpCode(200)
    @ApiOperation({ summary: 'Mark booking completed (passenger)' })
    @ApiResponse({ status: 200, description: 'Booking completed', type: BookingResponseDto })
    async complete(@Request() req, @Param('id') id: string): Promise<BookingResponseDto> {
        return this.bookingsService.completeByPassenger(id, req.user.sub);
    }

    @Post(':id/dispute')
    @HttpCode(200)
    @ApiOperation({ summary: 'Raise booking dispute within dispute window' })
    @ApiResponse({ status: 200, description: 'Dispute opened', type: BookingResponseDto })
    async dispute(@Request() req, @Param('id') id: string, @Body() dto: RaiseDisputeDto): Promise<BookingResponseDto> {
        return this.bookingsService.raiseDispute(id, req.user.sub, dto.reason);
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
