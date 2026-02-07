import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { PassportModule } from '@nestjs/passport';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { AuthController } from './auth.controller';
import { AuthService } from '@application/services/auth/auth.service';
import { JwtStrategy } from './strategies/jwt.strategy';
import { PrismaService } from '@infrastructure/database/prisma.service';
import { NotificationsModule } from '@infrastructure/notifications/notifications.module';
import { CacheModule } from '@infrastructure/cache/cache.module';

@Module({
    imports: [
        CacheModule,
        NotificationsModule,
        PassportModule.register({ defaultStrategy: 'jwt' }),
        JwtModule.registerAsync({
            imports: [ConfigModule],
            useFactory: async (configService: ConfigService) => ({
                secret: configService.get<string>('JWT_SECRET'),
                signOptions: {
                    expiresIn: configService.get<string>('JWT_ACCESS_EXPIRY') || '15m',
                },
            }),
            inject: [ConfigService],
        }),
    ],
    controllers: [AuthController],
    providers: [AuthService, JwtStrategy, PrismaService],
    exports: [AuthService, JwtStrategy],
})
export class AuthModule { }
