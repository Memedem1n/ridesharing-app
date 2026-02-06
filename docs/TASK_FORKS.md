# Task Fork Pack

Generated: 2026-02-04
Scope: ridesharing-app

This file provides one fork prompt per task plus the skills to use.
All prompts are ASCII-only to avoid encoding issues.

## Global rules for every agent
1) Read `docs/AGENT_HANDOFF.md` and `TASKS.md` before changes. If either is missing or unreadable, do a full repo read.
2) Respect domain rules: `backend/src/domain` must stay framework-free and dependency-free.
3) Update `docs/README.md` if you add a new doc under `docs/`.
4) Do not duplicate known issues already listed in `docs/AGENT_HANDOFF.md`.
5) Keep changes minimal and scoped to the task. Avoid unrelated refactors.

## Conversation summary (must read)
- Project root: C:\Users\barut\.gemini\antigravity\playground\crystal-newton\ridesharing-app
- Backend: NestJS 10 + TS + Prisma. Mobile: Flutter + Riverpod + GoRouter.
- Global API prefix: /v1. Swagger: /api/docs (non-prod).
- Prisma schema currently uses sqlite provider; env + docker use Postgres (mismatch).
- VerificationController has broken syntax; HealthController exists but not registered.
- /health path mismatch in prod compose (should be /v1/health).
- /uploads stored on disk but no static serving configured.
- Iyzico/Netgsm/FCM are mock implementations.
- Bus price scraper uses in-memory cache, not Redis.
- Task list is in TASKS.md. Do not duplicate known issues.

## Agent list (task -> skills)
T-01 Align Prisma provider with Postgres -> prisma-expert, postgres-best-practices, backend-architect, verification-before-completion
T-02 Fix VerificationController syntax and route wiring -> nestjs-expert, typescript-expert
T-03 Resolve verificationStatus mismatch (DTOs/services vs Prisma) -> prisma-expert, typescript-expert
T-04 Normalize User.preferences storage (string vs object) -> prisma-expert, typescript-expert
T-05 Register HealthController and expose /v1/health -> nestjs-expert, observability-engineer
T-06 Health check validates DB + Redis connectivity -> nestjs-expert, observability-engineer
T-07 Update prod healthcheck path and docs quick link -> docker-expert, observability-engineer, readme
T-08 Serve /uploads static assets with limits -> nestjs-expert, api-security-best-practices
T-09 Register BusPriceScraperService and wire Redis cache -> nestjs-expert, backend-architect, observability-engineer
T-10 Fix README/docs README tables -> readme
T-11 Align maps stack references in docs (OSM vs Yandex) -> readme
T-12 E-Devlet integration (auto document checks) -> backend-architect, api-design-principles, api-security-best-practices
T-13 OCR verification for uploaded documents -> backend-architect, api-design-principles, verification-before-completion
T-14 Payment system (Iyzico): payment/refund/tokenization + wallet -> backend-architect, api-design-principles, api-security-best-practices, prisma-expert
T-15 Admin panel for document approvals -> backend-architect, api-design-principles, ui-ux-pro-max
T-16 Live location tracking during trips -> flutter-expert, mobile-design, nestjs-expert, api-design-principles
T-17 Push notifications (Firebase) end-to-end -> flutter-expert, nestjs-expert, mobile-security-coder
T-18 SMS integration (Netgsm) for OTP + booking confirmations -> nestjs-expert, auth-implementation-patterns, api-security-best-practices
T-19 Auth OTP delivery + verification with Redis -> nestjs-expert, auth-implementation-patterns, backend-architect
T-20 Booking confirmation SMS/push -> nestjs-expert, api-design-principles, mobile-security-coder
T-21 Trip updates: notify booked passengers -> nestjs-expert, api-design-principles
T-22 Trip cancellation refunds flow -> nestjs-expert, api-design-principles, api-security-best-practices
T-23 Trip search Redis cache lookup -> nestjs-expert, backend-architect, observability-engineer
T-24 Device token storage for notifications -> nestjs-expert, typescript-expert, mobile-security-coder
T-25 Vehicle picker in Create Trip screen -> flutter-expert, mobile-design
T-26 Bus price scraping via Playwright -> typescript-expert, backend-architect
T-27 Multi-language support (EN/AR) -> flutter-expert, mobile-design

## Prompt blocks

### T-01
```
Role: coding agent (Codex).
Repo root: C:\Users\barut\.gemini\antigravity\playground\crystal-newton\ridesharing-app
Skills to use: prisma-expert, postgres-best-practices, backend-architect, verification-before-completion

Task: Align Prisma provider with Postgres and keep config consistent.

Goals:
1) Update prisma provider and datasource to match Postgres.
2) Align .env.example and docker-compose configs.
3) Add or update migrations safely if needed.
4) Update TASKS.md line notes if required.

Constraints:
- Do not break existing data or remove models.
- Keep changes minimal and scoped.
```

### T-02
```
Role: coding agent (Codex).
Repo root: C:\Users\barut\.gemini\antigravity\playground\crystal-newton\ridesharing-app
Skills to use: nestjs-expert, typescript-expert

Task: Fix VerificationController syntax and ensure route wiring works.

Goals:
1) Repair syntax errors and braces.
2) Ensure controller is imported and wired correctly.
3) Add minimal tests if possible (optional).
```

