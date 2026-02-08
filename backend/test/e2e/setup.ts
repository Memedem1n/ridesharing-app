const defaultDb = 'postgresql://postgres:postgres@localhost:5432/ridesharing_test';

process.env.NODE_ENV = process.env.NODE_ENV || 'test';
process.env.USE_MOCK_INTEGRATIONS = process.env.USE_MOCK_INTEGRATIONS || 'true';
process.env.JWT_SECRET = process.env.JWT_SECRET || 'test-secret';
process.env.JWT_ACCESS_EXPIRY = process.env.JWT_ACCESS_EXPIRY || '15m';
process.env.JWT_REFRESH_EXPIRY = process.env.JWT_REFRESH_EXPIRY || '7d';
process.env.DATABASE_URL = process.env.DATABASE_URL || defaultDb;
process.env.REDIS_URL = process.env.REDIS_URL || 'redis://localhost:6379';
process.env.API_VERSION = process.env.API_VERSION || 'v1';
process.env.OCR_LANGS = process.env.OCR_LANGS || 'tur+eng';
process.env.PORT = process.env.PORT || '3001';

if (!process.env.DATABASE_URL?.includes('ridesharing_test')) {
    throw new Error('E2E tests require DATABASE_URL to point to ridesharing_test to avoid data loss.');
}

