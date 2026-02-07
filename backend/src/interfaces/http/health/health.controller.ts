import { Controller, Get } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';
import { PrismaService } from '@infrastructure/database/prisma.service';
import { RedisService } from '@infrastructure/cache/redis.service';

@ApiTags('Health')
@Controller()
export class HealthController {
    constructor(
        private readonly prisma: PrismaService,
        private readonly redisService: RedisService,
    ) { }

    @Get('health')
    @ApiOperation({ summary: 'Health check' })
    async health() {
        return this.buildStatus();
    }

    @Get('ready')
    @ApiOperation({ summary: 'Readiness check' })
    async ready() {
        return this.buildStatus();
    }

    private async buildStatus() {
        const [dbOk, redisOk] = await Promise.all([
            this.checkDatabase(),
            this.checkRedis(),
        ]);

        const redisStatus = this.redisService.isConfigured()
            ? (redisOk ? 'connected' : 'down')
            : 'not_configured';

        return {
            status: dbOk && (redisStatus === 'connected' || redisStatus === 'not_configured')
                ? 'ok'
                : 'degraded',
            timestamp: new Date().toISOString(),
            uptime: process.uptime(),
            checks: {
                database: dbOk ? 'connected' : 'down',
                redis: redisStatus,
            },
        };
    }

    private async checkDatabase(): Promise<boolean> {
        try {
            await this.prisma.$queryRaw`SELECT 1`;
            return true;
        } catch {
            return false;
        }
    }

    private async checkRedis(): Promise<boolean> {
        if (!this.redisService.isConfigured()) return false;
        return this.redisService.ping();
    }
}
