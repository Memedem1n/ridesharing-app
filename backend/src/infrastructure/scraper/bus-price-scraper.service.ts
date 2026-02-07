import { Injectable, Logger } from '@nestjs/common';
import { Cron } from '@nestjs/schedule';
import { ConfigService } from '@nestjs/config';
import { chromium } from 'playwright';
import { RedisService } from '@infrastructure/cache/redis.service';

export interface BusPriceData {
    route: string;
    price: number;
    source: string;
    scrapedAt: Date;
}

@Injectable()
export class BusPriceScraperService {
    private readonly logger = new Logger(BusPriceScraperService.name);
    private readonly cacheTtlSeconds: number;
    private readonly redisKeyPrefix = 'bus:price:';
    private readonly enabled: boolean;
    private readonly headless: boolean;
    private readonly timeoutMs: number;
    private readonly maxRoutes: number;

    // In-memory cache (use Redis in production)
    private priceCache: Map<string, BusPriceData> = new Map();

    // Popular routes to scrape
    private readonly routes = [
        { from: 'istanbul', to: 'ankara' },
        { from: 'istanbul', to: 'izmir' },
        { from: 'ankara', to: 'izmir' },
        { from: 'istanbul', to: 'bursa' },
        { from: 'istanbul', to: 'antalya' },
        { from: 'ankara', to: 'antalya' },
        { from: 'istanbul', to: 'konya' },
        { from: 'ankara', to: 'konya' },
    ];

    constructor(
        private readonly redisService: RedisService,
        private readonly configService: ConfigService,
    ) {
        const cacheTtl = Number(this.configService.get('BUS_SCRAPER_CACHE_TTL_SECONDS') || 24 * 60 * 60);
        this.cacheTtlSeconds = Number.isFinite(cacheTtl) ? cacheTtl : 24 * 60 * 60;
        this.enabled = this.configService.get('BUS_SCRAPER_ENABLED') === 'true';
        this.headless = this.configService.get('BUS_SCRAPER_HEADLESS') !== 'false';
        const timeoutMs = Number(this.configService.get('BUS_SCRAPER_TIMEOUT_MS') || 15000);
        this.timeoutMs = Number.isFinite(timeoutMs) ? timeoutMs : 15000;
        const maxRoutes = Number(this.configService.get('BUS_SCRAPER_MAX_ROUTES') || this.routes.length);
        this.maxRoutes = Number.isFinite(maxRoutes) && maxRoutes > 0
            ? Math.min(maxRoutes, this.routes.length)
            : this.routes.length;
    }

    // Run daily at 02:00
    @Cron('0 2 * * *')
    async scrapeBusPrices() {
        if (!this.enabled || process.env.NODE_ENV === 'test') {
            this.logger.log('Bus price scraping is disabled');
            return;
        }

        this.logger.log('Starting daily bus price scraping...');

        const targets = this.routes.slice(0, this.maxRoutes);
        for (const route of targets) {
            try {
                const price = await this.scrapeRoute(route.from, route.to);
                if (price) {
                    const key = `${route.from}-${route.to}`;
                    await this.setCache(key, {
                        route: key,
                        price,
                        source: 'obilet', // or 'enuygun', 'busbud'
                        scrapedAt: new Date(),
                    });
                    this.logger.log(`Scraped ${key}: ₺${price}`);
                }
            } catch (error) {
                this.logger.error(`Failed to scrape ${route.from}-${route.to}:`, error);
            }
        }

        this.logger.log('Bus price scraping completed');
    }

    async getPrice(from: string, to: string): Promise<number | null> {
        const key = `${from.toLowerCase()}-${to.toLowerCase()}`;
        const cached = await this.getCache(key);

        if (cached) {
            // Check if cache is still valid (24 hours)
            const hoursSinceScraped = (Date.now() - cached.scrapedAt.getTime()) / (1000 * 60 * 60);
            if (hoursSinceScraped < 24) {
                return cached.price;
            }
        }

        if (this.enabled) {
            // Fallback: try to scrape on-demand
            try {
                const price = await this.scrapeRoute(from, to);
                if (price) {
                    await this.setCache(key, {
                        route: key,
                        price,
                        source: 'obilet',
                        scrapedAt: new Date(),
                    });
                    return price;
                }
            } catch (error) {
                this.logger.error(`On-demand scrape failed for ${key}:`, error);
            }
        }

        // Return fallback prices for known routes
        return this.getFallbackPrice(from, to);
    }

