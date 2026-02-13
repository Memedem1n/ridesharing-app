# Agent Handoff (ridesharing-app)

Last updated: 2026-02-14

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
- Conversation continuation (2026-02-10, routing QA pass):
  - Brought local TR OSRM dataset online via `scripts/osrm/setup-tr.ps1` and confirmed generated artifacts under `backend/.data/osrm`.
  - Hardened `scripts/osrm/setup-tr.ps1` to fail fast when any docker command fails (previously could print `Done` after docker daemon errors).
  - Ran local routing smoke across 5 city pairs (`Istanbul-Ankara`, `Izmir-Antalya`, `Bursa-Eskisehir`, `Adana-Gaziantep`, `Trabzon-Samsun`):
    - `POST /v1/routes/estimate` passed 5/5 with positive distance/duration/cost.
    - `POST /v1/trips/route-preview` passed 5/5 with at least one alternative and valid route points.
  - Ran Flutter SPA deep-link smoke with Playwright on local static host:
    - `/` and `/search` direct open passed.
    - Hard refresh on both routes passed.
    - No page/console runtime errors were observed in the smoke output.
    - Artifact: `output/playwright/deep-link-smoke.json`.
  - Finalized low-result autocomplete fallback UX:
    - Added explicit "no results" helper message in `mobile/lib/core/widgets/location_autocomplete_field.dart`.
- Conversation continuation (2026-02-10, parity v2 + Android emulator CI):
  - Completed create-trip parity v2 polish:
    - route selection cards improved (`Secili` state + direct-route fallback label)
    - route-step helper/copy cleanups and pickup-policy state preservation confirmed
    - file: `mobile/lib/features/trips/presentation/create_trip_screen.dart`
  - Completed trip-detail parity v2 polish:
    - responsive passenger roster row for compact widths
    - occupancy/status chips added in `Yolcu Durumu`
    - content max-width constraint on large screens for readability
    - file: `mobile/lib/features/trips/presentation/trip_detail_screen.dart`
  - Completed web desktop parity v2 pass:
    - home/search desktop top bars and CTA hierarchy tightened
    - search results list/map spacing, card depth, and CTA visibility improved
    - files:
      - `mobile/lib/features/home/presentation/home_screen.dart`
      - `mobile/lib/features/search/presentation/search_results_screen.dart`
  - Added repeatable Android emulator smoke path:
    - script: `scripts/android/emulator-smoke.sh`
    - CI job: `mobile-android-emulator-smoke` (Android 34 emulator + app launch check)
    - workflow updates: `.github/workflows/ci.yml`
  - Validation rerun:
    - `flutter analyze` ✅
    - `flutter test` ✅

## Conversation summary (2026-02-11)
- Fixed Flutter web blank/spinner issue caused by running `flutter run -d web-server` (AssetManifest 404).
  - Backend now serves the built Flutter web output from `mobile/build/web` via `@nestjs/serve-static`.
  - Added SPA fallback middleware so deep links like `/login` and `/search` return `index.html` on hard refresh.
  - Verified locally:
    - `GET /` returns `index.html` (200)
    - `GET /login` returns `index.html` (200)
    - `GET /assets/AssetManifest.bin.json` returns 200
  - Backend dev server was started in background with logs under `backend/.logs/api-dev.log`.
- Conversation continuation (2026-02-11, stabilization + contract sync):
  - Completed UX backlog items from previous checkpoint:
    - web illustration assets replaced with dedicated `mobile/assets/illustrations/web/*` images.
    - trip-detail messaging flow opens/creates chat without booking for authenticated passengers (`openTripConversation`).
    - vehicle create now enforces `registrationNumber` + registration image and relative-owner rules end-to-end.
    - route/map polish completed (fit bounds, start/end + via-city markers, provider/source text removed from estimate card).
  - Added web-safe location autocomplete proxy path:
    - backend `GET /v1/locations/search` (Nominatim proxy with TR filtering)
    - mobile web location service now uses backend proxy route.
  - Synced API contract documentation:
    - `docs/api/OPENAPI_SPEC.yaml` updated for vehicle ownership fields, `/vehicles/{id}`, `/routes/estimate`, `/locations/search`, and richer route preview schemas.
  - Added backend test coverage for vehicle ownership/registration guardrails:
    - `backend/src/application/services/vehicles/vehicles.service.spec.ts` (7 tests).
  - Fixed mojibake currency text in trip detail totals (`TL ...`).
  - Validation rerun:
    - backend `npm run type-check` ✅
    - backend `npm test -- --runInBand` ✅ (`7/7` suites, `52/52` tests)
    - mobile `flutter analyze` ✅
    - mobile `flutter test` ✅
  - Remaining manual QA:
    - web auth/menu behavior consistency and demo-user login smoke should be rechecked interactively in browser.
    - local API boot/login smoke is blocked while PostgreSQL is down (`P1001 localhost:5432`); bring DB up first (`docker compose up -d postgres`).
    - local `docker compose up -d postgres` attempt failed in this session because Docker Desktop engine pipe was unavailable.

