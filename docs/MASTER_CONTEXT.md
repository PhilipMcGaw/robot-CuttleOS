# Master Context (Consolidated at Root Level)

This document has been consolidated into the root-level [MASTER_CONTEXT.md](../MASTER_CONTEXT.md) for centralized maintenance across all services.

## Redirect Notice

**Please refer to:** [../MASTER_CONTEXT.md](../MASTER_CONTEXT.md)

The consolidated Master Context document includes:
- Cockpit (operator interface)
- Control (hardware and safety)
- Datalogger (telemetry recording)
- Shared architecture and deployment

## Why Consolidated?

With the consolidation of the three separate ROV repositories into a single monorepo (robot-CuttleOS), maintaining a single authoritative Master Context document reduces duplication and keeps architectural decisions synchronized across all services.

## Sections in Root MASTER_CONTEXT.md

- **Overview** — Introduction to the monorepo
- **Part I: Cockpit** — Operator interface service
- **Part II: Control** — Hardware control and safety service
- **Part III: Datalogger** — Telemetry recording service
- **Shared Architecture** — NATS, profiles, deployment
- **Development & Testing** — Testing stages and principles
- **Status discipline** — Documentation standards

---

*Last consolidated: 29 August 2026*
*Legacy content from:*
- *docs/MASTER_CONTEXT.md (Cockpit)*
- *control/MASTER_CONTEXT.md (Control)*
- *datalogger/MASTER_CONTEXT.md (Datalogger)*