    private async scrapeRoute(from: string, to: string): Promise<number | null> {
        if (!this.enabled) {
            return null;
        }

        const url = this.buildRouteUrl(from, to);
        const browser = await chromium.launch({ headless: this.headless });
        const page = await browser.newPage({
            locale: 'tr-TR',
            userAgent: 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/121 Safari/537.36',
        });

        try {
            await page.goto(url, { waitUntil: 'domcontentloaded', timeout: this.timeoutMs });
            await page.waitForTimeout(1500);

            const text = await page.evaluate(() => document.body?.innerText || '');
            const prices = this.extractPrices(text);
            if (prices.length > 0) {
                return Math.min(...prices);
            }
            return null;
        } catch (error) {
            this.logger.error(`Scrape failed for ${url}`, error);
            return null;
        } finally {
            await browser.close();
        }
    }

    private getFallbackPrice(from: string, to: string): number | null {
        const fallbackPrices: Record<string, number> = {
            'istanbul-ankara': 350,
            'ankara-istanbul': 350,
            'istanbul-izmir': 300,
            'izmir-istanbul': 300,
            'ankara-izmir': 400,
            'izmir-ankara': 400,
            'istanbul-bursa': 150,
            'bursa-istanbul': 150,
            'istanbul-antalya': 500,
            'antalya-istanbul': 500,
            'ankara-antalya': 450,
            'antalya-ankara': 450,
            'istanbul-konya': 350,
            'konya-istanbul': 350,
            'ankara-konya': 200,
            'konya-ankara': 200,
        };

        const key = `${from.toLowerCase()}-${to.toLowerCase()}`;
        return fallbackPrices[key] || null;
    }

    // Manual price update (admin panel)
    async setPrice(from: string, to: string, price: number, source: string = 'manual'): Promise<void> {
        const key = `${from.toLowerCase()}-${to.toLowerCase()}`;
        await this.setCache(key, {
            route: key,
            price,
            source,
            scrapedAt: new Date(),
        });
    }

    // Get all cached prices
    async getAllPrices(): Promise<BusPriceData[]> {
        const results: BusPriceData[] = [];
        for (const route of this.routes) {
            const key = `${route.from}-${route.to}`;
            const cached = await this.getCache(key);
            if (cached) {
                results.push(cached);
            }
        }
        return results;
    }

    private async getCache(key: string): Promise<BusPriceData | null> {
        if (this.redisService.isConfigured()) {
            return this.redisService.getJson<BusPriceData>(this.redisKeyPrefix + key);
        }
        return this.priceCache.get(key) || null;
    }

    private async setCache(key: string, value: BusPriceData): Promise<void> {
        if (this.redisService.isConfigured()) {
            await this.redisService.setJson(this.redisKeyPrefix + key, value, this.cacheTtlSeconds);
            return;
        }
        this.priceCache.set(key, value);
    }

    private buildRouteUrl(from: string, to: string): string {
        const slug = (value: string) =>
            value
                .trim()
                .toLowerCase()
                .replace(/\s+/g, '-')
                .replace(/[^a-z0-9-]/g, '');
        return `https://www.obilet.com/otobus-bileti/${slug(from)}-${slug(to)}`;
    }

    private extractPrices(text: string): number[] {
        const normalized = text.replace(/\./g, '').replace(/,/g, '.');
        const matches = normalized.match(/\b\d{2,4}(?:\.\d{1,2})?\s*(?:₺|TL|TRY)\b/gi) || [];
        const values = matches
            .map((raw) => raw.replace(/[^0-9.]/g, ''))
            .map((value) => Number.parseFloat(value))
            .filter((value) => Number.isFinite(value) && value >= 40 && value <= 2000);
        return values;
    }
}

