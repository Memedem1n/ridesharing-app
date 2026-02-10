import { Injectable } from "@nestjs/common";
import { ConfigService } from "@nestjs/config";
import axios from "axios";
import {
  RoutePath,
  RoutingProvider,
  RoutePreviewInput,
} from "./routing-provider";

type OsrmRouteResponse = {
  routes?: Array<{
    distance?: number;
    duration?: number;
    geometry?: { coordinates?: Array<[number, number]> };
    bbox?: [number, number, number, number];
  }>;
};

@Injectable()
export class OsrmRoutingProvider implements RoutingProvider {
  readonly name = "osrm";
  private readonly baseUrl: string;

  constructor(private readonly configService: ConfigService) {
    this.baseUrl =
      this.configService.get<string>("OSRM_BASE_URL") ||
      "https://router.project-osrm.org";
  }

  async getRouteAlternatives(input: RoutePreviewInput): Promise<RoutePath[]> {
    const { departureLat, departureLng, arrivalLat, arrivalLng } = input;
    const alternatives = Number.isFinite(Number(input.alternatives))
      ? Math.max(1, Math.min(Number(input.alternatives), 5))
      : 3;

    const url = `${this.baseUrl}/route/v1/driving/${departureLng},${departureLat};${arrivalLng},${arrivalLat}`;
    const response = await axios.get<OsrmRouteResponse>(url, {
      params: {
        alternatives: String(alternatives),
        overview: "full",
        geometries: "geojson",
        steps: "false",
      },
      timeout: 10_000,
      headers: {
        "User-Agent": "ridesharing-app/1.0",
      },
    });

    const routes = Array.isArray(response.data?.routes)
      ? response.data.routes
      : [];
    if (!routes.length) return [];

    const mappedRoutes: RoutePath[] = [];
    for (const route of routes) {
      const points = (route.geometry?.coordinates || [])
        .filter((coord) => Array.isArray(coord) && coord.length >= 2)
        .map((coord) => ({
          lat: Number(coord[1]),
          lng: Number(coord[0]),
        }))
        .filter(
          (point) => Number.isFinite(point.lat) && Number.isFinite(point.lng),
        );

      const distanceKm = Number(
        (Number(route.distance || 0) / 1000).toFixed(1),
      );
      const durationMin = Number((Number(route.duration || 0) / 60).toFixed(1));
      if (
        !points.length ||
        !Number.isFinite(distanceKm) ||
        !Number.isFinite(durationMin)
      ) {
        continue;
      }

      let bbox: RoutePath["bbox"];
      if (Array.isArray(route.bbox) && route.bbox.length === 4) {
        bbox = {
          minLng: Number(route.bbox[0]),
          minLat: Number(route.bbox[1]),
          maxLng: Number(route.bbox[2]),
          maxLat: Number(route.bbox[3]),
        };
        if (
          !Number.isFinite(bbox.minLat) ||
          !Number.isFinite(bbox.minLng) ||
          !Number.isFinite(bbox.maxLat) ||
          !Number.isFinite(bbox.maxLng)
        ) {
          bbox = undefined;
        }
      }

      mappedRoutes.push({
        provider: this.name,
        distanceKm,
        durationMin,
        points,
        bbox,
      });
    }

    return mappedRoutes;
  }
}
