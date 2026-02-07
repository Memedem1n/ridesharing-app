---
name: ridesharing-ops
description: Ops and deployment config for ridesharing-app. Use when editing Docker Compose, nginx, environment variables, health checks, or deployment runbooks.
---

# Ridesharing Ops

## Overview
Use this skill for changes under `docker-compose*.yml`, `nginx/`, or operational docs.

## Workflow
1. Read `docs/AGENT_CONTEXT.md` and `docs/ops/RUNBOOKS.md`.
2. Keep health check paths aligned with `/v1/health`.
3. Update runbooks if operational behavior changes.
4. Log the work with `scripts/agent-log.ps1`.

## Key Paths
- Dev compose: `docker-compose.yml`
- Prod compose: `docker-compose.prod.yml`
- Nginx: `nginx/nginx.conf`
- Runbooks: `docs/runbooks.md`, `docs/ops/RUNBOOKS.md`