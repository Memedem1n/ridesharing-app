# Task Status (Ridesharing SuperApp)

Source: repo code/docs audit
Last verification pass: 2026-02-14 (EOD checkpoint: web UX parity + backend/mobile validation rerun)

## Open Items (Priority, 2026-02-09)
- [x] Web auth/menu stabilization + demo-user login smoke on web (route guard checks now pass on both `http://localhost:4100` and `http://localhost:3000`; web profile/messages/reservations top-menu/back actions aligned)
- [x] Trip creation parity v2: route alternatives + via-city pickup policy UX hardening (completed 2026-02-10)
- [x] Trip detail parity v2: passenger roster and compact readability polish on all breakpoints (completed 2026-02-10)
- [x] Web desktop parity v2: spacing/typography and CTA hierarchy polish for desktop baseline (completed 2026-02-10)
- [x] Android emulator E2E coverage: emulator launch smoke added and enabled in CI (completed 2026-02-10)
- [ ] iOS release setup: real bundle identifier + App Store Connect key + signing profiles (blocked until paid Apple/App Store Connect setup is available)
- [ ] E-Devlet integration: auto document checks (legal/process dependency)
- [ ] Admin web panel UI (optional): admin moderation API exists, but a dedicated web panel is not in repo
- [ ] Payment system (Iyzico): live payment/refund/tokenization + wallet reconciliation (defer to final phase)
- [ ] Legal final approval/sign-off for Help/About/Security copy (draft v1 content shipped in app)

## Session Checkpoint (2026-02-13 EOD)
### Completed today
- [x] Web path URL strategy initialization added in Flutter (`setUrlStrategy(PathUrlStrategy())`).
- [x] Shared web header updated so guest users also see `Mesajlar` action.
- [x] Web top navigation primary actions aligned to `/search` on home and search-results.
- [x] Trip creation default booking mode switched to approval-first (`bookingType: approval_required` path by default).
- [x] Security/legal screen added (`/security`) and Help/About text updated to legal-ready draft copy.
- [x] Profile verification and vehicle verification screens now have web-specific layouts instead of mobile-only UI.
- [x] Route-check automation script hardened with URL-stability wait (covers delayed auth bootstrap redirects).
- [x] Temporary debug scripts used for ad-hoc Playwright diagnosis were removed from backend root.
- [x] Validation rerun completed on current working tree:
  - backend `npm run type-check` passed
  - backend `npm test -- --runInBand` passed (`7/7`, `52/52`)
  - mobile `flutter analyze` passed
  - mobile `flutter test` passed
  - mobile `flutter build web --release` passed

### In progress
- [ ] Full web screenshot evidence regeneration is in progress (route-level captures now regenerated on backend-served runtime).

### Open blocker (must-fix)
- [x] `http://localhost:3000` route verification blocker resolved (PostgreSQL + backend runtime restored, route checks passed).

### Pending next
- [ ] Regenerate expanded per-page web screenshots (beyond route smoke set) for final release evidence.
- [ ] Capture complete Android screenshot evidence for all critical pages/flows.
- [ ] Finish final repo hygiene pass (unused artifacts/temp outputs) and close QA report.

## Session Continuation (2026-02-14)
### Completed now
- [x] Docker/PostgreSQL/Redis runtime restored locally and backend restarted on `http://localhost:3000`.
- [x] Web route checks rerun successfully against backend-served runtime:
  - command: `scripts/check-web-routes.ps1 -BaseUrl http://localhost:3000`
  - report: `output/playwright/web-route-check-report.json`
  - result: public routes stayed stable, protected routes redirected to `/login?next=...` as expected.
- [x] `4100` (Flutter web server) UI changes are now confirmed on `3000` runtime with matching route behavior.

## Session Closure (2026-02-14 EOD)
### Completed now
- [x] Web chat page now has dedicated desktop layout (readable message bubbles, light input surface, top navigation, back/home/profile/messages actions).
- [x] Web messages list was separated from mobile glass UI and switched to readable desktop cards with consistent menu/back controls.
- [x] Web reservations pages were rebuilt for readability:
  - `Rezervasyonlarim` now has desktop header actions + back flow + light cards + readable status/meta text.
  - `Gelen Talepler` now has desktop header actions + back flow + selector/filter/readability fixes + web-safe dialog colors.
- [x] Home web map section brightness adjusted (less dark overlay, lighter map filter) for easier visual scanning.
- [x] WhatsApp hero illustration flow kept in right-side illustration slot with cleaned edge handling (`hero_whatsapp_car_clean_fixed.png`) and share section visual refreshed.
- [x] End-of-day validation rerun completed on current working tree:
  - backend `npm run type-check` passed
  - backend `npm test -- --runInBand` passed (`7/7`, `55/55`)
  - mobile `flutter analyze` passed

