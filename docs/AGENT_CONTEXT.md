# Agent Context (ridesharing-app)

Last updated: 2026-02-07

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
- Maps: OpenStreetMap + OSRM
- Location autocomplete: Nominatim (Turkey-only suggestions)
- Ops: Docker Compose, Nginx

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

API Basics
- Global API prefix: `/v1`
- Swagger (non-prod): `/api/docs`
- Health: `/v1/health`
- Auth OTP: `POST /auth/send-otp`, `POST /auth/verify-otp` (returns tokens)
- Device token: `POST /users/me/device-token` (stored under user preferences)

Agent Workflow
- Log every change set in `docs/AGENT_LOG.md` using `scripts/agent-log.ps1`.
- Update this file only for new system-wide facts. Do not duplicate known issues from `docs/AGENT_HANDOFF.md`.
- Bootstrap helper: `scripts/agent-setup.ps1` (installs all curated skills, syncs into repo).
- Skill sync helper: `scripts/skills-sync.ps1` (copies global skills into `.codex/skills`).

Project Skills
- Default list: `docs/AGENT_SKILLS.md`
- Repo `.codex/skills` contains all global skills (synced).





