import { Injectable } from '@nestjs/common';
import axios from 'axios';

export type LocationSuggestionDto = {
  displayName: string;
  city: string;
  lat: number;
  lon: number;
};

@Injectable()
export class LocationsService {
  private readonly nominatimBaseUrl = 'https://nominatim.openstreetmap.org';
  private readonly turkeyBounds = {
    minLat: 35.8,
    maxLat: 42.2,
    minLng: 25.6,
    maxLng: 44.9,
  };
  private readonly queryCache = new Map<string, LocationSuggestionDto[]>();
  private readonly memoryByKey = new Map<string, LocationSuggestionDto>();
  private readonly memoryList: LocationSuggestionDto[] = [];
  private readonly cacheLimit = 500;
  private readonly resultLimit = 8;

  async search(query: string): Promise<LocationSuggestionDto[]> {
    const raw = String(query || '').trim();
    if (raw.length < 2) return [];
    const cacheKey = this.normalizeForSearch(raw);
    if (!cacheKey) return [];

    const cached = this.queryCache.get(cacheKey);
    if (cached) {
      return cached;
    }

    const remote = await this.fetchRemoteSuggestions(raw);
    if (remote.length > 0) {
      this.rememberSuggestions(remote);
    }

    const local = this.searchMemory(raw);
    const merged = this.mergeSuggestions(remote, local).slice(
      0,
      this.resultLimit,
    );

    this.queryCache.set(cacheKey, merged);
    if (this.queryCache.size > this.cacheLimit) {
      const oldestKey = this.queryCache.keys().next().value;
      if (oldestKey) this.queryCache.delete(oldestKey);
    }

    return merged;
  }

  private async fetchRemoteSuggestions(
    query: string,
  ): Promise<LocationSuggestionDto[]> {
    const variants = Array.from(
      new Set([
        query.trim(),
        this.normalizeForSearch(query),
        `${query.trim()}, Turkiye`,
      ].filter((item) => item.length > 0)),
    );

    const collected: LocationSuggestionDto[] = [];
    for (const variant of variants) {
      const rows = await this.fetchByVariant(variant);
      if (rows.length > 0) {
        collected.push(...rows);
      }
      if (collected.length >= this.resultLimit) {
        break;
      }
    }

    return this.mergeSuggestions(collected);
  }

  private async fetchByVariant(
    query: string,
  ): Promise<LocationSuggestionDto[]> {
    try {
      const response = await axios.get(`${this.nominatimBaseUrl}/search`, {
        params: {
          format: 'jsonv2',
          q: query,
          addressdetails: 1,
          limit: this.resultLimit,
          countrycodes: 'tr',
          'accept-language': 'tr',
        },
        timeout: 8000,
        headers: {
          'User-Agent': 'yoliva-ridesharing/1.0 (local-dev)',
        },
      });

      const rows = Array.isArray(response.data) ? response.data : [];
      const results: LocationSuggestionDto[] = [];

      for (const row of rows) {
        const address = row?.address || {};
        const countryCode = String(address.country_code || '').toLowerCase();
        if (countryCode !== 'tr') continue;

        const city = String(
          address.city ||
            address.town ||
            address.village ||
            address.state ||
            address.county ||
            address.suburb ||
            address.neighbourhood ||
            address.neighborhood ||
            '',
        ).trim();

        const district = String(
          address.city_district ||
            address.district ||
            address.municipality ||
            '',
        ).trim();

        const neighbourhood = String(
          address.neighbourhood || address.neighborhood || address.suburb || '',
        ).trim();

        const lat = Number(row?.lat);
        const lon = Number(row?.lon);
        if (!Number.isFinite(lat) || !Number.isFinite(lon)) continue;
        if (!this.isWithinTurkey(lat, lon)) continue;

        const displayNameRaw = String(row?.display_name || '').trim();
        const displayName = this.composeDisplayName(
          city,
          district,
          neighbourhood,
          displayNameRaw,
        );
        if (!displayName) continue;

        results.push({ displayName, city, lat, lon });
      }

      return this.mergeSuggestions(results).slice(0, this.resultLimit);
    } catch {
      return [];
    }
  }

  private composeDisplayName(
    city: string,
    district: string,
    neighbourhood: string,
    fallback: string,
  ): string {
    const parts = [city, district, neighbourhood]
      .map((item) => String(item || '').trim())
      .filter((item) => item.length > 0);
    if (parts.length > 0) {
      return Array.from(new Set(parts)).join(', ');
    }
    return fallback;
  }

  private rememberSuggestions(items: LocationSuggestionDto[]): void {
    for (const item of items) {
      const key = this.suggestionKey(item);
      if (this.memoryByKey.has(key)) continue;
      this.memoryByKey.set(key, item);
      this.memoryList.push(item);
    }

    while (this.memoryList.length > this.cacheLimit) {
      const oldest = this.memoryList.shift();
      if (!oldest) continue;
      this.memoryByKey.delete(this.suggestionKey(oldest));
    }
  }