### Pending next
- [ ] Regenerate expanded per-page web screenshots (authenticated + guest + profile/legal/messages/reservations variants).
- [ ] Capture full Android screenshot evidence for critical user and driver flows.
- [ ] Final repository hygiene pass + final QA evidence closure (`docs/QA_RESULTS.md`).

## Completed
- [x] Project setup: Flutter + NestJS base stack
- [x] Auth module: login, register, JWT, secure storage
- [x] Maps integration: OpenStreetMap, markers, route drawing
- [x] Trip management: create 4 trip types (people/pet/cargo/food), search, list
- [x] Booking flow: request creation, driver approve/reject
- [x] Booking lifecycle hardening: `pending -> awaiting_payment -> confirmed -> checked_in -> completed/disputed`
- [x] Booking UX hardening: booking failure reasons are surfaced in mobile instead of generic failure text
- [x] Boarding verification: QR generation + QR scan + PNR check-in endpoint
- [x] Payout security baseline: driver payout account endpoints + TR IBAN validation + identity-name strict match + challenge verification
- [x] Settlement jobs: auto-complete checked-in trips and staged payout release (`%10` check-in, `%90` post-completion window)
- [x] Live location guard: passengers can view live location only after confirmed/paid booking states
- [x] Trip detail compact redesign baseline: route map + occupancy summary + passenger roster visibility gating
- [x] Messaging: real-time chat infra + UI
- [x] Verification module:
  - [x] Identity upload + API
  - [x] Driver license upload + API
  - [x] Vehicle registration upload + API
  - [x] Criminal record upload + API
- [x] OCR-based document verification (basic heuristic)
- [x] Review system: rating + comment screens
- [x] Auth OTP send/verify (Redis-backed) + Netgsm mock integration
- [x] Device token registration endpoint (stored in user preferences)
- [x] Profile menu routing to detail/vehicles/placeholders
- [x] Profile photo upload support: backend `POST /v1/users/me/profile-photo` + mobile gallery upload flow (no URL input)
- [x] Driver preferences in profile: edit + profile chip rendering (music, smoking, pets, AC, chattiness)
- [x] Full-seat UX guardrails: search/booking/trip detail surfaces `Dolu` state and blocks booking actions
- [x] Help/About/Support baseline screens: temporary realistic content with explicit demo note and date
- [x] Login/Register responsive hardening: centered constrained layout for compact devices (iPhone class widths)
- [x] Backend e2e stabilization: supertest import fix, sequential run, endpoint status code alignment, search filter/caching fixes
- [x] Guest-first browse flow: users can open app/search/trip details without login; reservation actions require login/register
- [x] Desktop web baseline redesign: home/search-results structure moved toward BlaBla-style layout with public browsing emphasis
- [x] Yoliva branding integration: Soft Curve icon set, cross-platform app identity update, and green-only palette cleanup
- [x] Routing QA baseline (local): TR OSRM dataset prepared, `/v1/routes/estimate` + `/v1/trips/route-preview` validated on 5 city pairs, and web deep-link smoke (`/` + `/search`) passed without JS runtime errors.
- [x] Vehicle ownership + registration hardening: `registrationNumber` + ownership model (`self|relative`) + relative-owner surname validation + registration image requirement.
- [x] Route/map UX polish: selected-route fit/markers + via-city marker visibility + estimate provider/source text cleanup.
- [x] API contract sync: `OPENAPI_SPEC` updated for `/vehicles/{id}`, `/routes/estimate`, `/locations/search`, and expanded route preview/vehicle schemas.

## Required Fixes / Tech Debt
- [ ] `README.md` historical roadmap sections can drift; treat this file as source of truth.

