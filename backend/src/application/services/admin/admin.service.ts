import { Injectable, NotFoundException } from '@nestjs/common';
import { PrismaService } from '@infrastructure/database/prisma.service';
import { BusPriceScraperService } from '@infrastructure/scraper/bus-price-scraper.service';

@Injectable()
export class AdminService {
    constructor(
        private readonly prisma: PrismaService,
        private readonly busPriceScraper: BusPriceScraperService,
    ) { }

    async listVerifications(status?: 'pending' | 'verified' | 'rejected') {
        const where = status
            ? {
                OR: [
                    { identityStatus: status },
                    { licenseStatus: status },
                    { criminalRecordStatus: status },
                ],
            }
            : undefined;

        const users = await this.prisma.user.findMany({
            where,
            select: {
                id: true,
                fullName: true,
                phone: true,
                email: true,
                identityStatus: true,
                licenseStatus: true,
                criminalRecordStatus: true,
                identityDocumentUrl: true,
                licenseDocumentUrl: true,
                criminalRecordDocumentUrl: true,
                verified: true,
                createdAt: true,
            },
            orderBy: { createdAt: 'desc' },
        });

        return users;
    }

    async updateVerification(
        userId: string,
        type: 'identity' | 'license' | 'criminal-record',
        status: 'pending' | 'verified' | 'rejected',
    ) {
        const data: Record<string, string> = {};
        if (type === 'identity') {
            data.identityStatus = status;
        } else if (type === 'license') {
            data.licenseStatus = status;
        } else {
            data.criminalRecordStatus = status;
        }

        const updated = await this.prisma.user.update({
            where: { id: userId },
            data,
            select: {
                id: true,
                identityStatus: true,
                licenseStatus: true,
                criminalRecordStatus: true,
                verified: true,
            },
        }).catch(() => null);

        if (!updated) {
            throw new NotFoundException('User not found');
        }

        const verified = this.computeVerified(updated);
        if (verified !== updated.verified) {
            await this.prisma.user.update({
                where: { id: userId },
                data: { verified },
            });
        }

        return { ...updated, verified };
    }

    async setBusPrice(from: string, to: string, price: number, source?: string) {
        await this.busPriceScraper.setPrice(from, to, price, source || 'manual');
        return { from, to, price, source: source || 'manual' };
    }

    async listBusPrices() {
        return this.busPriceScraper.getAllPrices();
    }

    private computeVerified(user: {
        identityStatus: string;
        licenseStatus: string;
        criminalRecordStatus: string;
    }) {
        return user.identityStatus === 'verified'
            && user.licenseStatus === 'verified'
            && user.criminalRecordStatus === 'verified';
    }
}
