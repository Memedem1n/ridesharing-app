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

