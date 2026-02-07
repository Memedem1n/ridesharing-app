# Documentation

Technical documentation for Paylaşımlı Yolculuk Platformu.

## 📚 Index

| Document | Description |
|----------|-------------|
| [API Spec](api-spec.yaml) | OpenAPI 3.1 specification |
| [Architecture](architecture.md) | System architecture diagrams |
| [ERD](erd.md) | Database entity relationships |
| [ADRs](decisions/) | Architecture Decision Records |
| [Runbooks](runbooks.md) | Operational guides |
| [Agent Handoff](AGENT_HANDOFF.md) | Technical context for future agents |
| [Agent Context](AGENT_CONTEXT.md) | Quick on-ramp and key paths |
| [Agent Skills](AGENT_SKILLS.md) | Default skill set for this repo |
| [Agent Log](AGENT_LOG.md) | Ongoing work log and command history |
| [Task Fork Pack](TASK_FORKS.md) | Fork prompts and skill mapping |

## 🔗 Quick Links

- **Swagger UI**: `http://localhost:3000/api/docs`
- **Health Check**: `http://localhost:3000/v1/health`
- **Task Fork Pack**: `TASK_FORKS.md`

## Recent changes (2026-02-07)
- Turkey-only location autocomplete for trip search/create.
- Trip creation stores departure/arrival address + coordinates.
- Trip detail shows an address fallback when missing.

## 📝 Updating Documentation

1. Edit files in this `docs/` folder
2. Update this README if adding new documents
3. Use conventional commit: `docs: update [doc-name]`
