import { VerificationService } from './verification.service';

const validTcKimlik = '10000000146';

const buildService = (textsByPath: Record<string, string>) => {
    const prisma = {
        user: {
            findUnique: jest.fn().mockResolvedValue({
                id: 'user-1',
                fullName: 'Ali Veli',
                dateOfBirth: new Date('1990-01-01'),
            }),
            update: jest.fn().mockResolvedValue({}),
        },
    } as any;

    const ocr = {
        extractText: jest.fn(async (path: string) => textsByPath[path] ?? ''),
    } as any;

    const service = new VerificationService(prisma, ocr);
    return { service, prisma, ocr };
};

describe('VerificationService (OCR rules)', () => {
    test('identity verified when all fields match', async () => {
        const text = `T.C. TURKIYE CUMHURIYETI\nALI VELI\n01.01.1990\n${validTcKimlik}`;
        const { service } = buildService({ 'id.png': text });

        const result = await service.verifyIdentity('user-1', 'id.png', '/uploads/identity/id.png');

        expect(result.status).toBe('verified');
        expect(result.issues).toHaveLength(0);
        expect(result.matches.idNumberValid).toBe(true);
        expect(result.matches.name).toBe(true);
        expect(result.matches.dateOfBirth).toBe(true);
    });

    test('identity pending when data unreadable', async () => {
        const text = 'T.C. TURKIYE CUMHURIYETI\nALI VELI';
        const { service } = buildService({ 'id.png': text });

        const result = await service.verifyIdentity('user-1', 'id.png', '/uploads/identity/id.png');

        expect(result.status).toBe('pending');
        expect(result.issues).toContain('id_number_missing');
        expect(result.issues).toContain('dob_unreadable');
    });

    test('identity rejected on mismatch', async () => {
        const text = `T.C. TURKIYE CUMHURIYETI\nALI\n02.02.1990\n${validTcKimlik}`;
        const { service } = buildService({ 'id.png': text });

        const result = await service.verifyIdentity('user-1', 'id.png', '/uploads/identity/id.png');

        expect(result.status).toBe('rejected');
        expect(result.issues).toContain('name_mismatch');
        expect(result.issues).toContain('dob_mismatch');
    });

    test('license verified when name/dob match and expiry in future', async () => {
        const front = 'SURUCU BELGESI\nALI VELI\n01.01.1990';
        const back = 'GECERLILIK 01.01.2027\nSINIF B';
        const { service } = buildService({ 'front.png': front, 'back.png': back });

        const result = await service.verifyLicense('user-1', ['front.png', 'back.png'], '/uploads/license/front.png');

        expect(result.status).toBe('verified');
        expect(result.matches.licenseExpiryValid).toBe(true);
        expect(result.extracted.licenseClasses).toContain('B');
    });

    test('license pending when expiry unreadable', async () => {
        const front = 'SURUCU BELGESI\nALI VELI\n01.01.1990';
        const { service } = buildService({ 'front.png': front });

        const result = await service.verifyLicense('user-1', ['front.png'], '/uploads/license/front.png');

        expect(result.status).toBe('pending');
        expect(result.issues).toContain('license_expiry_missing');
    });

    test('license rejected when expired', async () => {
        const front = 'SURUCU BELGESI\nALI VELI\n01.01.1990';
        const back = 'GECERLILIK 01.01.2020\nSINIF B';
        const { service } = buildService({ 'front.png': front, 'back.png': back });

        const result = await service.verifyLicense('user-1', ['front.png', 'back.png'], '/uploads/license/front.png');

        expect(result.status).toBe('rejected');
        expect(result.issues).toContain('license_expired');
    });

    test('criminal record verified when clean', async () => {
        const text = 'ADLI SICIL KAYDI YOKTUR\nALI VELI\n01.01.1990';
        const { service } = buildService({ 'record.png': text });

        const result = await service.verifyCriminalRecord('user-1', 'record.png', '/uploads/criminal-records/record.png');

        expect(result.status).toBe('verified');
        expect(result.matches.recordClean).toBe(true);
    });

    test('criminal record pending when status unknown', async () => {
        const text = 'ALI VELI\n01.01.1990';
        const { service } = buildService({ 'record.png': text });

        const result = await service.verifyCriminalRecord('user-1', 'record.png', '/uploads/criminal-records/record.png');

        expect(result.status).toBe('pending');
        expect(result.issues).toContain('record_status_unknown');
    });

    test('criminal record rejected when dirty', async () => {
        const text = 'ADLI SICIL KAYDI VARDIR\nALI VELI\n01.01.1990';
        const { service } = buildService({ 'record.png': text });

        const result = await service.verifyCriminalRecord('user-1', 'record.png', '/uploads/criminal-records/record.png');

        expect(result.status).toBe('rejected');
        expect(result.issues).toContain('record_not_clean');
    });
});
