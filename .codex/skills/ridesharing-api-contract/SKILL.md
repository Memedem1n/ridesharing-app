---
name: ridesharing-api-contract
description: API contract alignment for ridesharing-app. Use when adding or changing endpoints, DTOs, query params, or when syncing backend and mobile models.
---

# Ridesharing API Contract

## Overview
Use this skill to keep backend DTOs/controllers and mobile models/repositories aligned. The backend is the source of truth for routes and payloads.

## Workflow
1. Start from backend DTOs in `backend/src/application/dto/*` and controllers in `backend/src/interfaces/http/*`.
2. Update mobile repositories/providers to match payloads and routes.
3. Update docs if the contract changes: `docs/api/OPENAPI_SPEC.yaml` and/or `docs/api-spec.yaml`.
4. Cross-check query parameter names and response shapes.
5. Log changes with `scripts/agent-log.ps1`.

## Quick Checks
- Search endpoints in mobile: `rg -n "/v1|/auth|/trips|/bookings|/messages|/vehicles|/verification" mobile/lib`
- Search DTOs in backend: `rg -n "class .*Dto" backend/src/application/dto`

## Known Issues
See `docs/AGENT_CONTEXT.md` for current mismatches that need alignment.