## Verification Audit (2026-02-11)
- [x] Backend type-check passed (`npm run type-check`).
- [x] Backend unit suites passed (`npm test -- --runInBand`: `7/7` suites, `52/52` tests).
- [x] New vehicle service ownership/registration tests added and passing (`backend/src/application/services/vehicles/vehicles.service.spec.ts`).
- [x] Mobile analyze/test passed (`flutter analyze`, `flutter test`).
- [x] TR OSRM dataset generated locally under `backend/.data/osrm` (`turkey-latest.osrm*` artifacts).
- [x] Route estimate quality smoke passed on 5 city pairs via `POST /v1/routes/estimate`.
- [x] Route preview quality smoke passed on 5 city pairs via `POST /v1/trips/route-preview` (JWT).
- [x] Flutter SPA deep-link smoke passed (`/` and `/search` direct open + hard refresh) with no page/console runtime errors in Playwright check.
- [x] Admin verification and bus-price controls exist under `/v1/admin` with `x-admin-key`.
- [x] Live trip location exists on socket namespace `/location` (`join_trip`, `driver_location_update`) and mobile consumer flow exists.
- [x] Push/SMS notification infrastructure exists (FCM + Netgsm), with mock/real mode by `USE_MOCK_INTEGRATIONS`.
- [x] Trip cancellation refund logic exists in booking/trip services with Iyzico integration hooks.
- [x] Vehicle picker exists in create-trip flow and blocks trip creation when vehicle is missing.
- [x] Multi-language exists for TR/EN/AR with locale persistence.
- [x] E2E automation script exists at `scripts/run-e2e.ps1` with DB safety checks.
- [x] E2E suite passes on test DB (`ridesharing_test`) with `--runInBand`.
- [x] PNR check-in backend endpoint exists (`POST /bookings/check-in/pnr`) and mobile scanner calls it.
- [x] Backend TR coordinate guard exists for trip create/update (coordinates must be inside Turkiye bounds).
- [x] Trip search cache invalidates on create/update/cancel to avoid stale search results.

## QA Findings (2026-02-07)
- [x] Create trip fails: backend rejected `description` (DTO whitelist). Fixed by adding `description` to CreateTripDto and mapping.
- [x] Web build failed: stale file_picker web plugin. Fixed by flutter clean + pub get + rebuild.
- [x] Messaging list blocked for pending bookings. Fixed by including `pending` in conversations list.
- [x] Vehicle create UI missing. Added `VehicleCreateScreen` + routing and list CTA.
- [x] Profile header demo data. Bound to current user + verification.
- [x] Profile edit missing. Added editable profile details form (full name + bio).
- [x] Booking screen demo. Replaced with real booking flow + mock payment notice.
- [x] Booking payment action missing. Added mock payment action for pending bookings.
- [x] Vehicle update used PATCH vs PUT. Fixed to PUT.
- [x] Home screen search card uses static inputs (demo). Now uses form inputs + search params.
- [x] Popular routes + recent trips are demo data. Now computed from `/trips` + `/bookings/my` with empty states.
- [x] Trip detail “Mesaj” now opens chat if booking exists (shows info otherwise).
- [x] Driver “My Trips” screen added and wired to `/trips/my`.
- [ ] Real payment integration (Iyzico) still pending.
- [ ] Live provider payout transfer integration (currently mock release path in service).
- [x] Android emulator E2E coverage baseline added (CI emulator launch smoke active).
- [ ] iOS build setup: update bundle identifier from `com.example.ridesharing_app` to your real App ID.
- [ ] iOS build setup: configure Codemagic App Store Connect API key + signing profiles.
- [ ] iOS build setup: make repo public (or add Codemagic access token for private).

## In Progress / On Hold
- [ ] E-Devlet integration: auto document checks (on hold for legal process). Skills: backend-architect, api-design-principles, api-security-best-practices

## Planned
- [ ] Payment system (Iyzico): payment/refund/tokenization + wallet (final phase). Skills: backend-architect, api-design-principles, api-security-best-practices, prisma-expert
- [x] Admin moderation API for document approvals (`/v1/admin`). Skills: backend-architect, api-design-principles
- [ ] Admin web panel for document approvals (UI) is not implemented in repo. Skills: ui-ux-pro-max
- [x] Live location tracking during trips. Skills: flutter-expert, mobile-design, nestjs-expert, api-design-principles
- [x] Push notifications (Firebase) end-to-end. Skills: flutter-expert, nestjs-expert, mobile-security-coder
- [x] Booking confirmation SMS/push. Skills: nestjs-expert, api-design-principles, mobile-security-coder
- [x] Trip updates: notify booked passengers. Skills: nestjs-expert, api-design-principles
- [x] Trip cancellation refunds flow. Skills: nestjs-expert, api-design-principles, api-security-best-practices
- [x] Trip search Redis cache lookup. Skills: nestjs-expert, backend-architect, observability-engineer
- [x] Vehicle picker in Create Trip screen (replace temp vehicle id). Skills: flutter-expert, mobile-design
- [x] Bus price scraping via Playwright. Skills: typescript-expert, backend-architect
- [x] Multi-language support (EN/AR). Skills: flutter-expert, mobile-design
- [x] E2E automation script: create test DB, run prisma push/migrate, and execute `npm run test:e2e`. Skills: backend-ops, devex


