# Task Status (Ridesharing SuperApp)

Source: ridesharing-app/README.md (declares last updated 2026-02-05)
Gap analysis: code/config audit on 2026-02-04

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
- [x] Review system: rating + comment screens

## Required Fixes / Tech Debt
- [ ] Align Prisma provider with Postgres (schema + env + migrations). Skills: prisma-expert, postgres-best-practices, backend-architect, verification-before-completion
- [ ] Fix VerificationController syntax and route wiring. Skills: nestjs-expert, typescript-expert
- [ ] Resolve verificationStatus mismatch between DTOs/services and Prisma schema. Skills: prisma-expert, typescript-expert
- [ ] Normalize User.preferences storage (string vs object) with migration + mapping. Skills: prisma-expert, typescript-expert
- [ ] Register HealthController in AppModule and expose /v1/health. Skills: nestjs-expert, observability-engineer
- [ ] Health check should validate DB + Redis connectivity. Skills: nestjs-expert, observability-engineer
- [ ] Update prod healthcheck to /v1/health and docs quick link. Skills: docker-expert, observability-engineer, readme
- [ ] Serve /uploads as static assets with size/mime limits. Skills: nestjs-expert, api-security-best-practices
- [ ] Register BusPriceScraperService provider and wire Redis cache. Skills: nestjs-expert, backend-architect, observability-engineer
- [ ] Fix README/docs README tables (Runbooks/Agent Handoff row). Skills: readme
- [ ] Align maps stack references (OpenStreetMap vs Yandex) in docs. Skills: readme

## In Progress / On Hold
- [ ] E-Devlet integration: auto document checks (on hold for legal process). Skills: backend-architect, api-design-principles, api-security-best-practices
- [ ] OCR-based verification for uploaded documents. Skills: backend-architect, api-design-principles, verification-before-completion

## Planned
- [ ] Payment system (Iyzico): payment/refund/tokenization + wallet. Skills: backend-architect, api-design-principles, api-security-best-practices, prisma-expert
- [ ] Admin panel for document approvals. Skills: backend-architect, api-design-principles, ui-ux-pro-max
- [ ] Live location tracking during trips. Skills: flutter-expert, mobile-design, nestjs-expert, api-design-principles
- [ ] Push notifications (Firebase) end-to-end. Skills: flutter-expert, nestjs-expert, mobile-security-coder
- [ ] SMS integration (Netgsm) for OTP + booking confirmations. Skills: nestjs-expert, auth-implementation-patterns, api-security-best-practices
- [ ] Auth OTP delivery + verification with Redis. Skills: nestjs-expert, auth-implementation-patterns, backend-architect
- [ ] Booking confirmation SMS/push. Skills: nestjs-expert, api-design-principles, mobile-security-coder
- [ ] Trip updates: notify booked passengers. Skills: nestjs-expert, api-design-principles
- [ ] Trip cancellation refunds flow. Skills: nestjs-expert, api-design-principles, api-security-best-practices
- [ ] Trip search Redis cache lookup. Skills: nestjs-expert, backend-architect, observability-engineer
- [ ] Device token storage in user preferences for notifications. Skills: nestjs-expert, typescript-expert, mobile-security-coder
- [ ] Vehicle picker in Create Trip screen (replace temp vehicle id). Skills: flutter-expert, mobile-design
- [ ] Bus price scraping via Playwright. Skills: typescript-expert, backend-architect
- [ ] Multi-language support (EN/AR). Skills: flutter-expert, mobile-design
