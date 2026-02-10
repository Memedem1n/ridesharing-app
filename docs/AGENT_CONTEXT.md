# Agent Context (ridesharing-app)

Last updated: 2026-02-10

Purpose
This file is the short on-ramp for new agents. Read this instead of scanning the whole repo.

Read Order (new agents)
1. `docs/AGENT_CONTEXT.md` (this file)
2. `docs/AGENT_HANDOFF.md` for known issues and constraints
3. `docs/AGENT_SKILLS.md` for default skill set
4. `TASKS.md` for current task list
5. `docs/architecture.md` for system overview
6. `docs/api-spec.yaml` for API contract
7. `docs/erd.md` for data model
8. `README.md` for product scope

Tech Stack
- Backend: NestJS 10, TypeScript, Prisma, PostgreSQL, Redis (optional)
- Mobile: Flutter 3, Riverpod, GoRouter, Dio
- Realtime: Socket.io (/chat, /location)
- Maps: OpenStreetMap + backend routing APIs (`/v1/trips/route-preview`, `/v1/routes/estimate`)
- Routing engine: OSRM (self-host, TR-only dataset in `backend/.data/osrm`)
- Location autocomplete: Nominatim (Turkey-only suggestions)
- Ops: Docker Compose, Nginx

Product identity
- Brand/app name: `Yoliva`
- Official logo family: `Soft Curve` (`mobile/assets/branding/yoliva`)
- Product platforms: Web + Android + iOS (desktop app is out of scope)

Admin: /v1/admin (x-admin-key)

Key Paths
- Location gateway: `backend/src/interfaces/websocket/location.gateway.ts`
- Admin module: `backend/src/interfaces/http/admin`
- Backend entry: `backend/src/main.ts`
- Backend modules: `backend/src/interfaces/http/*`
- Services: `backend/src/application/services/*`
- DTOs: `backend/src/application/dto/*`
- Prisma schema: `backend/prisma/schema.prisma`
- Mobile router: `mobile/lib/core/router/app_router.dart`
- Mobile API client: `mobile/lib/core/api/api_client.dart`
- Mobile providers: `mobile/lib/core/providers/*`
- Routing provider abstraction: `backend/src/infrastructure/maps/*`

API Basics
- Global API prefix: `/v1`
- Swagger (non-prod): `/api/docs`
- Health: `/v1/health`
- Auth OTP: `POST /auth/send-otp`, `POST /auth/verify-otp` (returns tokens)
- Device token: `POST /users/me/device-token` (stored under user preferences)
- Guest browsing rule: mobile/web can browse home/search/trip-detail without login; reservation/protected routes require auth and redirect via `next` query.

Agent Workflow
- Log every change set in `docs/AGENT_LOG.md` using `scripts/agent-log.ps1`.
- Update this file only for new system-wide facts. Do not duplicate known issues from `docs/AGENT_HANDOFF.md`.
- After each work session, append to the long-form summary in `docs/AGENT_HANDOFF.md` (Conversation summary) so new agents can continue without rereading the repo.
- Bootstrap helper: `scripts/agent-setup.ps1` (installs all curated skills, syncs into repo).
- Skill sync helper: `scripts/skills-sync.ps1` (copies global skills into `.codex/skills`).

Project Delivery Rules (mandatory)
1. Definition of Done: a task is not done until code, relevant tests, and docs are updated, and `docs/AGENT_LOG.md` is appended.
2. API changes: if an endpoint, DTO, or response shape changes, update `docs/api/OPENAPI_SPEC.yaml` and the affected mobile/backend callers in the same change set.
3. Database changes: if `backend/prisma/schema.prisma` changes, include a Prisma migration and note rollback expectations in handoff notes.
4. Breaking changes: gate with feature flags or route versioning (for example `/v2`); do not silently break existing clients.
5. Test minimum: backend changes must include at least one relevant unit or e2e test update/addition.
6. Commit message format: use `feat|fix|chore|docs(scope): message`.
7. Security baseline: never commit secrets; mask tokens/PII in logs and debug output.
8. Handoff freshness: after each session, update `docs/AGENT_HANDOFF.md` conversation summary and keep the latest commit hash accurate.
9. CI gate: do not merge to `master` unless lint, tests, and typecheck pass.
10. Operations: production bug fixes should include a runbook note/update in `docs/runbooks.md`.

Project Skills
- Default list: `docs/AGENT_SKILLS.md`
- Repo `.codex/skills` contains all global skills (synced).





