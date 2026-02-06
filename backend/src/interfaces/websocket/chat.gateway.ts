import {
    WebSocketGateway,
    WebSocketServer,
    SubscribeMessage,
    OnGatewayConnection,
    OnGatewayDisconnect,
    ConnectedSocket,
    MessageBody,
} from '@nestjs/websockets';
import { Server, Socket } from 'socket.io';
import { Logger, UseGuards } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { MessagesService } from '@application/services/messages/messages.service';

interface AuthenticatedSocket extends Socket {
    userId?: string;
}

@WebSocketGateway({
    cors: {
        origin: '*',
    },
    namespace: '/chat',
})
export class ChatGateway implements OnGatewayConnection, OnGatewayDisconnect {
    @WebSocketServer()
    server: Server;

    private readonly logger = new Logger(ChatGateway.name);
    private userSockets: Map<string, string[]> = new Map(); // userId -> socketIds

    constructor(
        private readonly messagesService: MessagesService,
        private readonly jwtService: JwtService,
    ) { }

    async handleConnection(client: AuthenticatedSocket) {
        try {
            // Authenticate via token
            const token = client.handshake.auth.token || client.handshake.query.token;

            if (!token) {
                client.disconnect();
                return;
            }

            const payload = await this.jwtService.verifyAsync(token as string);
            client.userId = payload.sub;

            // Track socket
            const userSockets = this.userSockets.get(payload.sub) || [];
            userSockets.push(client.id);
            this.userSockets.set(payload.sub, userSockets);

            // Join user's room
            client.join(`user:${payload.sub}`);

            this.logger.log(`User ${payload.sub} connected (socket: ${client.id})`);
        } catch (error) {
            this.logger.error('WebSocket auth failed:', error);
            client.disconnect();
        }
    }

    handleDisconnect(client: AuthenticatedSocket) {
        if (client.userId) {
            const userSockets = this.userSockets.get(client.userId) || [];
            const filtered = userSockets.filter(id => id !== client.id);

            if (filtered.length === 0) {
                this.userSockets.delete(client.userId);
            } else {
                this.userSockets.set(client.userId, filtered);
            }

            this.logger.log(`User ${client.userId} disconnected (socket: ${client.id})`);
        }
    }

    @SubscribeMessage('join_conversation')
    async handleJoinConversation(
        @ConnectedSocket() client: AuthenticatedSocket,
        @MessageBody() data: { bookingId: string },
    ) {
        client.join(`booking:${data.bookingId}`);
        this.logger.log(`User ${client.userId} joined conversation ${data.bookingId}`);
    }

    @SubscribeMessage('leave_conversation')
    async handleLeaveConversation(
        @ConnectedSocket() client: AuthenticatedSocket,
        @MessageBody() data: { bookingId: string },
    ) {
        client.leave(`booking:${data.bookingId}`);
    }

    @SubscribeMessage('send_message')
    async handleSendMessage(
        @ConnectedSocket() client: AuthenticatedSocket,
        @MessageBody() data: { bookingId: string; message: string },
    ) {
        if (!client.userId) return;

        try {
            const message = await this.messagesService.sendMessage(client.userId, {
                bookingId: data.bookingId,
                message: data.message,
            });

            // Emit to all participants in the conversation
            this.server.to(`booking:${data.bookingId}`).emit('new_message', message);

            // Also emit to the receiver's user room (for notification badge)
            this.server.to(`user:${message.receiverId}`).emit('message_received', {
                bookingId: data.bookingId,
                preview: data.message.substring(0, 50),
            });

            return { success: true, message };
        } catch (error) {
            return { success: false, error: error.message };
        }
    }

    @SubscribeMessage('typing')
    async handleTyping(
        @ConnectedSocket() client: AuthenticatedSocket,
        @MessageBody() data: { bookingId: string; isTyping: boolean },
    ) {
        // Broadcast typing status to other participants
        client.to(`booking:${data.bookingId}`).emit('user_typing', {
            userId: client.userId,
            isTyping: data.isTyping,
        });
    }

    @SubscribeMessage('mark_read')
    async handleMarkRead(
        @ConnectedSocket() client: AuthenticatedSocket,
        @MessageBody() data: { bookingId: string },
    ) {
        if (!client.userId) return;

        await this.messagesService.markAsRead(client.userId, data.bookingId);

        // Notify sender that messages were read
        this.server.to(`booking:${data.bookingId}`).emit('messages_read', {
            bookingId: data.bookingId,
            readBy: client.userId,
        });
    }

    // Utility method to send real-time notifications from other services
    sendToUser(userId: string, event: string, data: any) {
        this.server.to(`user:${userId}`).emit(event, data);
    }

    isUserOnline(userId: string): boolean {
        return this.userSockets.has(userId);
    }
}
