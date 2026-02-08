import { Injectable, Logger, OnModuleDestroy } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import Redis from 'ioredis';

@Injectable()
export class RedisService implements OnModuleDestroy {
    private readonly logger = new Logger(RedisService.name);
    private readonly client?: Redis;
    private readonly configured: boolean;

    constructor(private readonly configService: ConfigService) {
        const redisUrl = this.configService.get<string>('REDIS_URL');
        this.configured = Boolean(redisUrl);

        if (redisUrl) {
            this.client = new Redis(redisUrl, {
                maxRetriesPerRequest: 1,
                enableReadyCheck: true,
            });

            this.client.on('error', (err) => {
                this.logger.warn(`Redis error: ${err.message}`);
            });
        }
    }

    isConfigured(): boolean {
        return this.configured;
    }

    async ping(): Promise<boolean> {
        if (!this.client) return false;
        try {
            await this.client.ping();
            return true;
        } catch {
            return false;
        }
    }

    async get(key: string): Promise<string | null> {
        if (!this.client) return null;
        try {
            return await this.client.get(key);
        } catch {
            return null;
        }
    }

    async set(key: string, value: string, ttlSeconds?: number): Promise<void> {
        if (!this.client) return;
        try {
            if (ttlSeconds && ttlSeconds > 0) {
                await this.client.set(key, value, 'EX', ttlSeconds);
            } else {
                await this.client.set(key, value);
            }
        } catch {
            // Ignore cache errors
        }
    }

    async del(key: string): Promise<void> {
        if (!this.client) return;
        try {
            await this.client.del(key);
        } catch {
            // Ignore cache errors
        }
    }

    async delByPrefix(prefix: string): Promise<void> {
        if (!this.client) return;
        try {
            let cursor = '0';
            do {
                const [nextCursor, keys] = await this.client.scan(cursor, 'MATCH', `${prefix}*`, 'COUNT', 100);
                if (keys.length > 0) {
                    await this.client.del(...keys);
                }
                cursor = nextCursor;
            } while (cursor !== '0');
        } catch {
            // Ignore cache errors
        }
    }

    async getJson<T>(key: string): Promise<T | null> {
        const raw = await this.get(key);
        if (!raw) return null;
        try {
            return JSON.parse(raw) as T;
        } catch {
            return null;
        }
    }

    async setJson(key: string, value: unknown, ttlSeconds?: number): Promise<void> {
        await this.set(key, JSON.stringify(value), ttlSeconds);
    }

    async onModuleDestroy() {
        if (this.client) {
            await this.client.quit();
        }
    }
}
