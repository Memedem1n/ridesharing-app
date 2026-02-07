import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';
import * as admin from 'firebase-admin';

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
    private readonly useMock: boolean;
    private app?: admin.app.App;

    constructor(private configService: ConfigService) {
        this.projectId = this.configService.get('FIREBASE_PROJECT_ID') || '';
        this.useMock = this.configService.get('USE_MOCK_INTEGRATIONS') !== 'false';

        if (process.env.NODE_ENV === 'production' && this.useMock) {
            throw new Error('USE_MOCK_INTEGRATIONS must be false in production');
        }

        if (!this.useMock) {
            const clientEmail = this.configService.get('FIREBASE_CLIENT_EMAIL') || '';
            const privateKeyRaw = this.configService.get('FIREBASE_PRIVATE_KEY') || '';
            const privateKey = privateKeyRaw.replace(/\\n/g, '\n');

            if (!this.projectId || !clientEmail || !privateKey) {
                throw new Error('Missing Firebase configuration');
            }

            if (!admin.apps.length) {
                this.app = admin.initializeApp({
                    credential: admin.credential.cert({
                        projectId: this.projectId,
                        clientEmail,
                        privateKey,
                    }),
                });
            } else {
                this.app = admin.app();
            }
        }
    }

    async sendToDevice(deviceToken: string, payload: PushPayload): Promise<PushResult> {
        this.logger.log(`Sending push to device ${deviceToken.substring(0, 10)}...`);

        if (this.useMock) {
            return {
                success: true,
                messageId: `FCM_${Date.now()}`,
            };
        }
        try {
            const response = await this.app!.messaging().send({
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
        } catch (error: any) {
            return {
                success: false,
                errorMessage: error?.message || 'FCM send failed',
            };
        }
    }

    async sendToTopic(topic: string, payload: PushPayload): Promise<PushResult> {
        this.logger.log(`Sending push to topic ${topic}`);

        if (this.useMock) {
            return {
                success: true,
                messageId: `FCM_TOPIC_${Date.now()}`,
            };
        }
        try {
            const response = await this.app!.messaging().send({
                topic,
                notification: {
                    title: payload.title,
                    body: payload.body,
                    imageUrl: payload.imageUrl,
                },
                data: payload.data,
            });

            return {
                success: true,
                messageId: response,
            };
        } catch (error: any) {
            return {
                success: false,
                errorMessage: error?.message || 'FCM topic send failed',
            };
        }
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
            title: 'Rezervasyon onaylandı',
            body: `${tripInfo.from} › ${tripInfo.to} yolculuğunuz onaylandı.`,
            data: { type: 'booking_confirmed' },
        });
    }

    async notifyNewBookingRequest(deviceToken: string, passengerName: string, tripInfo: { from: string; to: string }): Promise<PushResult> {
        return this.sendToDevice(deviceToken, {
            title: 'Yeni rezervasyon',
            body: `${passengerName} ${tripInfo.from} › ${tripInfo.to} yolculuğunuz için rezervasyon yaptı.`,
            data: { type: 'new_booking' },
        });
    }

    async notifyTripStarting(deviceToken: string, minutesUntil: number): Promise<PushResult> {
        return this.sendToDevice(deviceToken, {
            title: 'Yolculuk yaklaşıyor',
            body: `Yolculuğunuz ${minutesUntil} dakika sonra başlayacak.`,
            data: { type: 'trip_reminder' },
        });
    }

    async notifyCancellation(deviceToken: string, cancelledBy: 'driver' | 'passenger'): Promise<PushResult> {
        return this.sendToDevice(deviceToken, {
            title: 'Rezervasyon iptal edildi',
            body: cancelledBy === 'driver'
                ? 'Sürücü yolculuğu iptal etti. İade işleminiz başlatıldı.'
                : 'Yolcu rezervasyonunu iptal etti.',
            data: { type: 'cancellation' },
        });
    }

    async notifyTripUpdated(deviceToken: string, tripInfo: { from: string; to: string; tripId?: string }): Promise<PushResult> {
        return this.sendToDevice(deviceToken, {
            title: 'Yolculuk güncellendi',
            body: `${tripInfo.from} › ${tripInfo.to} yolculuğunuz güncellendi. Detayları kontrol edin.`,
            data: { type: 'trip_updated', ...(tripInfo.tripId ? { tripId: tripInfo.tripId } : {}) },
        });
    }

    async notifyTripCancelled(deviceToken: string, tripInfo: { from: string; to: string; tripId?: string }): Promise<PushResult> {
        return this.sendToDevice(deviceToken, {
            title: 'Yolculuk iptal edildi',
            body: `${tripInfo.from} › ${tripInfo.to} yolculuğu iptal edildi.`,
            data: { type: 'trip_cancelled', ...(tripInfo.tripId ? { tripId: tripInfo.tripId } : {}) },
        });
    }
}

