# Agent Handoff (ridesharing-app)

Last updated: 2026-02-08

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

## Conversation summary (2026-02-07)
- Flutter web dev server was run on `http://localhost:5000` using `C:\Users\barut\Downloads\flutter_windows_3.38.9-stable\flutter\bin\flutter.bat`.
- Riverpod build-time errors were fixed:
  - `ref.listen` moved to widget `build` (was previously in `initState`).
  - search results now update `tripSearchParamsProvider` inside `addPostFrameCallback`.
- Driver flows improved:
  - Added “Yolculuklarım” screen wired to `/trips/my`.
  - Vehicle create now shows API error messages; create-trip redirects to `/vehicle-create` if missing.
  - Vehicle verification screen includes “Araç Ekle” CTA.
- Address autocomplete is live (Nominatim, Turkey-only) for home, search, and create-trip. Trip creation now stores address + lat/lng.
- Trip detail shows “Adres bilgisi yok” if address is missing.
- Demo/mock trips filtered from UI (driverName starting with `test`), and Redis cache was flushed once to remove stale search results.
- Sample data used for QA:
  - Driver account: `driver_20260207051820@demo.local` / `Test1234!`
  - Passenger account: `pass_20260207051820@demo.local` / `Test1234!`
  - Vehicle: `93b8a2cf-e36f-45a4-a79f-52c0064556a4` (Toyota Corolla, 34QA218)
  - Trip: `e2d0bb52-53ce-4954-b45a-441c81f03539` (Istanbul → Ankara, 2026-02-09T06:00:00Z, ₺250, 3 seats)
- Docs updated: `docs/AGENT_CONTEXT.md`, `docs/AGENT_HANDOFF.md`, `docs/AGENT_LOG.md`, `docs/AGENT_SKILLS.md`, `docs/QA_RESULTS.md`, `docs/QA_TREE.md`, `docs/README.md`, root `README.md`.
- Session commit at that time: `0ebdabd`.

## Conversation summary (2026-02-08)
- Synced project docs with current code status: `README.md`, `docs/architecture.md`, `docs/api-spec.yaml`, and `TASKS.md`.
- Added a fresh task audit section in `TASKS.md` and listed prioritized open items.
- Verified that core "done" items are implemented in code (admin APIs, live location namespace, notification infrastructure, vehicle picker, i18n, e2e script).
- Reprioritized backlog: Iyzico payment kept as final phase; iOS release setup marked blocked until paid Apple/App Store Connect setup is available.
- Verified local environment with `flutter doctor -v`: Android SDK/emulator not installed and no local AVD present.
- Implemented PNR fallback end-to-end: backend `POST /bookings/check-in/pnr`, booking `pnrCode` persistence, mobile QR scanner PNR flow, and boarding ticket now uses backend-provided PNR/QR.
- Added backend TR coordinate guard for trip create/update (coordinates must be inside Turkiye bounds when provided).
- Added tests for new behavior (`backend/src/application/services/bookings/bookings.service.spec.ts`, `backend/src/application/services/trips/trips.service.spec.ts`) and added PNR e2e scenario in `backend/test/e2e/trips-bookings.e2e-spec.ts`.
- Updated runbook with admin verification operations guidance (`docs/runbooks.md`).
- Validation results: `npm run type-check` and `npm test -- --runInBand` passed on backend; Flutter analyze reported only existing deprecation infos.
- E2E tests were not executable in this session because `DATABASE_URL/TEST_DATABASE_URL` was not configured for test DB.

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
- Definition of Done: code + relevant tests + docs + `docs/AGENT_LOG.md` entry are required.
- API change rule: endpoint/DTO/response updates must be mirrored in `docs/api/OPENAPI_SPEC.yaml` in the same change set.
- DB migration rule: any Prisma schema change requires a migration and rollback note in handoff/PR notes.
- Breaking change rule: use feature flags or versioned APIs; avoid silent client-breaking changes.
- Test rule: backend changes should add or update at least one relevant unit/e2e test.
- Commit rule: prefer `feat|fix|chore|docs(scope): message`.
- Security rule: never commit secrets; mask PII/tokens in logs.
- Handoff freshness rule: keep conversation summary and referenced latest commit hash current.
- CI rule: lint + tests + typecheck should pass before merge to `master`.
- Ops rule: production bugfixes should include `docs/runbooks.md` update/note.