## Conversation summary (2026-02-12)
- Continued implementation on search/matching, booking pricing context, and web/mobile UX polish.
- Backend feature additions kept in-progress state (already modified in working tree):
  - fuzzy/partial route matching and contextual segment pricing in trip search
  - contextual trip-detail query support (`GET /trips/:id?from=...&to=...`)
  - booking request segment fields (`requestedFrom`, `requestedTo`) and segment-aware pricing data
  - location search service overhaul with memory cache + fuzzy normalization
- Mobile feature additions kept in-progress state (already modified in working tree):
  - contextual trip/booking navigation (`from/to/sp` query propagation)
  - search results partial-match labels and segment route rendering
  - home map density points for active route visualization
  - create-trip route step readability and web step navigation controls
- Stabilization fixes completed in this pass:
  - fixed Flutter compile error in `mobile/lib/core/services/location_service.dart` (`late final` re-assignment)
  - restored UTF-8 text integrity in:
    - `mobile/lib/features/trips/presentation/create_trip_screen.dart`
    - `mobile/lib/features/home/presentation/home_screen.dart`
  - improved route-selection readability (distance/duration text contrast) in `mobile/lib/features/trips/presentation/create_trip_screen.dart`
  - fixed missing web SVG assets by adding them to `mobile/pubspec.yaml`
- Validation run results (2026-02-12):
  - backend `npm run type-check` ✅
  - backend `npm test -- --runInBand src/application/services/trips/trips.service.spec.ts` ✅
  - backend `npm test -- --runInBand src/application/services/bookings/bookings.service.spec.ts` ✅
  - mobile `flutter analyze` ✅
  - mobile `flutter build apk --debug` ✅
  - web `flutter run -d chrome` starts and UI opens after asset fix ✅
- Important open issue discovered:
  - `/v1/trips` response currently contains invalid UTF-8 bytes in some seeded text fields (seen as `Bad UTF-8 encoding (U+FFFD)` in Flutter web logs). This should be cleaned at DB/data source level before final UX sign-off.
- User-request continuity note:
  - New request to build a usable pitch deck under `C:\Users\barut\workspace\Sunumlar` was acknowledged, but implementation did not start due user interruption.

## Next session start here (updated 2026-02-14)
1. Regenerate expanded web screenshot evidence set (public + authenticated + profile/legal/menu pages) on `http://localhost:3000`.
2. Complete Android end-to-end screenshot evidence for critical flows (home/search/trip-detail/create-trip/reservations/messages/profile/driver-reservations).
3. Finalize repository hygiene pass (remove stale diagnostics/temp artifacts) and close QA evidence gaps.
4. Refresh `docs/QA_RESULTS.md` with final pass/fail matrix and release-readiness checklist.
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





## Conversation summary (2026-02-13 EOD)
- User asked for full day-end closure: write done/in-progress/pending status, clean unnecessary leftovers, and prepare a commit-ready state.
- Runtime/state checks completed:
  - Backend health endpoint `GET /v1/health` reachable on `http://localhost:3000`.
  - Flutter web server (`:4100`) and Android emulator processes were running during validation.
  - Existing Playwright screenshot set from earlier pass was invalid for audit (many files had identical hash/blank captures).
- Implemented in this session:
  - Added web URL strategy initialization in `mobile/lib/main.dart` (`setUrlStrategy(PathUrlStrategy())`).
  - Added direct `flutter_web_plugins` SDK dependency in `mobile/pubspec.yaml`.
  - Updated web top-nav primary actions to point to `/search` from home and search-results screens.
  - Added guest-visible `Mesajlar` action in shared web header (`mobile/lib/core/widgets/web/site_header.dart`).
  - Set trip creation default booking mode to approval-first (`_instantBooking = false`) so payment is not the initial step.
  - Updated GoRouter web initial location handling in `mobile/lib/core/router/app_router.dart` using `Uri.base`.
  - Removed temporary local debug scripts used for ad-hoc Playwright diagnosis.
- Validation rerun (current working tree):
  - Backend: `npm run type-check` ✅
  - Backend: `npm test -- --runInBand` ✅ (7/7 suites, 52/52 tests)
  - Mobile: `flutter analyze` ✅
  - Mobile: `flutter test` ✅
  - Mobile: `flutter build web --release --pwa-strategy=none` ✅
