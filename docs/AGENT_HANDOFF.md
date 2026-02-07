# Agent Handoff (ridesharing-app)

Last updated: 2026-02-07

## Scope
This handoff captures the current technical state of the ridesharing app at:
C:\Users\barut\workspace\ridesharing-app

## Agent workflow
- Read `docs/AGENT_CONTEXT.md` for a fast repo summary before making changes.
- Log each change set with `scripts/agent-log.ps1` (writes to `docs/AGENT_LOG.md`).

## Repository layout
- backend/ (NestJS 10 + TypeScript + Prisma)
- mobile/ (Flutter 3 + Riverpod + GoRouter)
- docs/ (API spec, architecture, ERD, ADRs, runbooks)
- docker-compose.yml (postgres + redis for dev)
- docker-compose.prod.yml (nginx + api + postgres + redis for prod)

## Backend summary
- AppModule imports: Auth, Users, Vehicles, Trips, Bookings, Messages, Verification, Admin, Location (CacheModule + BusPriceModule registered).
- Global setup: helmet, CORS, ValidationPipe, GlobalExceptionFilter, LoggingInterceptor.
- JWT auth via passport-jwt.
- Swagger enabled in non-prod at /api/docs (global prefix is /v1).
- Services: auth, users, trips, bookings, vehicles, messages.
- Integrations: Iyzico (mock), Netgsm SMS (real if USE_MOCK_INTEGRATIONS=false), FCM (real if USE_MOCK_INTEGRATIONS=false).
- Auth OTP: `POST /auth/send-otp`, `POST /auth/verify-otp` (returns tokens); OTP stored in Redis with in-memory fallback.
- Device token registration: `POST /users/me/device-token` stores tokens in user preferences.
- Bus price scraper registered; Playwright-based when BUS_SCRAPER_ENABLED=true. Uses Redis cache if configured (fallback to in-memory).
- Live location: Socket.io namespace /location (join_trip, driver_location_update).
- OCR verification uses tesseract.js (images) + pdf-parse (text PDFs); strict matching with status: verified/pending/rejected. License upload supports front/back; expiry must be future.

## Mobile summary
- Flutter + Riverpod + GoRouter.
- Dio client with auth interceptor and refresh-token flow.
- Screens: auth, home, search, trips, bookings, messages, profile, verification, QR.
- Chat screen connects to Socket.io namespace `/chat` for realtime messages.
- Maps: flutter_map + geolocator + OSRM routing.
- Address autocomplete uses Nominatim (OpenStreetMap) and is restricted to Turkey (cities/districts/neighborhoods).
- “Yolculuklarım” screen added for driver listings (wired to `/trips/my`).
- Trip creation persists departure/arrival address + coordinates; trip detail shows a fallback label when address is missing.

## Data model (Prisma)
- User, Vehicle, Trip, Booking, Message, Review.
- User includes identity/license/criminal status fields.
- Preferences stored as Json in DB.

## Environment
- backend/.env.example defines DATABASE_URL (postgres), REDIS_URL, JWT, IYZICO, NETGSM, FIREBASE, R2, OTP_TTL_SECONDS, ADMIN_API_KEY, BUS_SCRAPER_*, TRIP_SEARCH_CACHE_TTL_SECONDS, TRIP_LOCATION_TTL_SECONDS.
- mobile baseUrl is http://localhost:3000/v1 in lib/core/api/api_client.dart.

## Known issues / mismatches (do not duplicate)
1) Iyzico remains mock (payment implementation pending).
2) Bus price scraping is disabled by default (BUS_SCRAPER_ENABLED=false); fallback prices used unless enabled.
3) FCM/Netgsm require credentials and USE_MOCK_INTEGRATIONS=false to send real notifications.

## Selected skill set (use for future work)
Repo skills:
- ridesharing-backend
- ridesharing-mobile
- ridesharing-api-contract
- ridesharing-ops
- ridesharing-agent-log

Default skills:
- See `docs/AGENT_SKILLS.md`

Repo skills sync:
- `.codex/skills` contains all global skills (synced from $HOME/.codex/skills)

## Active project rules
- No AGENTS.md / CLAUDE.md / CURSOR.md in ridesharing-app.
- Flutter linting: mobile/analysis_options.yaml includes flutter_lints.
- Backend lint/test: package.json scripts (eslint, jest, tsc).