### T-03
```
Role: coding agent (Codex).
Repo root: C:\Users\barut\.gemini\antigravity\playground\crystal-newton\ridesharing-app
Skills to use: prisma-expert, typescript-expert

Task: Resolve verificationStatus mismatch between DTOs/services and Prisma schema.

Goals:
1) Decide whether to add field(s) to Prisma or remove usage.
2) Update DTOs/services/schema consistently.
3) Add migration if schema changes.
```

### T-04
```
Role: coding agent (Codex).
Repo root: C:\Users\barut\.gemini\antigravity\playground\crystal-newton\ridesharing-app
Skills to use: prisma-expert, typescript-expert

Task: Normalize User.preferences storage (string vs object).

Goals:
1) Pick a single representation (JSON string or JSON type).
2) Update schema, mapping, and DTOs.
3) Add migration if needed.
```

### T-05
```
Role: coding agent (Codex).
Repo root: C:\Users\barut\.gemini\antigravity\playground\crystal-newton\ridesharing-app
Skills to use: nestjs-expert, observability-engineer

Task: Register HealthController and expose /v1/health.

Goals:
1) Ensure HealthController is in AppModule.
2) Confirm routing respects the /v1 prefix.
3) Update any quick links if needed.
```

### T-06
```
Role: coding agent (Codex).
Repo root: C:\Users\barut\.gemini\antigravity\playground\crystal-newton\ridesharing-app
Skills to use: nestjs-expert, observability-engineer

Task: Health check should validate DB + Redis connectivity.

Goals:
1) Add DB connectivity check (Prisma).
2) Add Redis connectivity check.
3) Keep response format consistent with current API conventions.
```

### T-07
```
Role: coding agent (Codex).
Repo root: C:\Users\barut\.gemini\antigravity\playground\crystal-newton\ridesharing-app
Skills to use: docker-expert, observability-engineer, readme

Task: Update prod healthcheck to /v1/health and docs quick link.

Goals:
1) Fix docker-compose.prod.yml healthcheck path.
2) Update docs quick links to match /v1/health.
```

### T-08
```
Role: coding agent (Codex).
Repo root: C:\Users\barut\.gemini\antigravity\playground\crystal-newton\ridesharing-app
Skills to use: nestjs-expert, api-security-best-practices

Task: Serve /uploads as static assets with size/mime limits.

Goals:
1) Configure static file serving for uploads.
2) Add size/mime guards to upload endpoints.
3) Document any new config.
```

### T-09
```
Role: coding agent (Codex).
Repo root: C:\Users\barut\.gemini\antigravity\playground\crystal-newton\ridesharing-app
Skills to use: nestjs-expert, backend-architect, observability-engineer

Task: Register BusPriceScraperService and wire Redis cache.

Goals:
1) Ensure service is provided in module.
2) Replace in-memory cache with Redis where applicable.
3) Add safe fallbacks and logging.
```

### T-10
```
Role: documentation agent (Codex).
Repo root: C:\Users\barut\.gemini\antigravity\playground\crystal-newton\ridesharing-app
Skills to use: readme

Task: Fix README and docs README table formatting.

Goals:
1) Repair broken table rows (Runbooks/Agent Handoff).
2) Keep existing links intact.
```

### T-11
```
Role: documentation agent (Codex).
Repo root: C:\Users\barut\.gemini\antigravity\playground\crystal-newton\ridesharing-app
Skills to use: readme

Task: Align maps stack references in docs (OpenStreetMap vs Yandex).

Goals:
1) Find conflicting references.
2) Update docs to reflect actual stack.
```

### T-12
```
Role: system design agent (Codex).
Repo root: C:\Users\barut\.gemini\antigravity\playground\crystal-newton\ridesharing-app
Skills to use: backend-architect, api-design-principles, api-security-best-practices

Task: E-Devlet integration (auto document checks).

Goals:
1) Draft API design and data flow.
2) Identify legal/security constraints and prerequisites.
3) Update docs + TODOs without implementing code yet (if blocked).
```

### T-13
```
Role: system design agent (Codex).
Repo root: C:\Users\barut\.gemini\antigravity\playground\crystal-newton\ridesharing-app
Skills to use: backend-architect, api-design-principles, verification-before-completion

Task: OCR verification for uploaded documents.

Goals:
1) Propose OCR pipeline and data model changes.
2) Define API endpoints and status transitions.
3) Document risk and testing plan.
```

### T-14
```
Role: backend agent (Codex).
Repo root: C:\Users\barut\.gemini\antigravity\playground\crystal-newton\ridesharing-app
Skills to use: backend-architect, api-design-principles, api-security-best-practices, prisma-expert

Task: Payment system (Iyzico) with refunds and tokenization.

Goals:
1) Implement payment intents and refund flow (backend).
2) Add Prisma models if needed.
3) Add security and audit logging.
```

