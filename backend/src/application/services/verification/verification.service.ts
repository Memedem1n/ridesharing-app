import { Injectable } from '@nestjs/common';
import { PrismaService } from '@infrastructure/database/prisma.service';
import { OcrService } from '@infrastructure/ocr/ocr.service';

export type VerificationType = 'identity' | 'license' | 'criminal-record';

export interface OcrVerificationResult {
    status: 'verified' | 'pending' | 'rejected';
    score: number;
    matches: {
        idNumberValid?: boolean;
        name?: boolean;
        dateOfBirth?: boolean;
        keywords?: boolean;
        licenseExpiryValid?: boolean;
        recordClean?: boolean;
    };
    extracted: {
        idNumber?: string;
        dateOfBirth?: string;
        licenseExpiry?: string;
        licenseClasses?: string[];
    };
    issues: string[];
}

@Injectable()
export class VerificationService {
    constructor(
        private readonly prisma: PrismaService,
        private readonly ocrService: OcrService,
    ) { }

    async verifyIdentity(userId: string, filePath: string, fileUrl: string): Promise<OcrVerificationResult> {
        const user = await this.prisma.user.findUnique({ where: { id: userId } });
        const text = await this.ocrService.extractText(filePath);
        const result = this.evaluateIdentity(text, user?.fullName, user?.dateOfBirth);

        await this.prisma.user.update({
            where: { id: userId },
            data: {
                identityDocumentUrl: fileUrl,
                identityStatus: result.status,
            },
        });

        await this.updateVerifiedStatus(userId);
        return result;
    }

    async verifyLicense(userId: string, filePaths: string[], fileUrl: string): Promise<OcrVerificationResult> {
        const user = await this.prisma.user.findUnique({ where: { id: userId } });
        const texts = await Promise.all(filePaths.map((path) => this.ocrService.extractText(path)));
        const text = texts.join(' ');
        const result = this.evaluateLicense(text, user?.fullName, user?.dateOfBirth);

        await this.prisma.user.update({
            where: { id: userId },
            data: {
                licenseDocumentUrl: fileUrl,
                licenseStatus: result.status,
            },
        });

        await this.updateVerifiedStatus(userId);
        return result;
    }

    async verifyCriminalRecord(userId: string, filePath: string, fileUrl: string): Promise<OcrVerificationResult> {
        const user = await this.prisma.user.findUnique({ where: { id: userId } });
        const text = await this.ocrService.extractText(filePath);
        const result = this.evaluateCriminalRecord(text, user?.fullName, user?.dateOfBirth);

        await this.prisma.user.update({
            where: { id: userId },
            data: {
                criminalRecordDocumentUrl: fileUrl,
                criminalRecordStatus: result.status,
            },
        });

        await this.updateVerifiedStatus(userId);
        return result;
    }

    private evaluateIdentity(text: string, fullName?: string, dateOfBirth?: Date): OcrVerificationResult {
        const normalized = this.normalizeText(text);
        const missing: string[] = [];
        const mismatch: string[] = [];

        const idNumber = this.extractTcKimlik(text);
        const idValid = Boolean(idNumber && this.isValidTcKimlik(idNumber));
        if (!idNumber) {
            missing.push('id_number_missing');
        } else if (!idValid) {
            missing.push('id_number_invalid');
        }

        const nameCheck = this.checkName(normalized, fullName);
        if (nameCheck.status === 'missing') missing.push('name_unreadable');
        if (nameCheck.status === 'mismatch') mismatch.push('name_mismatch');

        const dobCheck = this.checkDateOfBirth(text, dateOfBirth);
        if (dobCheck.status === 'missing') missing.push('dob_unreadable');
        if (dobCheck.status === 'mismatch') mismatch.push('dob_mismatch');

        const keywordMatch =
            normalized.includes('TURKIYE') ||
            normalized.includes('T C') ||
            normalized.includes('TC') ||
            normalized.includes('CUMHURIYETI');

        const status = this.decideStatus(missing, mismatch);

        return {
            status,
            score: this.computeScore({
                idNumberValid: idValid,
                name: nameCheck.matched,
                dateOfBirth: dobCheck.matched,
                keywords: keywordMatch,
            }),
            matches: {
                idNumberValid: idValid,
                name: nameCheck.matched,
                dateOfBirth: dobCheck.matched,
                keywords: keywordMatch,
            },
            extracted: {
                idNumber: idNumber || undefined,
                dateOfBirth: dobCheck.extracted,
            },
            issues: [...mismatch, ...missing],
        };
    }

