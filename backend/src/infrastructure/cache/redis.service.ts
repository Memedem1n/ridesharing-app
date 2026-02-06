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

    async onModuleDestroy() {
        if (this.client) {
            await this.client.quit();
        }
    }
}
