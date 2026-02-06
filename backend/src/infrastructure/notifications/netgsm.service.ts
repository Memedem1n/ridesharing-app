import { Injectable, Logger } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

export interface SmsResult {
    success: boolean;
    messageId?: string;
    errorMessage?: string;
}

@Injectable()
export class NetgsmService {
    private readonly logger = new Logger(NetgsmService.name);
    private readonly username: string;
    private readonly password: string;
    private readonly header: string;
    private readonly useMock: boolean;

    constructor(private configService: ConfigService) {
        this.username = this.configService.get('NETGSM_USERNAME') || '';
        this.password = this.configService.get('NETGSM_PASSWORD') || '';
        this.header = this.configService.get('NETGSM_HEADER') || 'RIDESHARE';
        this.useMock = this.configService.get('USE_MOCK_INTEGRATIONS') !== 'false';

        if (process.env.NODE_ENV === 'production' && this.useMock) {
            throw new Error('USE_MOCK_INTEGRATIONS must be false in production');
        }

        if (!this.useMock && (!this.username || !this.password)) {
            throw new Error('Missing Netgsm credentials');
        }
    }

    async sendSms(phone: string, message: string): Promise<SmsResult> {
        this.logger.log(`Sending SMS to ${phone.substring(0, 5)}***`);

        // TODO: Implement actual Netgsm API call
        /*
        const axios = require('axios');
        
        const params = new URLSearchParams({
          usercode: this.username,
          password: this.password,
          gsmno: phone.replace('+90', ''),
          message: message,
          msgheader: this.header,
          dil: 'TR',
        });
    
        try {
          const response = await axios.get(
            `https://api.netgsm.com.tr/sms/send/get?${params.toString()}`
          );
          
          const code = response.data.split(' ')[0];
          if (code === '00' || code === '01' || code === '02') {
            return {
              success: true,
              messageId: response.data.split(' ')[1],
            };
          } else {
            return {
              success: false,
              errorMessage: `Netgsm error code: ${code}`,
            };
          }
        } catch (error) {
          return {
            success: false,
            errorMessage: error.message,
          };
        }
        */

        if (this.useMock) {
            return {
                success: true,
                messageId: `SMS_${Date.now()}`,
            };
        }

        throw new Error('Netgsm integration is not implemented');
    }

    async sendOtp(phone: string, code: string): Promise<SmsResult> {
        const message = `Doğrulama kodunuz: ${code}. Bu kodu kimseyle paylaşmayın.`;
        return this.sendSms(phone, message);
    }

    async sendBookingConfirmation(phone: string, tripInfo: {
        from: string;
        to: string;
        date: string;
        qrCode: string;
    }): Promise<SmsResult> {
        const message = `Rezervasyonunuz onaylandı! ${tripInfo.from} → ${tripInfo.to}, ${tripInfo.date}. QR Kod: ${tripInfo.qrCode}`;
        return this.sendSms(phone, message);
    }

    async sendTripReminder(phone: string, tripInfo: {
        from: string;
        to: string;
        time: string;
        driver: string;
    }): Promise<SmsResult> {
        const message = `Hatırlatma: Yarın ${tripInfo.time}'de ${tripInfo.from} → ${tripInfo.to} yolculuğunuz var. Sürücü: ${tripInfo.driver}`;
        return this.sendSms(phone, message);
    }

    async sendCancellationNotice(phone: string, refundAmount: number): Promise<SmsResult> {
        const message = refundAmount > 0
            ? `Rezervasyonunuz iptal edildi. ₺${refundAmount} tutarında iade yapılacaktır.`
            : `Rezervasyonunuz iptal edildi.`;
        return this.sendSms(phone, message);
    }
}
