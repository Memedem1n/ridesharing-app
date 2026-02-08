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
import { Logger } from '@nestjs/common';
import { JwtService } from '@nestjs/jwt';
import { PrismaService } from '@infrastructure/database/prisma.service';
import { RedisService } from '@infrastructure/cache/redis.service';
import { ConfigService } from '@nestjs/config';

interface AuthenticatedSocket extends Socket {
    userId?: string;
}

interface LocationSnapshot {
    tripId: string;
    driverId: string;
    lat: number;
    lng: number;
    speed?: number;
    heading?: number;
    timestamp: string;
}

@WebSocketGateway({
    cors: {
        origin: '*',
    },
    namespace: '/location',
})
export class LocationGateway implements OnGatewayConnection, OnGatewayDisconnect {
    @WebSocketServer()
    server: Server;

    private readonly logger = new Logger(LocationGateway.name);
    private readonly redisKeyPrefix = 'trip:location:';
    private readonly ttlSeconds: number;
    private memoryCache = new Map<string, { snapshot: LocationSnapshot; expiresAt: number }>();

    constructor(
        private readonly prisma: PrismaService,
        private readonly jwtService: JwtService,
        private readonly redisService: RedisService,
        private readonly configService: ConfigService,
    ) {
        this.ttlSeconds = Number(this.configService.get('TRIP_LOCATION_TTL_SECONDS') || 600);
    }

    async handleConnection(client: AuthenticatedSocket) {
        try {
            const token = this.extractToken(client);
            if (!token) {
                this.logger.warn('Location socket rejected: missing token');
                client.disconnect(true);
                return;
            }

            const payload = await this.jwtService.verifyAsync(token);
            if (!payload?.sub) {
                this.logger.warn('Location socket rejected: invalid token');
                client.disconnect(true);
                return;
            }
            client.userId = payload.sub;

            this.logger.log(`Location socket connected: ${payload.sub}`);
        } catch (error) {
            this.logger.error('Location socket auth failed:', error);
            client.disconnect(true);
        }
    }

    handleDisconnect(client: AuthenticatedSocket) {
        if (client.userId) {
            this.logger.log(`Location socket disconnected: ${client.userId}`);
        }
    }

    @SubscribeMessage('join_trip')
    async handleJoinTrip(
        @ConnectedSocket() client: AuthenticatedSocket,
        @MessageBody() data: { tripId: string },
    ) {
        if (!client.userId || !data?.tripId) return { success: false };

        const allowed = await this.canAccessTrip(client.userId, data.tripId);
        if (!allowed) {
            return { success: false, error: 'not_allowed' };
        }

        client.join(`trip:${data.tripId}`);

        const snapshot = await this.getLastLocation(data.tripId);
        if (snapshot) {
            client.emit('location_update', snapshot);
        }

        return { success: true };
    }

    @SubscribeMessage('leave_trip')
    handleLeaveTrip(
        @ConnectedSocket() client: AuthenticatedSocket,
        @MessageBody() data: { tripId: string },
    ) {
        if (!data?.tripId) return;
        client.leave(`trip:${data.tripId}`);
    }

    @SubscribeMessage('driver_location_update')
    async handleDriverLocationUpdate(
        @ConnectedSocket() client: AuthenticatedSocket,
        @MessageBody() data: { tripId: string; lat: number; lng: number; speed?: number; heading?: number },
    ) {
        if (!client.userId || !data?.tripId) return { success: false };

        const trip = await this.prisma.trip.findUnique({
            where: { id: data.tripId },
            select: { driverId: true },
        });

        if (!trip || trip.driverId !== client.userId) {
            return { success: false, error: 'not_driver' };
        }

        const snapshot: LocationSnapshot = {
            tripId: data.tripId,
            driverId: client.userId,
            lat: data.lat,
            lng: data.lng,
            speed: data.speed,
            heading: data.heading,
            timestamp: new Date().toISOString(),
        };

        await this.setLastLocation(data.tripId, snapshot);
        this.server.to(`trip:${data.tripId}`).emit('location_update', snapshot);

        return { success: true };
    }

    private async canAccessTrip(userId: string, tripId: string): Promise<boolean> {
        const trip = await this.prisma.trip.findUnique({
            where: { id: tripId },
            select: { driverId: true },
        });

        if (!trip) return false;
        if (trip.driverId === userId) return true;

        const booking = await this.prisma.booking.findFirst({
            where: {
                tripId,
                passengerId: userId,
                status: { in: ['confirmed', 'checked_in', 'completed', 'disputed'] },
            },
            select: { id: true },
        });

        return Boolean(booking);
    }

    private async getLastLocation(tripId: string): Promise<LocationSnapshot | null> {
        if (this.redisService.isConfigured()) {
            return this.redisService.getJson<LocationSnapshot>(this.redisKeyPrefix + tripId);
        }

        const cached = this.memoryCache.get(tripId);
        if (!cached) return null;
        if (cached.expiresAt < Date.now()) {
            this.memoryCache.delete(tripId);
            return null;
        }
        return cached.snapshot;
    }

    private async setLastLocation(tripId: string, snapshot: LocationSnapshot): Promise<void> {
        if (this.redisService.isConfigured()) {
            await this.redisService.setJson(this.redisKeyPrefix + tripId, snapshot, this.ttlSeconds);
            return;
        }
        this.memoryCache.set(tripId, {
            snapshot,
            expiresAt: Date.now() + this.ttlSeconds * 1000,
        });
    }

    private extractToken(client: AuthenticatedSocket): string | null {
        const authToken = client.handshake.auth?.token;
        const queryToken = client.handshake.query?.token;
        const header = client.handshake.headers?.authorization;

        const raw = typeof authToken === 'string'
            ? authToken
            : typeof queryToken === 'string'
                ? queryToken
                : Array.isArray(header)
                    ? header[0]
                    : typeof header === 'string'
                        ? header
                        : null;

        if (!raw) return null;
        return raw.startsWith('Bearer ') ? raw.slice(7) : raw;
    }
}