    private evaluateLicense(text: string, fullName?: string, dateOfBirth?: Date): OcrVerificationResult {
        const normalized = this.normalizeText(text);
        const missing: string[] = [];
        const mismatch: string[] = [];

        const nameCheck = this.checkName(normalized, fullName);
        if (nameCheck.status === 'missing') missing.push('name_unreadable');
        if (nameCheck.status === 'mismatch') mismatch.push('name_mismatch');

        const dobCheck = this.checkDateOfBirth(text, dateOfBirth);
        if (dobCheck.status === 'missing') missing.push('dob_unreadable');
        if (dobCheck.status === 'mismatch') mismatch.push('dob_mismatch');

        let expiry = this.extractLatestDate(text);
        if (expiry?.date && dateOfBirth && this.isSameDate(expiry.date, dateOfBirth)) {
            expiry = null;
        }
        let expiryValid = false;
        if (!expiry?.date) {
            missing.push('license_expiry_missing');
        } else if (this.isFutureDate(expiry.date)) {
            expiryValid = true;
        } else {
            mismatch.push('license_expired');
        }

        const classes = this.extractLicenseClasses(normalized);

        const status = this.decideStatus(missing, mismatch);

        return {
            status,
            score: this.computeScore({
                name: nameCheck.matched,
                dateOfBirth: dobCheck.matched,
                licenseExpiryValid: expiryValid,
            }),
            matches: {
                name: nameCheck.matched,
                dateOfBirth: dobCheck.matched,
                licenseExpiryValid: expiryValid,
            },
            extracted: {
                dateOfBirth: dobCheck.extracted,
                licenseExpiry: expiry?.raw,
                licenseClasses: classes.length ? classes : undefined,
            },
            issues: [...mismatch, ...missing],
        };
    }

    private evaluateCriminalRecord(text: string, fullName?: string, dateOfBirth?: Date): OcrVerificationResult {
        const normalized = this.normalizeText(text);
        const missing: string[] = [];
        const mismatch: string[] = [];

        const nameCheck = this.checkName(normalized, fullName);
        if (nameCheck.status === 'missing') missing.push('name_unreadable');
        if (nameCheck.status === 'mismatch') mismatch.push('name_mismatch');

        const dobCheck = this.checkDateOfBirth(text, dateOfBirth);
        if (dobCheck.status === 'missing') missing.push('dob_unreadable');
        if (dobCheck.status === 'mismatch') mismatch.push('dob_mismatch');

        const recordStatus = this.detectCriminalRecordStatus(normalized);
        if (recordStatus === 'unknown') {
            missing.push('record_status_unknown');
        } else if (recordStatus === 'dirty') {
            mismatch.push('record_not_clean');
        }

        const status = this.decideStatus(missing, mismatch);

        return {
            status,
            score: this.computeScore({
                name: nameCheck.matched,
                dateOfBirth: dobCheck.matched,
                recordClean: recordStatus === 'clean',
            }),
            matches: {
                name: nameCheck.matched,
                dateOfBirth: dobCheck.matched,
                recordClean: recordStatus === 'clean',
            },
            extracted: {
                dateOfBirth: dobCheck.extracted,
            },
            issues: [...mismatch, ...missing],
        };
    }

    private decideStatus(missing: string[], mismatch: string[]): 'verified' | 'pending' | 'rejected' {
        if (mismatch.length > 0) return 'rejected';
        if (missing.length > 0) return 'pending';
        return 'verified';
    }

    private computeScore(matches: {
        idNumberValid?: boolean;
        name?: boolean;
        dateOfBirth?: boolean;
        keywords?: boolean;
        licenseExpiryValid?: boolean;
        recordClean?: boolean;
    }): number {
        const values = Object.values(matches).filter((value) => value !== undefined) as boolean[];
        if (values.length === 0) return 0;
        const matched = values.filter((value) => value).length;
        return Number((matched / values.length).toFixed(2));
    }

