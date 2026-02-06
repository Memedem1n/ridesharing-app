import { Injectable, Logger } from '@nestjs/common';
import { Cron, CronExpression } from '@nestjs/schedule';

interface BusPriceData {
    route: string;
    price: number;
    source: string;
    scrapedAt: Date;
}

@Injectable()
export class BusPriceScraperService {
    private readonly logger = new Logger(BusPriceScraperService.name);

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

    // Run daily at 02:00
    @Cron('0 2 * * *')
    async scrapeBusPrices() {
        this.logger.log('Starting daily bus price scraping...');

        for (const route of this.routes) {
            try {
                const price = await this.scrapeRoute(route.from, route.to);
                if (price) {
                    const key = `${route.from}-${route.to}`;
                    this.priceCache.set(key, {
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
        const cached = this.priceCache.get(key);

        if (cached) {
            // Check if cache is still valid (24 hours)
            const hoursSinceScraped = (Date.now() - cached.scrapedAt.getTime()) / (1000 * 60 * 60);
            if (hoursSinceScraped < 24) {
                return cached.price;
            }
        }

        // Fallback: try to scrape on-demand
        try {
            const price = await this.scrapeRoute(from, to);
            if (price) {
                this.priceCache.set(key, {
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

        // Return fallback prices for known routes
        return this.getFallbackPrice(from, to);
    }

    private async scrapeRoute(from: string, to: string): Promise<number | null> {
        // TODO: Implement actual Playwright scraping
        // For now, return mock data

        /*
        // Actual implementation would look like:
        const browser = await chromium.launch({ headless: true });
        const page = await browser.newPage();
        
        try {
          const url = `https://www.obilet.com/otobus-bileti/${from}-${to}`;
          await page.goto(url, { waitUntil: 'networkidle' });
          
          // Wait for price elements to load
          await page.waitForSelector('.journey-item-price', { timeout: 10000 });
          
          // Get minimum price
          const prices = await page.$$eval('.journey-item-price', elements => 
            elements.map(el => parseFloat(el.textContent.replace(/[^\d]/g, '')))
          );
          
          return prices.length > 0 ? Math.min(...prices) : null;
        } finally {
          await browser.close();
        }
        */

        // Mock implementation
        return this.getFallbackPrice(from, to);
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
        this.priceCache.set(key, {
            route: key,
            price,
            source,
            scrapedAt: new Date(),
        });
    }

    // Get all cached prices
    getAllPrices(): BusPriceData[] {
        return Array.from(this.priceCache.values());
    }
}
