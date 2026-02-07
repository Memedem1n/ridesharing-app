import { Module } from '@nestjs/common';
import { BusPriceScraperService } from './bus-price-scraper.service';
import { CacheModule } from '@infrastructure/cache/cache.module';

@Module({
    imports: [CacheModule],
    providers: [BusPriceScraperService],
    exports: [BusPriceScraperService],
})
export class BusPriceModule { }