    private extractTcKimlik(text: string): string | null {
        const candidates: string[] = [];
        const lines = text.split(/\r?\n/);
        for (const line of lines) {
            const digits = line.replace(/\D/g, '');
            if (digits.length < 11) continue;
            for (let i = 0; i <= digits.length - 11; i += 1) {
                candidates.push(digits.slice(i, i + 11));
            }
        }

        const valid = candidates.find((candidate) => this.isValidTcKimlik(candidate));
        if (valid) return valid;
        return candidates[0] || null;
    }

    private isValidTcKimlik(id: string): boolean {
        if (!/^\d{11}$/.test(id)) return false;
        if (id[0] === '0') return false;
        const digits = id.split('').map((d) => parseInt(d, 10));
        const sumOdd = digits[0] + digits[2] + digits[4] + digits[6] + digits[8];
        const sumEven = digits[1] + digits[3] + digits[5] + digits[7];
        const check10 = ((sumOdd * 7) - sumEven) % 10;
        const sumAll = digits.slice(0, 10).reduce((a, b) => a + b, 0);
        const check11 = sumAll % 10;
        return digits[9] === check10 && digits[10] === check11;
    }

    private checkName(text: string, fullName?: string): { status: 'ok' | 'missing' | 'mismatch'; matched: boolean } {
        if (!fullName) return { status: 'missing', matched: false };
        const normalizedName = this.normalizeText(fullName);
        const nameParts = normalizedName.split(/\s+/).filter(Boolean);
        if (nameParts.length === 0) return { status: 'missing', matched: false };

        const allMatch = nameParts.every((part) => text.includes(part));
        if (allMatch) return { status: 'ok', matched: true };

        const anyMatch = nameParts.some((part) => text.includes(part));
        return { status: anyMatch ? 'mismatch' : 'missing', matched: false };
    }

    private checkDateOfBirth(text: string, dateOfBirth?: Date): { status: 'ok' | 'missing' | 'mismatch'; matched: boolean; extracted?: string } {
        if (!dateOfBirth) return { status: 'missing', matched: false };
        const dateMatch = this.matchDateOfBirth(text, dateOfBirth);
        const extracted = this.extractDateString(text);
        if (dateMatch) return { status: 'ok', matched: true, extracted: extracted || undefined };
        if (extracted) return { status: 'mismatch', matched: false, extracted };
        return { status: 'missing', matched: false };
    }

    private matchDateOfBirth(text: string, dateOfBirth?: Date): boolean {
        if (!dateOfBirth) return false;
        const normalizedText = text.replace(/\s+/g, ' ');
        const yyyy = dateOfBirth.getFullYear().toString();
        const mm = (dateOfBirth.getMonth() + 1).toString().padStart(2, '0');
        const dd = dateOfBirth.getDate().toString().padStart(2, '0');
        return (
            normalizedText.includes(`${dd}.${mm}.${yyyy}`) ||
            normalizedText.includes(`${dd}/${mm}/${yyyy}`) ||
            normalizedText.includes(`${yyyy}-${mm}-${dd}`)
        );
    }

    private extractDateString(text: string): string | undefined {
        const match = text.match(/\b\d{2}[./-]\d{2}[./-]\d{4}\b/);
        if (match) return match[0];
        const alt = text.match(/\b\d{4}-\d{2}-\d{2}\b/);
        return alt ? alt[0] : undefined;
    }

    private extractLatestDate(text: string): { raw?: string; date?: Date } | null {
        const matches = text.match(/\b\d{2}[./-]\d{2}[./-]\d{4}\b/g) || [];
        const parsed = matches
            .map((value) => ({ raw: value, date: this.parseDate(value) }))
            .filter((item) => item.date !== null) as { raw: string; date: Date }[];

        if (parsed.length === 0) {
            const alt = text.match(/\b\d{4}-\d{2}-\d{2}\b/g) || [];
            const altParsed = alt
                .map((value) => ({ raw: value, date: this.parseDate(value) }))
                .filter((item) => item.date !== null) as { raw: string; date: Date }[];
            if (altParsed.length === 0) return null;
            return altParsed.sort((a, b) => b.date.getTime() - a.date.getTime())[0];
        }

        return parsed.sort((a, b) => b.date.getTime() - a.date.getTime())[0];
    }

