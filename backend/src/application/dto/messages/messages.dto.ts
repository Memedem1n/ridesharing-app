import { IsString, IsNotEmpty, IsUUID, IsOptional, IsNumber, IsBoolean } from 'class-validator';
import { ApiProperty, ApiPropertyOptional } from '@nestjs/swagger';
import { Type } from 'class-transformer';

export class SendMessageDto {
    @ApiProperty()
    @IsNotEmpty()
    @IsUUID()
    bookingId: string;

    @ApiProperty()
    @IsNotEmpty()
    @IsString()
    message: string;
}

export class GetConversationDto {
    @ApiPropertyOptional({ default: 1 })
    @IsOptional()
    @Type(() => Number)
    @IsNumber()
    page?: number = 1;

    @ApiPropertyOptional({ default: 50 })
    @IsOptional()
    @Type(() => Number)
    @IsNumber()
    limit?: number = 50;
}

export class MessageResponseDto {
    @ApiProperty()
    id: string;

    @ApiProperty()
    bookingId: string;

    @ApiProperty()
    senderId: string;

    @ApiProperty()
    receiverId: string;

    @ApiProperty()
    message: string;

    @ApiProperty()
    read: boolean;

    @ApiProperty()
    createdAt: Date;

    @ApiPropertyOptional()
    sender?: {
        id: string;
        fullName: string;
        profilePhotoUrl?: string;
    };
}

export class ConversationDto {
    @ApiProperty()
    bookingId: string;

    @ApiProperty()
    tripInfo: {
        departureCity: string;
        arrivalCity: string;
        departureTime: Date;
    };

    @ApiProperty()
    otherUser: {
        id: string;
        fullName: string;
        profilePhotoUrl?: string;
    };

    @ApiProperty()
    lastMessage?: MessageResponseDto;

    @ApiProperty()
    unreadCount: number;

    @ApiProperty()
    updatedAt: Date;
}

export class ConversationListDto {
    @ApiProperty({ type: [ConversationDto] })
    conversations: ConversationDto[];

    @ApiProperty()
    total: number;
}

export class MessageListDto {
    @ApiProperty({ type: [MessageResponseDto] })
    messages: MessageResponseDto[];

    @ApiProperty()
    total: number;

    @ApiProperty()
    page: number;

    @ApiProperty()
    hasMore: boolean;
}

// WebSocket Events
export class WsMessageEvent {
    type: 'message';
    payload: MessageResponseDto;
}

export class WsTypingEvent {
    type: 'typing';
    payload: {
        bookingId: string;
        userId: string;
        isTyping: boolean;
    };
}

export class WsReadEvent {
    type: 'read';
    payload: {
        bookingId: string;
        readBy: string;
    };
}
