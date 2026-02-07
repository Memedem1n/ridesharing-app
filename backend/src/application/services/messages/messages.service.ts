import { Injectable, NotFoundException, ForbiddenException } from '@nestjs/common';
import { PrismaService } from '@infrastructure/database/prisma.service';
import { FcmService } from '@infrastructure/notifications/fcm.service';
import {
    SendMessageDto,
    MessageResponseDto,
    ConversationDto,
    ConversationListDto,
    MessageListDto,
} from '@application/dto/messages/messages.dto';
import { v4 as uuid } from 'uuid';

@Injectable()
export class MessagesService {
    constructor(
        private readonly prisma: PrismaService,
        private readonly fcmService: FcmService,
    ) { }

    async sendMessage(senderId: string, dto: SendMessageDto): Promise<MessageResponseDto> {
        // Verify booking exists and user is participant
        const booking = await this.prisma.booking.findUnique({
            where: { id: dto.bookingId },
            include: {
                trip: { include: { driver: true } },
                passenger: true,
            },
        });

        if (!booking) {
            throw new NotFoundException('Rezervasyon bulunamadı');
        }

        const isPassenger = booking.passengerId === senderId;
        const isDriver = booking.trip.driverId === senderId;

        if (!isPassenger && !isDriver) {
            throw new ForbiddenException('Bu konuşmaya erişim yetkiniz yok');
        }

        const receiverId = isPassenger ? booking.trip.driverId : booking.passengerId;
        const receiverUser = isPassenger ? booking.trip.driver : booking.passenger;

        // Create message
        const message = await this.prisma.message.create({
            data: {
                id: uuid(),
                bookingId: dto.bookingId,
                senderId,
                receiverId,
                message: dto.message,
                read: false,
            },
            include: {
                sender: true,
            },
        });

        // Send push notification to receiver (best effort)
        try {
            const deviceTokens = this.extractDeviceTokens(receiverUser?.preferences);
            if (deviceTokens.length > 0) {
                await Promise.all(
                    deviceTokens.map((token) =>
                        this.fcmService.notifyNewMessage(token, message.sender.fullName, dto.message)
                    )
                );
            }
        } catch (error) {
            // Ignore notification errors
        }

        return this.mapToResponse(message);
    }

    async getConversations(userId: string): Promise<ConversationListDto> {
        // Get all bookings where user is participant
        const bookings = await this.prisma.booking.findMany({
            where: {
                OR: [
                    { passengerId: userId },
                    { trip: { driverId: userId } },
                ],
                status: { in: ['pending', 'confirmed', 'checked_in', 'completed'] },
            },
            include: {
                trip: {
                    include: { driver: true },
                },
                passenger: true,
                messages: {
                    orderBy: { createdAt: 'desc' },
                    take: 1,
                    include: { sender: true },
                },
            },
            orderBy: { updatedAt: 'desc' },
        });

        const conversations: ConversationDto[] = await Promise.all(
            bookings.map(async (booking) => {
                const isDriver = booking.trip.driverId === userId;
                const otherUser = isDriver ? booking.passenger : booking.trip.driver;

                const unreadCount = await this.prisma.message.count({
                    where: {
                        bookingId: booking.id,
                        receiverId: userId,
                        read: false,
                    },
                });

                return {
                    bookingId: booking.id,
                    tripInfo: {
                        departureCity: booking.trip.departureCity,
                        arrivalCity: booking.trip.arrivalCity,
                        departureTime: booking.trip.departureTime,
                    },
                    otherUser: {
                        id: otherUser.id,
                        fullName: otherUser.fullName,
                        profilePhotoUrl: otherUser.profilePhotoUrl || undefined,
                    },
                    lastMessage: booking.messages[0] ? this.mapToResponse(booking.messages[0]) : undefined,
                    unreadCount,
                    updatedAt: booking.messages[0]?.createdAt || booking.createdAt,
                };
            })
        );

        // Sort by last message time
        conversations.sort((a, b) => b.updatedAt.getTime() - a.updatedAt.getTime());

        return {
            conversations,
            total: conversations.length,
        };
    }

    async getMessages(userId: string, bookingId: string, page = 1, limit = 50): Promise<MessageListDto> {
        // Verify access
        const booking = await this.prisma.booking.findUnique({
            where: { id: bookingId },
            include: { trip: true },
        });

        if (!booking) {
            throw new NotFoundException('Rezervasyon bulunamadı');
        }

        const isParticipant = booking.passengerId === userId || booking.trip.driverId === userId;
        if (!isParticipant) {
            throw new ForbiddenException('Bu konuşmaya erişim yetkiniz yok');
        }

        const skip = (page - 1) * limit;

        const [messages, total] = await Promise.all([
            this.prisma.message.findMany({
                where: { bookingId },
                orderBy: { createdAt: 'desc' },
                skip,
                take: limit,
                include: { sender: true },
            }),
            this.prisma.message.count({ where: { bookingId } }),
        ]);

        // Mark messages as read
        await this.prisma.message.updateMany({
            where: {
                bookingId,
                receiverId: userId,
                read: false,
            },
            data: { read: true },
        });

        return {
            messages: messages.reverse().map(m => this.mapToResponse(m)),
            total,
            page,
            hasMore: skip + messages.length < total,
        };
    }

    async markAsRead(userId: string, bookingId: string): Promise<void> {
        await this.prisma.message.updateMany({
            where: {
                bookingId,
                receiverId: userId,
                read: false,
            },
            data: { read: true },
        });
    }

    async getUnreadCount(userId: string): Promise<number> {
        return this.prisma.message.count({
            where: {
                receiverId: userId,
                read: false,
            },
        });
    }

    private mapToResponse(message: any): MessageResponseDto {
        return {
            id: message.id,
            bookingId: message.bookingId,
            senderId: message.senderId,
            receiverId: message.receiverId,
            message: message.message,
            read: message.read,
            createdAt: message.createdAt,
            sender: message.sender ? {
                id: message.sender.id,
                fullName: message.sender.fullName,
                profilePhotoUrl: message.sender.profilePhotoUrl,
            } : undefined,
        };
    }

    private extractDeviceTokens(preferences: any): string[] {
        if (!preferences) return [];
        const parsed = typeof preferences === 'string'
            ? (() => {
                try {
                    return JSON.parse(preferences);
                } catch {
                    return {};
                }
            })()
            : preferences;

        const tokens = parsed?.deviceTokens;
        if (Array.isArray(tokens)) {
            return tokens.filter((t) => typeof t === 'string' && t.length > 0);
        }
        if (typeof parsed?.deviceToken === 'string' && parsed.deviceToken.length > 0) {
            return [parsed.deviceToken];
        }
        return [];
    }
}