    private parseDate(value: string): Date | null {
        const m = value.match(/(\d{2})[./-](\d{2})[./-](\d{4})/);
        if (m) {
            const day = parseInt(m[1], 10);
            const month = parseInt(m[2], 10);
            const year = parseInt(m[3], 10);
            const date = new Date(year, month - 1, day);
            if (date.getFullYear() === year && date.getMonth() === month - 1 && date.getDate() === day) {
                return date;
            }
            return null;
        }
        const iso = value.match(/(\d{4})-(\d{2})-(\d{2})/);
        if (iso) {
            const year = parseInt(iso[1], 10);
            const month = parseInt(iso[2], 10);
            const day = parseInt(iso[3], 10);
            const date = new Date(year, month - 1, day);
            if (date.getFullYear() === year && date.getMonth() === month - 1 && date.getDate() === day) {
                return date;
            }
        }
        return null;
    }

    private isFutureDate(date: Date): boolean {
        const today = new Date();
        const todayMidnight = new Date(today.getFullYear(), today.getMonth(), today.getDate());
        return date.getTime() > todayMidnight.getTime();
    }

    private isSameDate(left: Date, right: Date): boolean {
        return (
            left.getFullYear() === right.getFullYear() &&
            left.getMonth() === right.getMonth() &&
            left.getDate() === right.getDate()
        );
    }

    private extractLicenseClasses(text: string): string[] {
        const normalized = text.toUpperCase();
        const regex = /\b(AM|A1|A2|A|B1|B|BE|C1|C|C1E|CE|D1|D|D1E|DE|F|G|M)\b/g;
        const results = new Set<string>();
        let match: RegExpExecArray | null;
        while ((match = regex.exec(normalized)) !== null) {
            results.add(match[1]);
        }
        return Array.from(results.values()).sort();
    }

    private detectCriminalRecordStatus(text: string): 'clean' | 'dirty' | 'unknown' {
        const cleanSignals = [
            'ADLI SICIL KAYDI YOKTUR',
            'ADLI SICIL KAYDI BULUNMAMAKTADIR',
            'SABIKA KAYDI YOKTUR',
            'SICIL KAYDI YOKTUR',
            'KAYDI YOKTUR',
        ];
        const dirtySignals = [
            'ADLI SICIL KAYDI VARDIR',
            'SABIKA KAYDI VARDIR',
            'KAYDI VARDIR',
            'HUKUMLU',
            'MAHKUM',
        ];

        const clean = cleanSignals.some((signal) => text.includes(signal));
        const dirty = dirtySignals.some((signal) => text.includes(signal));

        if (clean && !dirty) return 'clean';
        if (dirty) return 'dirty';
        return 'unknown';
    }

    private normalizeText(value: string): string {
        const map: Record<string, string> = {
            ç: 'c',
            ğ: 'g',
            ı: 'i',
            i: 'i',
            ö: 'o',
            ş: 's',
            ü: 'u',
        };
        return value
            .toLowerCase()
            .split('')
            .map((char) => (map[char] ? map[char] : char))
            .join('')
            .replace(/[^a-z0-9\s]/g, ' ')
            .replace(/\s+/g, ' ')
            .trim()
            .toUpperCase();
    }

    private async updateVerifiedStatus(userId: string): Promise<void> {
        const user = await this.prisma.user.findUnique({
            where: { id: userId },
            select: {
                identityStatus: true,
                licenseStatus: true,
                criminalRecordStatus: true,
                verified: true,
            },
        });

        if (!user) return;
        const verified = user.identityStatus === 'verified'
            && user.licenseStatus === 'verified'
            && user.criminalRecordStatus === 'verified';

        if (verified !== user.verified) {
            await this.prisma.user.update({
                where: { id: userId },
                data: { verified },
            });
        }
    }
}
