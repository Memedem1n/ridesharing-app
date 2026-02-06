# Agent Handoff (ridesharing-app)

Last updated: 2026-02-04

## Scope
This handoff captures the current technical state of the ridesharing app at:
C:\Users\barut\.gemini\antigravity\playground\crystal-newton\ridesharing-app

## Repository layout
- backend/ (NestJS 10 + TypeScript + Prisma)
- mobile/ (Flutter 3 + Riverpod + GoRouter)
- docs/ (API spec, architecture, ERD, ADRs, runbooks)
- docker-compose.yml (postgres + redis for dev)
- docker-compose.prod.yml (nginx + api + postgres + redis for prod)

## Backend summary
- AppModule imports: Auth, Users, Vehicles, Trips, Bookings, Messages, Verification.
- Global setup: helmet, CORS, ValidationPipe, GlobalExceptionFilter, LoggingInterceptor.
- JWT auth via passport-jwt.
- Swagger enabled in non-prod at /api/docs (global prefix is /v1).
- Services: auth, users, trips, bookings, vehicles, messages.
- Integrations: Iyzico (mock), Netgsm SMS (mock), FCM (mock).
- Bus price scraper exists but is not registered in AppModule providers.

## Mobile summary
- Flutter + Riverpod + GoRouter.
- Dio client with auth interceptor and refresh-token flow.
- Screens: auth, home, search, trips, bookings, messages, profile, verification, QR.
- Maps: flutter_map + geolocator + OSRM routing.

## Data model (Prisma)
- User, Vehicle, Trip, Booking, Message, Review.
- User includes identity/license/criminal status fields.
- Preferences stored as string in DB.

## Environment
- backend/.env.example defines DATABASE_URL (postgres), REDIS_URL, JWT, IYZICO, NETGSM, FIREBASE, R2.
- mobile baseUrl is http://localhost:3000/v1 in lib/core/api/api_client.dart.

## Known issues / mismatches (do not duplicate)
1) backend/prisma/schema.prisma uses sqlite provider but .env.example and docker-compose use postgres.
2) backend/src/controllers/VerificationController.ts has broken syntax (stray lines and braces).
3) verificationStatus is referenced in DTOs/services but does not exist in Prisma schema.
4) User.preferences stored as string but UsersService merges it as object.
5) HealthController exists but is not registered in AppModule; health endpoints likely missing.
6) Upload endpoints store files on disk; Nest does not serve /uploads (no static assets config).
7) Iyzico/Netgsm/FCM are mock implementations.
8) Bus price scraper is in-memory only; no Redis wiring.

## Selected skill set (use for future work)
Backend and architecture:
- nestjs-expert
- typescript-expert
- prisma-expert
- postgres-best-practices
- architecture-patterns
- backend-architect
- api-design-principles
- api-documenter
- auth-implementation-patterns
- api-security-best-practices
- cc-skill-security-review

Mobile and UI:
- flutter-expert
- mobile-design
- ui-ux-pro-max
- mobile-security-coder
- app-store-optimization

Infra and quality:
- docker-expert
- deployment-engineer
- observability-engineer
- test-driven-development
- unit-testing-test-generate
- verification-before-completion

Docs:
- readme

## Active project rules
- No AGENTS.md / CLAUDE.md / CURSOR.md in ridesharing-app.
- Flutter linting: mobile/analysis_options.yaml includes flutter_lints.
- Backend lint/test: package.json scripts (eslint, jest, tsc).
