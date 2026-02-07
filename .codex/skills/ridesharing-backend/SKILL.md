---
name: ridesharing-backend
description: Backend work for ridesharing-app (NestJS + Prisma). Use when modifying API controllers, DTOs, services, Prisma schema/migrations, health checks, uploads, WebSocket gateway, or backend tests.
---

# Ridesharing Backend

## Overview
Use this skill for any change under `backend/` or when the backend API contract changes. Keep changes minimal and follow the existing Clean Architecture layout.

## Workflow
1. Read `docs/AGENT_CONTEXT.md` and `docs/AGENT_HANDOFF.md` first.
2. Identify the module path under `backend/src/interfaces/http/*` and its service under `backend/src/application/services/*`.
3. Update DTOs in `backend/src/application/dto/*` before touching service/controller code.
4. If data changes are needed, update `backend/prisma/schema.prisma` and plan migrations.
5. If new docs are added under `docs/`, update `docs/README.md`.
6. Log the work with `scripts/agent-log.ps1`.

## Key Paths
- API controllers: `backend/src/interfaces/http`
- Services: `backend/src/application/services`
- DTOs: `backend/src/application/dto`
- Prisma: `backend/prisma/schema.prisma`
- Health: `backend/src/interfaces/http/health/health.controller.ts`
- Uploads: `backend/src/interfaces/http/uploads`
- WebSocket: `backend/src/interfaces/websocket/chat.gateway.ts`

## Rules
- Domain layer (`backend/src/domain`) must stay framework-free.
- Global API prefix is `/v1` (see `backend/src/main.ts`).
- Prefer updating tests in `backend/test` when behavior changes.

## Notes
- Many mobile/backend mismatches are tracked in `docs/AGENT_CONTEXT.md`.
- Use the `playwright` and `security-best-practices` skills when relevant.