import { Controller, Get, Post, Body, Param, Query, UseGuards, Request, HttpCode } from '@nestjs/common';
import { ApiTags, ApiOperation, ApiResponse, ApiBearerAuth } from '@nestjs/swagger';
import { JwtAuthGuard } from '../auth/guards/jwt-auth.guard';
import { MessagesService } from '@application/services/messages/messages.service';
import {
    SendMessageDto,
    GetConversationDto,
    ConversationDto,
    MessageResponseDto,
    ConversationListDto,
    MessageListDto,
} from '@application/dto/messages/messages.dto';

@ApiTags('Messages')
@Controller('messages')
@UseGuards(JwtAuthGuard)
@ApiBearerAuth()
export class MessagesController {
    constructor(private readonly messagesService: MessagesService) { }

    @Post('open-trip/:tripId')
    @HttpCode(200)
    @ApiOperation({ summary: 'Open or reuse trip chat without reservation' })
    @ApiResponse({ status: 200, description: 'Conversation opened', type: ConversationDto })
    async openTripConversation(@Request() req, @Param('tripId') tripId: string): Promise<ConversationDto> {
        return this.messagesService.openTripConversation(req.user.sub, tripId);
    }

    @Get('conversations')
    @ApiOperation({ summary: 'Get all conversations' })
    @ApiResponse({ status: 200, description: 'Conversation list', type: ConversationListDto })
    async getConversations(@Request() req): Promise<ConversationListDto> {
        return this.messagesService.getConversations(req.user.sub);
    }

    @Get('conversation/:bookingId')
    @ApiOperation({ summary: 'Get messages for a conversation' })
    @ApiResponse({ status: 200, description: 'Message list', type: MessageListDto })
    async getMessages(
        @Request() req,
        @Param('bookingId') bookingId: string,
        @Query() query: GetConversationDto,
    ): Promise<MessageListDto> {
        return this.messagesService.getMessages(req.user.sub, bookingId, query.page, query.limit);
    }

    @Post()
    @ApiOperation({ summary: 'Send message' })
    @ApiResponse({ status: 201, description: 'Message sent', type: MessageResponseDto })
    async sendMessage(@Request() req, @Body() dto: SendMessageDto): Promise<MessageResponseDto> {
        return this.messagesService.sendMessage(req.user.sub, dto);
    }

    @Post('read/:bookingId')
    @ApiOperation({ summary: 'Mark messages as read' })
    @ApiResponse({ status: 200, description: 'Messages marked as read' })
    async markAsRead(@Request() req, @Param('bookingId') bookingId: string): Promise<void> {
        return this.messagesService.markAsRead(req.user.sub, bookingId);
    }

    @Get('unread-count')
    @ApiOperation({ summary: 'Get unread message count' })
    @ApiResponse({ status: 200, description: 'Unread count' })
    async getUnreadCount(@Request() req): Promise<{ count: number }> {
        const count = await this.messagesService.getUnreadCount(req.user.sub);
        return { count };
    }
}
