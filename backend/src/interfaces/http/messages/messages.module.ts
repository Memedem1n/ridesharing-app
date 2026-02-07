import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { MessagesController } from './messages.controller';
import { MessagesService } from '@application/services/messages/messages.service';
import { ChatGateway } from '@interfaces/websocket/chat.gateway';
import { PrismaService } from '@infrastructure/database/prisma.service';
import { NotificationsModule } from '@infrastructure/notifications/notifications.module';

@Module({
    imports: [
        NotificationsModule,
        JwtModule.registerAsync({
            imports: [ConfigModule],
            useFactory: async (configService: ConfigService) => ({
                secret: configService.get<string>('JWT_SECRET'),
            }),
            inject: [ConfigService],
        }),
    ],
    controllers: [MessagesController],
    providers: [
        MessagesService,
        ChatGateway,
        PrismaService,
    ],
    exports: [MessagesService, ChatGateway],
})
export class MessagesModule { }
