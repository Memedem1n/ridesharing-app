# Agent Handoff (ridesharing-app)

Last updated: 2026-02-10

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
- Implemented payout-account security endpoints under users:
  - `GET /v1/users/me/payout-account`
  - `POST /v1/users/me/payout-account`
  - `POST /v1/users/me/payout-account/verify`
- Enforced payout guardrails in backend:
  - identity must be verified before payout account setup
  - TR-IBAN format/checksum validation
  - strict account-holder vs identity name matching
  - challenge-code verification with attempt limits and temporary lock behavior
- Implemented booking lifecycle hardening and new endpoints:
  - `POST /v1/bookings/:id/accept`
  - `POST /v1/bookings/:id/reject`
  - `POST /v1/bookings/:id/complete`
  - `POST /v1/bookings/:id/dispute`
  - flow: `pending -> awaiting_payment -> confirmed -> checked_in -> completed/disputed`
- Added staged settlement behavior:
  - `%10` payout release attempt at check-in
  - `%90` payout release after completion + dispute window
  - cron service `BookingSettlementService` for auto-complete and payout release loops
- Added Prisma migration `20260209003000_add_payout_and_booking_settlement`:
  - new user payout fields
  - new booking settlement/dispute fields
  - new `payout_ledgers` table
  - rollback expectation: drop `payout_ledgers` + remove added payout/dispute columns from `users` and `bookings`

## Conversation summary (2026-02-09)
- Continued implementation and hardening after payout/booking-flow changes with focus on profile UX, support pages, and full validation.
- Mobile profile improvements:
  - Added profile photo URL editing support in profile details form and profile avatar usage.
  - Files: `mobile/lib/features/profile/presentation/profile_details_screen.dart`, `mobile/lib/features/profile/presentation/profile_screen.dart`, `mobile/lib/core/providers/auth_provider.dart`.
- Added real (temporary) support/about content pages and routed them:
  - New screen: `mobile/lib/features/profile/presentation/about_screen.dart`.
  - Existing support screen wired in router: `mobile/lib/features/profile/presentation/help_support_screen.dart`.
  - Router updates: `mobile/lib/core/router/app_router.dart`.
- Backend profile DTO/service support for photo URL update:
  - `backend/src/application/dto/users/users.dto.ts`
  - `backend/src/application/services/users/users.service.ts`
- E2E and API behavior stabilization:
  - Fixed E2E `supertest` imports in all specs (`backend/test/e2e/*.ts`).
  - Fixed action endpoint HTTP status semantics with `@HttpCode(200)` where needed:
    - `backend/src/interfaces/http/bookings/bookings.controller.ts`
    - `backend/src/interfaces/http/users/users.controller.ts`
  - Fixed trip search query robustness for non-transformed query params (seats/page/limit parsing and date validation) in:
    - `backend/src/application/services/trips/trips.service.ts`
  - Added trip search cache invalidation on trip create/update/cancel and Redis prefix deletion support:
    - `backend/src/application/services/trips/trips.service.ts`
    - `backend/src/infrastructure/cache/redis.service.ts`
  - Updated E2E expectation for booking lifecycle status (`awaiting_payment`) in:
    - `backend/test/e2e/trips-bookings.e2e-spec.ts`
- E2E runner script fixes:
  - Fixed PowerShell path bug in `scripts/run-e2e.ps1` (`Join-Path` usage).
  - Ensured E2E runs sequentially (`--runInBand`) to avoid cross-suite DB cleanup races.
  - Added graceful handling when `prisma generate` fails with Windows file-lock EPERM.
- Mobile test baseline fixed:
  - Replaced default counter widget test with `ProviderScope` bootstrap smoke test:
    - `mobile/test/widget_test.dart`
- Validation run results on 2026-02-09:
  - Backend: `npm run type-check` ✅, `npm test -- --runInBand` ✅ (6/6 suites, 42/42 tests).
  - Backend E2E: `./scripts/run-e2e.ps1 -DatabaseUrl postgresql://postgres:postgres@localhost:5432/ridesharing_test` ✅ (5/5 suites, 8/8 tests).
  - Mobile: `flutter analyze` ✅, `flutter test` ✅, `flutter build web` ✅.
  - Responsive screenshot smoke outputs:
    - `output/screens/login_ios_like.png`
    - `output/screens/login_android_like.png`
    - `output/screens/login_desktop.png`
