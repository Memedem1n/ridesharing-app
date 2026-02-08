# Architecture Overview

Last updated: 2026-02-08

This document summarizes the current architecture for the ridesharing app.

## Components
- `mobile/`: Flutter client (Riverpod, GoRouter, Dio, flutter_map).
- `backend/`: NestJS 10 API (modular clean-style structure) + Prisma.
- `postgres` + `redis`: Development and production data/cache services.
- `nginx/`: Production reverse proxy and TLS termination.
- `docker-compose*.yml`: Local and production orchestration.

## High-Level Request Flow
1. Mobile authenticates via `/v1/auth/*` and stores JWT + refresh token.
2. REST requests hit feature modules (`users`, `trips`, `bookings`, `messages`, `verification`, `admin`).
3. Prisma persists to PostgreSQL.
4. Redis is used for OTP and cache paths where configured; in-memory fallbacks exist.
5. Booking boarding supports QR check-in and PNR check-in (`/v1/bookings/check-in`, `/v1/bookings/check-in/pnr`).

## Realtime Flow
- Chat: Socket.io namespace `/chat` for conversation messaging.
- Live trip location: Socket.io namespace `/location` with `join_trip` and `driver_location_update`.

## External Integrations
- Payments: Iyzico service wired in backend; live mode requires `USE_MOCK_INTEGRATIONS=false` and valid credentials.
- Notifications: Netgsm SMS + Firebase FCM (mock by default, real mode via env vars).
- Address autocomplete: Nominatim (Turkey-focused query shaping in mobile service).
- Route calculation: OSRM over OpenStreetMap data.
- Bus price feed: Playwright-based scraper behind `BUS_SCRAPER_ENABLED=true`.
- Backend coordinate guard enforces Turkiye bounds for trip create/update coordinates.

## Verification & OCR
- Endpoints: `/v1/verification/upload-identity`, `/v1/verification/upload-license`, `/v1/verification/upload-criminal-record`.
- OCR pipeline: `tesseract.js` (images) + `pdf-parse` (text PDFs).
- Status rules:
  - `verified`: required fields match
  - `pending`: required field unreadable/missing
  - `rejected`: mismatch or non-clean criminal record
- License rule: expiry must be in the future.
- Storage rule: document URLs + statuses are stored; raw OCR text is not persisted.

## Admin Surface
- Base path: `/v1/admin`
- Guard: `x-admin-key` header validated by `ADMIN_API_KEY`.
- Includes verification moderation endpoints and bus-price controls.
