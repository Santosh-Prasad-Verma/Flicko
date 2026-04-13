# Development Overview

> **Reading time:** ~4 minutes · **Audience:** Everyone · **Last Updated:** 2026-04-11

Welcome to the internal Development guide. This section provides the workflows necessary to compile, run, and actively contribute to the Flicko codebase.

---

## Monorepo Workflow

Because Flicko is a monorepo, a developer modifying a struct in the Go backend can immediately map it to the TypeScript interfaces in the mobile app without coordinating pull requests across different repositories.

If you are a Full-Stack developer contributing a new feature (e.g. `Read Receipts`), your workflow will span the entire stack:
1. **Migrations:** Creating the `read_states` table in PostgreSQL.
2. **Backend:** Modifying `msg-service` to process read hashes.
3. **Frontend:** Updating `messageStore.ts` to reveal a double-check UI icon.

---

## Required Tooling

Before proceeding, ensure you have the required prerequisites installed on your local machine. Refer to the [Getting Started: Prerequisites](../getting-started/prerequisites.md) list.

### Quick Verification Checklist:
- `docker` and `docker compose`
- `go version 1.22+`
- `node version 20+` (LTS)
- `npx supabase -v` (Supabase Local CLI)

---

## Directory Navigation

- **[Local Setup & Execution](local-setup.md)**: How to boot the 3 backend services and the mobile app on your laptop simultaneously.
- **[Code Style & Linting](code-style.md)**: Formatting rules required to pass GitHub Actions CI checks.
- **[Database Migrations](database-migrations.md)**: How to make changes to the PostgreSQL schema securely.
- **[Debugging Workflows](debugging.md)**: How to trace errors from the mobile React tree all the way through to the Go debugger (`delve`).
