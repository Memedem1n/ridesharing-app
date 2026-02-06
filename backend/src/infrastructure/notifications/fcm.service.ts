import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

export interface PushResult {
    success: boolean;
    messageId?: string;
    errorMessage?: string;
}

export interface PushPayload {
    title: string;
    body: string;
    data?: Record<string, string>;
    imageUrl?: string;
}

@Injectable()
export class FcmService {
    private readonly logger = new Logger(FcmService.name);
    private readonly projectId: string;

    constructor(private configService: ConfigService) {
        this.projectId = this.configService.get('FIREBASE_PROJECT_ID') || '';
    }

    async sendToDevice(deviceToken: string, payload: PushPayload): Promise<PushResult> {
        this.logger.log(`Sending push to device ${deviceToken.substring(0, 10)}...`);

        // TODO: Implement actual FCM API call
        /*
        const admin = require('firebase-admin');
        
        if (!admin.apps.length) {
          admin.initializeApp({
            credential: admin.credential.cert({
              projectId: this.configService.get('FIREBASE_PROJECT_ID'),
              clientEmail: this.configService.get('FIREBASE_CLIENT_EMAIL'),
              privateKey: this.configService.get('FIREBASE_PRIVATE_KEY')?.replace(/\\n/g, '\n'),
            }),
          });
        }
    
        try {
          const response = await admin.messaging().send({
            token: deviceToken,
            notification: {
              title: payload.title,
              body: payload.body,
              imageUrl: payload.imageUrl,
            },
            data: payload.data,
            android: {
              priority: 'high',
              notification: {
                channelId: 'ridesharing',
                priority: 'high',
              },
            },
            apns: {
              payload: {
                aps: {
                  sound: 'default',
                  badge: 1,
                },
              },
            },
          });
    
          return {
            success: true,
            messageId: response,
          };
        } catch (error) {
          return {
            success: false,
            errorMessage: error.message,
          };
        }
        */

        // Mock implementation
        return {
            success: true,
            messageId: `FCM_${Date.now()}`,
        };
    }

    async sendToTopic(topic: string, payload: PushPayload): Promise<PushResult> {
        this.logger.log(`Sending push to topic ${topic}`);

        // TODO: Implement topic-based messaging
        return {
            success: true,
            messageId: `FCM_TOPIC_${Date.now()}`,
        };
    }

    // Pre-built notification templates
    async notifyNewMessage(deviceToken: string, senderName: string, preview: string): Promise<PushResult> {
        return this.sendToDevice(deviceToken, {
            title: `${senderName} mesaj gönderdi`,
            body: preview.length > 50 ? preview.substring(0, 50) + '...' : preview,
            data: { type: 'message' },
        });
    }

    async notifyBookingConfirmed(deviceToken: string, tripInfo: { from: string; to: string }): Promise<PushResult> {
        return this.sendToDevice(deviceToken, {
            title: 'Rezervasyon Onaylandı! ✅',
            body: `${tripInfo.from} → ${tripInfo.to} yolculuğunuz onaylandı.`,
            data: { type: 'booking_confirmed' },
        });
    }

    async notifyNewBookingRequest(deviceToken: string, passengerName: string, tripInfo: { from: string; to: string }): Promise<PushResult> {
        return this.sendToDevice(deviceToken, {
            title: 'Yeni Rezervasyon! 🚗',
            body: `${passengerName} ${tripInfo.from} → ${tripInfo.to} yolculuğunuz için rezervasyon yaptı.`,
            data: { type: 'new_booking' },
        });
    }

    async notifyTripStarting(deviceToken: string, minutesUntil: number): Promise<PushResult> {
        return this.sendToDevice(deviceToken, {
            title: 'Yolculuk Yaklaşıyor! ⏰',
            body: `Yolculuğunuz ${minutesUntil} dakika sonra başlayacak.`,
            data: { type: 'trip_reminder' },
        });
    }

    async notifyCancellation(deviceToken: string, cancelledBy: 'driver' | 'passenger'): Promise<PushResult> {
        return this.sendToDevice(deviceToken, {
            title: 'Rezervasyon İptal Edildi',
            body: cancelledBy === 'driver'
                ? 'Sürücü yolculuğu iptal etti. İade işleminiz başlatıldı.'
                : 'Yolcu rezervasyonunu iptal etti.',
            data: { type: 'cancellation' },
        });
    }
}