  private searchMemory(query: string): LocationSuggestionDto[] {
    if (this.memoryList.length === 0) return [];
    const normalizedQuery = this.normalizeForSearch(query);
    if (!normalizedQuery) return [];

    const queryTokens = normalizedQuery.split(' ').filter(Boolean);
    if (queryTokens.length === 0) return [];

    const ranked = this.memoryList
      .map((item) => {
        const haystack = this.normalizeForSearch(
          `${item.city} ${item.displayName}`,
        );
        if (!haystack) return null;

        let score = 0;
        if (
          haystack.includes(normalizedQuery) ||
          normalizedQuery.includes(haystack)
        ) {
          score = 100 - Math.abs(haystack.length - normalizedQuery.length);
        } else {
          const haystackTokens = haystack.split(' ').filter(Boolean);
          if (!haystackTokens.length) return null;

          for (const token of queryTokens) {
            const matched = haystackTokens.some((candidate) =>
              this.isFuzzyTokenMatch(token, candidate),
            );
            if (!matched) return null;
            score += 15;
          }
        }

        return { item, score };
      })
      .filter(Boolean) as Array<{ item: LocationSuggestionDto; score: number }>;

    ranked.sort((a, b) => b.score - a.score);
    return ranked.slice(0, this.resultLimit).map((entry) => entry.item);
  }

  private isFuzzyTokenMatch(queryToken: string, candidateToken: string): boolean {
    if (
      candidateToken.includes(queryToken) ||
      queryToken.includes(candidateToken)
    ) {
      return true;
    }

    const maxDistance =
      queryToken.length <= 4 ? 1 : queryToken.length <= 8 ? 2 : 3;
    return (
      this.levenshteinDistance(queryToken, candidateToken, maxDistance) <=
      maxDistance
    );
  }

  private levenshteinDistance(
    left: string,
    right: string,
    maxDistance: number,
  ): number {
    if (left === right) return 0;
    if (!left.length) return right.length;
    if (!right.length) return left.length;
    if (Math.abs(left.length - right.length) > maxDistance) {
      return maxDistance + 1;
    }

    const previousRow = Array.from({ length: right.length + 1 }, (_, i) => i);
    const currentRow = new Array<number>(right.length + 1);

    for (let i = 1; i <= left.length; i += 1) {
      currentRow[0] = i;
      let rowMin = currentRow[0];

      for (let j = 1; j <= right.length; j += 1) {
        const insertCost = currentRow[j - 1] + 1;
        const deleteCost = previousRow[j] + 1;
        const replaceCost =
          previousRow[j - 1] + (left[i - 1] === right[j - 1] ? 0 : 1);
        const next = Math.min(insertCost, deleteCost, replaceCost);
        currentRow[j] = next;
        if (next < rowMin) {
          rowMin = next;
        }
      }

      if (rowMin > maxDistance) {
        return maxDistance + 1;
      }

      for (let j = 0; j <= right.length; j += 1) {
        previousRow[j] = currentRow[j];
      }
    }

    return previousRow[right.length];
  }

  private mergeSuggestions(
    ...groups: Array<LocationSuggestionDto[]>
  ): LocationSuggestionDto[] {
    const merged: LocationSuggestionDto[] = [];
    const seen = new Set<string>();

    for (const group of groups) {
      for (const item of group) {
        const key = this.suggestionKey(item);
        if (seen.has(key)) continue;
        seen.add(key);
        merged.push(item);
      }
    }

    return merged;
  }

  private suggestionKey(item: LocationSuggestionDto): string {
    const name = this.normalizeForSearch(item.displayName);
    return `${name}|${item.lat.toFixed(4)}|${item.lon.toFixed(4)}`;
  }

  private normalizeForSearch(value: string): string {
    return String(value || '')
      .trim()
      .toLocaleLowerCase('tr-TR')
      .replace(/ı/g, 'i')
      .replace(/ğ/g, 'g')
      .replace(/ş/g, 's')
      .replace(/ö/g, 'o')
      .replace(/ü/g, 'u')
      .replace(/ç/g, 'c')
      .normalize('NFKD')
      .replace(/[\u0300-\u036f]/g, '')
      .replace(/[^a-z0-9\s]/g, ' ')
      .replace(/\s+/g, ' ')
      .trim();
  }

  private isWithinTurkey(lat: number, lng: number): boolean {
    return (
      lat >= this.turkeyBounds.minLat &&
      lat <= this.turkeyBounds.maxLat &&
      lng >= this.turkeyBounds.minLng &&
      lng <= this.turkeyBounds.maxLng
    );
  }
}
