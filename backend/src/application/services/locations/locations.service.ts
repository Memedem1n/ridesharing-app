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

  async search(query: string): Promise<LocationSuggestionDto[]> {
    const normalized = String(query || '').trim();
    if (normalized.length < 2) return [];

    try {
      const response = await axios.get(`${this.nominatimBaseUrl}/search`, {
        params: {
          format: 'jsonv2',
          q: normalized,
          addressdetails: 1,
          limit: 6,
          countrycodes: 'tr',
          'accept-language': 'tr',
        },
        timeout: 8000,
        headers: {
          // Nominatim policy: identify your application.
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

        const lat = Number(row?.lat);
        const lon = Number(row?.lon);
        if (!Number.isFinite(lat) || !Number.isFinite(lon)) continue;
        if (!this.isWithinTurkey(lat, lon)) continue;

        const displayName = String(row?.display_name || '').trim();
        if (!displayName) continue;

        results.push({ displayName, city, lat, lon });
      }

      return results;
    } catch {
      return [];
    }
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

