import { CanActivate, ExecutionContext, Injectable, UnauthorizedException } from '@nestjs/common';
import { ConfigService } from '@nestjs/config';

@Injectable()
export class AdminKeyGuard implements CanActivate {
    constructor(private readonly configService: ConfigService) { }

    canActivate(context: ExecutionContext): boolean {
        const request = context.switchToHttp().getRequest();
        const header = request.headers?.['x-admin-key'];
        const provided = Array.isArray(header) ? header[0] : header;
        const expected = this.configService.get<string>('ADMIN_API_KEY');

        if (!expected) {
            throw new UnauthorizedException('ADMIN_API_KEY is not configured');
        }

        if (!provided || provided !== expected) {
            throw new UnauthorizedException('Invalid admin key');
        }

        return true;
    }
}
