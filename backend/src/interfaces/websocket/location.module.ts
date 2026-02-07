import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { PrismaService } from '@infrastructure/database/prisma.service';
import { LocationGateway } from './location.gateway';
import { CacheModule } from '@infrastructure/cache/cache.module';

@Module({
    imports: [
        CacheModule,
        JwtModule.registerAsync({
            imports: [ConfigModule],
            useFactory: async (configService: ConfigService) => ({
                secret: configService.get<string>('JWT_SECRET'),
            }),
            inject: [ConfigService],
        }),
    ],
    providers: [LocationGateway, PrismaService],
    exports: [LocationGateway],
})
export class LocationModule { }
