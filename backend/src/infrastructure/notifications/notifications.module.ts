import { Module } from '@nestjs/common';
import { FcmService } from './fcm.service';
import { NetgsmService } from './netgsm.service';

@Module({
    providers: [FcmService, NetgsmService],
    exports: [FcmService, NetgsmService],
})
export class NotificationsModule { }