### T-15
```
Role: product/backend agent (Codex).
Repo root: C:\Users\barut\.gemini\antigravity\playground\crystal-newton\ridesharing-app
Skills to use: backend-architect, api-design-principles, ui-ux-pro-max

Task: Admin panel for document approvals.

Goals:
1) Define admin roles and API endpoints.
2) Stub UI structure or document screens (if UI not in repo).
3) Update docs and TASKS.
```

### T-16
```
Role: full-stack mobile/backend agent (Codex).
Repo root: C:\Users\barut\.gemini\antigravity\playground\crystal-newton\ridesharing-app
Skills to use: flutter-expert, mobile-design, nestjs-expert, api-design-principles

Task: Live location tracking during trips.

Goals:
1) Define backend endpoint and payload.
2) Implement mobile tracking hooks and permissions.
3) Add privacy/safety controls.
```

### T-17
```
Role: full-stack mobile/backend agent (Codex).
Repo root: C:\Users\barut\.gemini\antigravity\playground\crystal-newton\ridesharing-app
Skills to use: flutter-expert, nestjs-expert, mobile-security-coder

Task: Push notifications (Firebase) end-to-end.

Goals:
1) Store device tokens.
2) Send push on booking/messaging events.
3) Add minimal docs and config.
```

### T-18
```
Role: backend agent (Codex).
Repo root: C:\Users\barut\.gemini\antigravity\playground\crystal-newton\ridesharing-app
Skills to use: nestjs-expert, auth-implementation-patterns, api-security-best-practices

Task: SMS integration (Netgsm) for OTP + booking confirmations.

Goals:
1) Replace mock Netgsm service with real API calls.
2) Add config, retries, and logging.
3) Keep PII safe in logs.
```

### T-19
```
Role: backend agent (Codex).
Repo root: C:\Users\barut\.gemini\antigravity\playground\crystal-newton\ridesharing-app
Skills to use: nestjs-expert, auth-implementation-patterns, backend-architect

Task: Auth OTP delivery + verification with Redis.

Goals:
1) Generate and store OTP with TTL.
2) Verify OTP on login/registration flow.
3) Add rate limiting where needed.
```

### T-20
```
Role: backend agent (Codex).
Repo root: C:\Users\barut\.gemini\antigravity\playground\crystal-newton\ridesharing-app
Skills to use: nestjs-expert, api-design-principles, mobile-security-coder

Task: Booking confirmation SMS/push.

Goals:
1) Trigger notifications on booking status changes.
2) Ensure idempotency to avoid duplicate notifications.
3) Update docs or events list.
```

### T-21
```
Role: backend agent (Codex).
Repo root: C:\Users\barut\.gemini\antigravity\playground\crystal-newton\ridesharing-app
Skills to use: nestjs-expert, api-design-principles

Task: Trip updates notify booked passengers.

Goals:
1) Identify state changes that need notification.
2) Implement notification dispatch logic.
```

### T-22
```
Role: backend agent (Codex).
Repo root: C:\Users\barut\.gemini\antigravity\playground\crystal-newton\ridesharing-app
Skills to use: nestjs-expert, api-design-principles, api-security-best-practices

Task: Trip cancellation refunds flow.

Goals:
1) Implement refund logic in service layer.
2) Add audit trail and validation.
```

### T-23
```
Role: backend agent (Codex).
Repo root: C:\Users\barut\.gemini\antigravity\playground\crystal-newton\ridesharing-app
Skills to use: nestjs-expert, backend-architect, observability-engineer

Task: Trip search Redis cache lookup.

Goals:
1) Define cache key strategy.
2) Add cache get/set with TTL.
3) Add metrics/logging for cache hits.
```

### T-24
```
Role: backend/mobile agent (Codex).
Repo root: C:\Users\barut\.gemini\antigravity\playground\crystal-newton\ridesharing-app
Skills to use: nestjs-expert, typescript-expert, mobile-security-coder

Task: Device token storage in user preferences.

Goals:
1) Add API to register device tokens.
2) Store tokens in a secure, queryable shape.
3) Add minimal docs and usage notes.
```

### T-25
```
Role: mobile agent (Codex).
Repo root: C:\Users\barut\.gemini\antigravity\playground\crystal-newton\ridesharing-app
Skills to use: flutter-expert, mobile-design

Task: Vehicle picker in Create Trip screen.

Goals:
1) Replace temp vehicle id with user vehicle list.
2) Add UX for selection.
3) Handle empty state gracefully.
```

### T-26
```
Role: backend agent (Codex).
Repo root: C:\Users\barut\.gemini\antigravity\playground\crystal-newton\ridesharing-app
Skills to use: typescript-expert, backend-architect

Task: Bus price scraping via Playwright.

Goals:
1) Implement Playwright scraping flow.
2) Add cache and rate limiting.
3) Document runtime dependencies.
```

### T-27
```
Role: mobile agent (Codex).
Repo root: C:\Users\barut\.gemini\antigravity\playground\crystal-newton\ridesharing-app
Skills to use: flutter-expert, mobile-design

Task: Multi-language support (EN/AR).

Goals:
1) Add localization framework and strings.
2) Update key screens to use localized strings.
3) Document translation workflow.
```