- Key unfinished blocker at end of day:
  - Direct web routes on `http://localhost:3000` still normalize back to `/` in headless checks (`/search`, `/login`, `/help`, `/about`, `/security`), so final page-by-page web screenshot evidence is not yet trustworthy.
- Closing status:
  - Code and docs are checkpointed for continuation.
  - Next session should start from routing root-cause resolution before final UI evidence pass.

## Conversation continuation (2026-02-13, late session)
- User request focus was implemented: legal text refresh, web auth/menu stabilization, and critical blocker progression.
- Mobile/web routing updates completed:
  - `mobile/lib/core/router/app_router.dart` now includes `/security` in public paths and maps `/security` to `SecurityLegalScreen`.
  - Shell route child ordering was adjusted (root `/` moved after specific shell paths) to prevent wrong page rendering on direct route opens.
- Legal/security content updates completed:
  - Added `mobile/lib/features/profile/presentation/security_legal_screen.dart`.
  - Rewrote legal/support copy in:
    - `mobile/lib/features/profile/presentation/about_screen.dart`
    - `mobile/lib/features/profile/presentation/help_support_screen.dart`
- Web UX parity improvements completed:
  - Added web-first layout to `mobile/lib/features/trips/presentation/search_screen.dart`.
  - Added web-specific verification dashboards for:
    - `mobile/lib/features/profile/presentation/verification_screen.dart`
    - `mobile/lib/features/profile/presentation/vehicle_verification_screen.dart`
- Route blocker diagnostics updated:
  - Hardened `backend/scripts/check-web-routes.mjs` with delayed bootstrap + stable-URL wait logic.
  - Wrapper script `scripts/check-web-routes.ps1` used for repeatable checks.
  - Result: route check now passes on `http://localhost:4100` for all public routes and protected-route login redirects.
- Validation rerun in this pass:
  - `flutter analyze` ✅
  - `flutter test` ✅
  - `flutter build web --release --pwa-strategy=none` ✅
  - `scripts/check-web-routes.ps1 -BaseUrl http://localhost:4100` ✅
- Remaining blocker:
  - Final `http://localhost:3000` verification is still pending because backend runtime validation needs PostgreSQL available at `localhost:5432`.

## Conversation continuation (2026-02-14, early session)
- Restored local runtime stack and validated backend-served web mode end-to-end:
  - Docker daemon started successfully.
  - `docker compose up -d postgres redis` completed.
  - backend dev server restarted and `GET /v1/health` responded on `http://localhost:3000`.
- Route/auth blocker closed on backend-served runtime:
  - `scripts/check-web-routes.ps1 -BaseUrl http://localhost:3000` passed.
  - Report confirms:
    - public routes (`/`, `/search`, `/login`, `/help`, `/about`, `/security`) remain on-path
    - protected routes (`/reservations`, `/messages`, `/profile`, `/create-trip`) redirect to `/login?next=...`.
  - Artifact: `output/playwright/web-route-check-report.json`.
- Status update:
  - `4100`-validated UI/router updates are now confirmed on `3000` as well.
  - Remaining work is evidence expansion (full screenshot set + Android captures) and final repo hygiene.

## Conversation continuation (2026-02-14, EOD closeout)
- User requested full end-of-day closure with commit split and push preparation.
- Web UX parity fixes completed in this pass:
  - Web chat got a dedicated desktop layout (readable light surfaces, top menu, back action):
    - `mobile/lib/features/messages/presentation/chat_screen.dart`
  - Web messages list separated from mobile-style glass UI and converted to readable desktop cards:
    - `mobile/lib/features/messages/presentation/messages_screen.dart`
  - Web reservations pages were stabilized for readability/navigation:
    - `mobile/lib/features/bookings/presentation/my_reservations_screen.dart`
    - `mobile/lib/features/bookings/presentation/driver_reservations_screen.dart`
  - Home map visibility improved by reducing darkness in map overlay/filter:
    - `mobile/lib/features/home/presentation/home_screen.dart`
- Illustration status:
  - Hero slot continues using cleaned image variant (`hero_whatsapp_car_clean_fixed.png`) and share visual remains updated in home web sections.
- Validation rerun in this closeout:
  - Backend `npm run type-check` ✅
  - Backend `npm test -- --runInBand` ✅ (`7/7` suites, `55/55` tests)
  - Mobile `flutter analyze` ✅
- Remaining next items:
  - regenerate full web screenshot evidence set (guest/auth/profile/legal/messages/reservations),
  - finalize Android screenshot evidence set for critical flows,
  - complete final repo hygiene + QA evidence closure updates.
