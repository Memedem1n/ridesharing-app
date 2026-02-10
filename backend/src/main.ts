import { NestFactory } from '@nestjs/core';
import { ValidationPipe, Logger } from '@nestjs/common';
import { SwaggerModule, DocumentBuilder } from '@nestjs/swagger';
import helmet from 'helmet';
import { AppModule } from './app.module';
import { GlobalExceptionFilter } from './interfaces/http/filters/global-exception.filter';
import { LoggingInterceptor } from './interfaces/http/interceptors/logging.interceptor';

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
        origin: allowedOrigins,
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

    const port = process.env.PORT || 3000;
    await app.listen(port);

    logger.log(`🚀 Server running on http://localhost:${port}`);
    logger.log(`📚 API Docs: http://localhost:${port}/api/docs`);
    logger.log(`❤️ Health: http://localhost:${port}/v1/health`);
}

bootstrap();