- Conversation continuation (2026-02-09, late session):
  - Replaced profile photo URL flow with file upload flow end-to-end:
    - backend `POST /v1/users/me/profile-photo` multipart endpoint + e2e test
    - mobile gallery pick/upload + resolved relative `/uploads/...` URLs
  - Added profile driver-preference edit/display parity improvements:
    - profile details form supports music/smoking/pets/ac/chattiness edits
    - profile page renders preference chips
  - Booking/full-capacity hardening:
    - search cards and booking/trip detail flows show `Dolu` state and disable booking actions when no seats
  - Messaging access flow changed to allow opening trip chat without reservation gate (trip-detail message CTA opens/creates conversation)
  - Login/register responsive hardening for compact widths:
    - centered constrained form layout (`maxWidth: 480`) to reduce layout drift on iPhone-class screens
  - OpenAPI metadata cleanup:
    - `docs/api/OPENAPI_SPEC.yaml` title normalized to ASCII-safe text
  - Demo users prepared directly in DB for two-account booking tests:
    - `driver_demo_20260209@demo.local` / `Test1234!` (`+905551112233`)
    - `passenger_demo_20260209@demo.local` / `Test1234!` (`+905551112244`)
  - Validation rerun:
    - backend unit/typecheck ✅ (`44/44`)
    - backend e2e ✅ (`10/10`)
    - mobile analyze/test ✅
  - Note: no frontend host/process was started during final pass per user request.
  - Guest-first browse flow + desktop parity baseline (2026-02-09):
    - Router refactor: app no longer login-first; unauthenticated users can open `/`, `/search`, `/search-results`, and `/trip/:id`.
    - Auth gate behavior: protected routes redirect to `/login?next=...`; login/register now honor `next` and return users to intended screen.
    - Reservation gate: booking actions in trip-detail and booking screens force login for guests; CTA copy updated to reflect this.
    - Guest UX improvements: guest-specific home content shown; personal booking sections hidden unless authenticated.
    - Web desktop baseline redesign:
      - home page now renders a BlaBla-style desktop layout (top bar + hero search + popular routes + guest info)
      - search results desktop layout now includes structured list cards and reservation CTA with login gate
      - desktop shell hides bottom nav for cleaner website-style experience
    - Validation run:
      - `flutter analyze` ✅
      - `flutter test` ✅
      - `flutter build web` ✅ (with existing wasm dry-run warnings from web plugins)
  - Branding and identity alignment pass (2026-02-09, latest):
    - Finalized brand to `Yoliva` and kept only `Soft Curve` logo assets in `mobile/assets/branding/yoliva`.
    - Regenerated launcher icons for web/android/ios from `icon-routepin-asphalt-soft-curve-app-1024.png` via `flutter_launcher_icons`.
    - Updated app identity across platforms:
      - Android: `com.yoliva.app`, launcher label `Yoliva`
      - iOS: bundle id `com.yoliva.app`, display/name `Yoliva`
      - Web: `manifest.json` + `index.html` title/meta set to `Yoliva`
    - Removed off-brand color leftovers and standardized palette to green/neutral + semantic colors.
    - Fixed encoding/clean-code issues in localization and mobile docs; rewrote `mobile/README.md` in clean UTF-8.
    - Validation rerun:
      - `flutter analyze` ✅
      - `flutter test` ✅
      - `flutter build web --release --pwa-strategy=none` ✅
      - `flutter build apk --debug` ✅
      - `flutter build appbundle --release` ✅

## Conversation summary (2026-02-10)
- Continued from guest-first + branding baseline and completed routing architecture hardening with OSRM-first self-host path.
- Backend routing layer was abstracted behind provider contracts:
  - Added `backend/src/infrastructure/maps/routing-provider.ts`
  - Added `backend/src/infrastructure/maps/osrm-routing.provider.ts`
  - Added `backend/src/infrastructure/maps/routing-provider-resolver.service.ts`
  - Added `backend/src/infrastructure/maps/maps.module.ts`
- Added new public route estimate API:
  - `POST /v1/routes/estimate`
  - Controller: `backend/src/interfaces/http/trips/routes.controller.ts`
  - Service logic: `TripsService.estimateRouteCost(...)`
- Expanded trip DTOs for route/estimate payloads (bbox + estimate breakdown):
  - `backend/src/application/dto/trips/trips.dto.ts`
- Wired trip module to maps module/controller:
  - `backend/src/interfaces/http/trips/trips.module.ts`
- Added TR self-host OSRM ops path:
  - `scripts/osrm/setup-tr.ps1` (download + extract/partition/customize)
  - `docker-compose.yml` and `docker-compose.prod.yml` now include `osrm` service wiring.
  - `backend/.env.example` includes `ROUTE_PROVIDER`, `OSRM_BASE_URL`, and fare variables.
- Mobile create-trip flow now uses backend estimate endpoint and shows estimate card:
  - `mobile/lib/features/trips/presentation/create_trip_screen.dart`
- Branding/copy quality updates kept:
  - top-left brand lockup uses logo + `Yoliva` only
  - Turkish copy fixes (`Aynı yöne, daha az masraf`, `Hoş geldiniz`) and slogan consistency.
- Validation rerun in this session:
  - Backend: `npm run build` ✅
  - Backend: `npm test -- application/services/trips/trips.service.spec.ts` ✅
  - Mobile: `flutter analyze` ✅
  - Mobile: `flutter test` ✅
  - Mobile: `flutter build web --release` ✅
  - API smoke: `GET /v1/health` ✅, `POST /v1/routes/estimate` ✅
- Operational note:
  - White/blank web page after deploy is usually host rewrite/cache configuration. Keep SPA fallback (`/* -> /index.html`) and purge cache after release.

## Next session start here
1. Verify production host rewrite/cache policy with one deep-link smoke test (`/search` direct open).
2. Bring OSRM TR dataset online in target host using `scripts/osrm/setup-tr.ps1`.
3. Confirm `/v1/routes/estimate` and `/v1/trips/route-preview` response quality against real city pairs.
4. Review search/autocomplete UX and finalize fallback messaging for low-result regions.

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




