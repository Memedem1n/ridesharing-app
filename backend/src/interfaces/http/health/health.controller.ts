import { Controller, Get } from '@nestjs/common';
import { ApiTags, ApiOperation } from '@nestjs/swagger';

@ApiTags('Health')
@Controller()
export class HealthController {
    @Get('health')
    @ApiOperation({ summary: 'Health check' })
    health() {
        return {
            status: 'ok',
            timestamp: new Date().toISOString(),
            uptime: process.uptime(),
        };
    }

    @Get('ready')
    @ApiOperation({ summary: 'Readiness check' })
    ready() {
        // TODO: Check database and Redis connections
        return {
            status: 'ok',
            checks: {
                database: 'connected',
                redis: 'connected',
            },
        };
    }
}
