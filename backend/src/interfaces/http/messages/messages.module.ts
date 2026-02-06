import { Module } from '@nestjs/common';
import { JwtModule } from '@nestjs/jwt';
import { ConfigModule, ConfigService } from '@nestjs/config';
import { MessagesController } from './messages.controller';
import { MessagesService } from '@application/services/messages/messages.service';
import { ChatGateway } from '@interfaces/websocket/chat.gateway';
import { FcmService } from '@infrastructure/notifications/fcm.service';
import { NetgsmService } from '@infrastructure/notifications/netgsm.service';
import { PrismaService } from '@infrastructure/database/prisma.service';

@Module({
    imports: [
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
        FcmService,
        NetgsmService,
        PrismaService,
    ],
    exports: [MessagesService, ChatGateway, FcmService, NetgsmService],
})
export class MessagesModule { }
