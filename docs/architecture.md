# Architecture Overview

This document summarizes the current system architecture for the ridesharing app.

## Components
- `mobile/`: Flutter client application (Riverpod + GoRouter).
- `backend/`: NestJS API (Clean Architecture style) with Prisma.
- `nginx/`: Reverse proxy and TLS termination for production.
- `docker-compose*.yml`: Local and production container orchestration.

## High-Level Flow
1. Mobile client authenticates via `/v1/auth/*`.
2. Requests are routed to feature modules (users, trips, bookings, messages, verification).
3. Prisma provides access to PostgreSQL.
4. WebSocket gateway handles real-time chat on `/chat`.

## External Integrations
- Payments: Iyzico (currently mocked via `USE_MOCK_INTEGRATIONS`).
- Notifications: Netgsm SMS + FCM (mocked unless enabled).

## Verification & OCR
- Endpoints: `/v1/verification/upload-identity`, `/v1/verification/upload-license`, `/v1/verification/upload-criminal-record`.
- OCR pipeline: `tesseract.js` for images, `pdf-parse` for text-based PDFs.
- Status rules: `verified` only if all required fields match; `pending` if any field is unreadable or missing; `rejected` if any mismatch or dirty criminal record is detected.
- License rule: expiry must be a future date; license classes are extracted for later matching.
- Storage: only document URLs and status are stored; OCR text is not stored.

## Mobile Capture Flow
- License upload requires both front and back images; criminal record accepts PDF or image.
- In-app camera capture provides an overlay guide (ID frame, photo box, alignment marks).
- UI includes a Turkish guidance card with a good photo example and capture tips.

