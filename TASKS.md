# Task Status (Ridesharing SuperApp)

Source: ridesharing-app/README.md (declares last updated 2026-02-05)
Gap analysis: code/config audit on 2026-02-06

## Completed
- [x] Project setup: Flutter + NestJS base stack
- [x] Auth module: login, register, JWT, secure storage
- [x] Maps integration: OpenStreetMap, markers, route drawing
- [x] Trip management: create 4 trip types (people/pet/cargo/food), search, list
- [x] Booking flow: request creation, driver approve/reject
- [x] Boarding verification: QR generation + QR scan + PNR fallback
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

## Required Fixes / Tech Debt
- (none as of 2026-02-07)

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
- [ ] Android emulator E2E coverage blocked (no AVD configured).
- [ ] iOS build setup: update bundle identifier from `com.example.ridesharing_app` to your real App ID.
- [ ] iOS build setup: configure Codemagic App Store Connect API key + signing profiles.
- [ ] iOS build setup: make repo public (or add Codemagic access token for private).

## In Progress / On Hold
- [ ] E-Devlet integration: auto document checks (on hold for legal process). Skills: backend-architect, api-design-principles, api-security-best-practices

## Planned
- [ ] Payment system (Iyzico): payment/refund/tokenization + wallet. Skills: backend-architect, api-design-principles, api-security-best-practices, prisma-expert
- [x] Admin panel for document approvals. Skills: backend-architect, api-design-principles, ui-ux-pro-max
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

