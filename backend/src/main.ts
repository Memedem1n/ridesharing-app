import { NestFactory } from '@nestjs/core';
import { ValidationPipe, Logger } from '@nestjs/common';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import { existsSync } from 'fs';
import { join } from 'path';
import helmet from 'helmet';
import { AppModule } from './app.module';
import { GlobalExceptionFilter } from './interfaces/http/filters/global-exception.filter';
import { LoggingInterceptor } from './interfaces/http/interceptors/logging.interceptor';

function isLanOrLocalOrigin(origin: string): boolean {
    try {
        const parsed = new URL(origin);
        const { protocol, hostname } = parsed;

        if (protocol !== 'http:' && protocol !== 'https:') {
            return false;
        }

        if (hostname === 'localhost' || hostname === '127.0.0.1' || hostname === '::1') {
            return true;
        }

        const octets = hostname.split('.');
        if (octets.length !== 4) {
            return false;
        }
        const nums = octets.map((part) => Number(part));
        if (nums.some((n) => Number.isNaN(n) || n < 0 || n > 255)) {
            return false;
        }

        // Private IPv4 ranges: 10/8, 172.16/12, 192.168/16
        if (nums[0] === 10) return true;
        if (nums[0] === 172 && nums[1] >= 16 && nums[1] <= 31) return true;
        if (nums[0] === 192 && nums[1] === 168) return true;

        return false;
    } catch {
        return false;
    }
}

async function bootstrap() {
    const logger = new Logger('Bootstrap');
    const app = await NestFactory.create(AppModule);
    const allowedOrigins = process.env.ALLOWED_ORIGINS?.split(',')
        .map((origin) => origin.trim())
        .filter((origin) => origin.length > 0) || [
            'http://localhost:3000',
            'http://localhost:5173',
            'http://127.0.0.1:5173',
        ];

    // Security
    app.use(helmet({
        contentSecurityPolicy: process.env.NODE_ENV === 'production' ? undefined : false,
    }));

    // CORS
    app.enableCors({
        origin: (origin, callback) => {
            // Allow non-browser clients and same-origin server-to-server calls.
            if (!origin) {
                callback(null, true);
                return;
            }
            if (allowedOrigins.includes(origin) || isLanOrLocalOrigin(origin)) {
                callback(null, true);
                return;
            }
            callback(new Error(`CORS blocked for origin: ${origin}`), false);
        },
        credentials: true,
        methods: ['GET', 'POST', 'PUT', 'DELETE', 'PATCH', 'OPTIONS'],
        allowedHeaders: ['Content-Type', 'Authorization', 'X-Requested-With'],
    });

    // Global validation
    app.useGlobalPipes(
        new ValidationPipe({
            whitelist: true,
            forbidNonWhitelisted: true,
            transform: true,
            transformOptions: {
                enableImplicitConversion: true,
            },
        }),
    );

    // Global exception filter
    app.useGlobalFilters(new GlobalExceptionFilter());

    // Global logging interceptor
    app.useGlobalInterceptors(new LoggingInterceptor());

    // API prefix
    app.setGlobalPrefix('v1');

    // Swagger documentation
    if (process.env.NODE_ENV !== 'production') {
        const config = new DocumentBuilder()
            .setTitle('Paylaşımlı Yolculuk API')
            .setDescription(`
        REST API for ride-sharing platform.
        
        ## Features
        - 👥 User authentication & verification
        - 🚗 Trip management & search
        - 📦 Booking with QR check-in
        - 💳 İyzico payment integration
        - 💬 Real-time messaging (WebSocket)
        - 🔔 Push & SMS notifications
      `)
            .setVersion('1.0')
            .addBearerAuth({
                type: 'http',
                scheme: 'bearer',
                bearerFormat: 'JWT',
            })
            .addTag('Authentication', 'User registration and login')
            .addTag('Users', 'User profile management')
            .addTag('Vehicles', 'Vehicle CRUD operations')
            .addTag('Trips', 'Trip creation and search')
            .addTag('Bookings', 'Booking and payment')
            .addTag('Messages', 'Chat messaging')
            .addTag('Health', 'Health checks')
            .build();

        const document = SwaggerModule.createDocument(app, config);
        SwaggerModule.setup('api/docs', app, document, {
            swaggerOptions: {
                persistAuthorization: true,
            },
        });

        logger.log('Swagger UI available at /api/docs');
    }

    // Flutter web SPA fallback (when served via ServeStaticModule).
    // Supports deep-links like `/login` or `/search` on hard refresh.
    const webIndexPath = join(process.cwd(), '..', 'mobile', 'build', 'web', 'index.html');
    if (existsSync(webIndexPath)) {
        app.use((req: any, res: any, next: any) => {
            if (req.method !== 'GET') return next();
            const path: string = req.path ?? '';
            if (
                path.startsWith('/v1') ||
                path.startsWith('/api') ||
                path.startsWith('/uploads') ||
                path.startsWith('/socket.io')
            ) {
                return next();
            }

            // Let asset files fall through to static middleware (or 404).
            if (path.includes('.')) return next();

            res.sendFile(webIndexPath);
        });
        logger.log('Flutter web SPA fallback enabled (mobile/build/web)');
    }

    const port = process.env.PORT || 3000;
    await app.listen(port);

    logger.log(`🚀 Server running on http://localhost:${port}`);
    logger.log(`📚 API Docs: http://localhost:${port}/api/docs`);
    logger.log(`❤️ Health: http://localhost:${port}/v1/health`);
}

bootstrap();
