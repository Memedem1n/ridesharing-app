---
name: ridesharing-mobile
description: Mobile work for ridesharing-app (Flutter + Riverpod + GoRouter). Use when updating UI screens, providers, repositories, models, routing, theme, or API client usage under `mobile/`.
---

# Ridesharing Mobile

## Overview
Use this skill for any Flutter/UI, state management, or mobile API integration changes.

## Workflow
1. Read `docs/AGENT_CONTEXT.md` for current API mismatches and key screens.
2. Update models and repositories before changing UI screens.
3. Keep API calls aligned with backend DTOs and routes.
4. If you add new docs, update `docs/README.md`.
5. Log the work with `scripts/agent-log.ps1`.

## Key Paths
- Router: `mobile/lib/core/router/app_router.dart`
- API client: `mobile/lib/core/api/api_client.dart`
- Providers: `mobile/lib/core/providers/*`
- Features: `mobile/lib/features/*`
- Theme: `mobile/lib/core/theme/app_theme.dart`

## Rules
- Keep Riverpod providers as the single source of state.
- Avoid creating duplicate screens; reuse existing ones in `app_router.dart`.
- Ensure endpoints and payloads match backend expectations.

## Notes
- Known mobile/backend mismatches are tracked in `docs/AGENT_CONTEXT.md`.