---
name: ridesharing-agent-log
description: Agent workflow logging for ridesharing-app. Use when starting work, finishing work, or handing off tasks; updates AGENT_CONTEXT and AGENT_LOG.
---

# Ridesharing Agent Log

## Overview
Use this skill to keep project context and work logs up to date so new agents do not reread the entire repo.

## Required Actions
1. Read `docs/AGENT_CONTEXT.md` before making changes.
2. After each change set, append an entry to `docs/AGENT_LOG.md` using `scripts/agent-log.ps1`.
3. If you discover new system-wide facts or mismatches, update `docs/AGENT_CONTEXT.md`.

## Logging Command
Use:
`powershell -File scripts/agent-log.ps1 -Level agent -Agent <name> -Task <short> -Summary <short> -Commands <cmd1;cmd2> -Files <file1,file2> -Notes <optional>`

For sub-agents, set `-Level sub-agent` and include the parent task in `-Notes`.