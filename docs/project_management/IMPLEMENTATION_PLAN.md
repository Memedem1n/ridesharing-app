# Map & Identity Verification Implementation Plan (Updated)

## Goal Description
Replace Google Maps with **OpenStreetMap (OSM)** using `flutter_map` to achieve a cost-free, customizable, and independent mapping system. Implement "BlaBlaCar-style" routing, live tracking, and calculation (price/time) using OSRM.

## User Review Required
> [!NOTE]
> **Routing Engine**: We will use public **OSRM (Open Source Routing Machine)** servers for development. For production/offline capability, we can host a dockerized OSRM instance.
> **Tiles**: We will use **CartoDB Dark Matter** tiles. They are free, lightweight, and perfect for our Dark Glassmorphism theme.

## Proposed Changes

### 1. Map Integration (Frontend)
Switch from `google_maps_flutter` to `flutter_map`.

#### [MODIFY] [pubspec.yaml](file:///c:/Users/barut/.gemini/antigravity/playground/crystal-newton/ridesharing-app/mobile/pubspec.yaml)
- **REMOVE**: `google_maps_flutter`, `geolocator` (keep geolocator for device location).
- **ADD**: 
    - `flutter_map`: Core OSM rendering.
    - `latlong2`: Coordinate handling.
    - `http`: For fetching routes from OSRM.
    - `dio_cache_interceptor`: To aggressively cache map tiles (offline-like feel).

#### [REPLACE] [map_view.dart](file:///c:/Users/barut/.gemini/antigravity/playground/crystal-newton/ridesharing-app/mobile/lib/core/widgets/map_view.dart)
- Re-implement using `FlutterMap`.
- Layer 1: TileLayer (CartoDB Dark).
- Layer 2: PolylineLayer (Route path).
- Layer 3: MarkerLayer (Start/End points, Driver cars).

#### [NEW] [route_service.dart](file:///c:/Users/barut/.gemini/antigravity/playground/crystal-newton/ridesharing-app/mobile/lib/core/services/route_service.dart)
- Function `getRoute(start, end)`: Calls OSRM API.
- Parsers response to get:
    - **Polyline points** (geometry) for drawing.
    - **Duration** (seconds).
    - **Distance** (meters).
- Function `calculatePrice(distance)`: Estimation logic.

### 2. Live Tracking Logic
#### [MODIFY] [home_screen.dart](file:///c:/Users/barut/.gemini/antigravity/playground/crystal-newton/ridesharing-app/mobile/lib/features/home/presentation/home_screen.dart)
- Update to use the new OSM `MapView`.
- Add logic to update driver markers in real-time (mocked for now, ready for websocket).

### 3. Identity Verification (Backend & UI)
*Remains unchanged from previous plan, will proceed after Map is fixed.*
