export type RouteCoordinate = {
  lat: number;
  lng: number;
};

export type RoutePath = {
  provider: string;
  distanceKm: number;
  durationMin: number;
  points: RouteCoordinate[];
  bbox?: {
    minLat: number;
    minLng: number;
    maxLat: number;
    maxLng: number;
  };
};

export type RoutePreviewInput = {
  departureLat: number;
  departureLng: number;
  arrivalLat: number;
  arrivalLng: number;
  alternatives?: number;
};

export interface RoutingProvider {
  readonly name: string;
  getRouteAlternatives(input: RoutePreviewInput): Promise<RoutePath[]>;
}
