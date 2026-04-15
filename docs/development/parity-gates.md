# Parity Delivery Gates (X1–X3)

> **Audience:** Backend + Platform Engineers · **Last Updated:** 2026-04-15

This document defines cross-phase delivery gates for Discord parity execution.

## X1 — Contract Gate (WS + REST compatibility)

Contract compatibility is enforced by automated tests:

- `TestParityRESTContractRoutesPresent`
- `TestParityWSContractDomainsPresent`

Run:

```bash
cd backend && go test ./internal/handlers -run Parity
```

These checks guard critical parity routes and WS schema-domain/version alignment.

## X2 — Security Review Gate (auth, activities, bot installs)

Every PR touching auth/activity/app-install surfaces must pass:

1. **Auth/authorization review**
   - Endpoint access control validated.
   - User-scoped writes enforce identity ownership.
2. **RLS and policy review**
   - New public tables enable RLS.
   - Explicit SELECT/INSERT/UPDATE/DELETE policies are defined.
3. **Input and abuse review**
   - Request payload validation exists.
   - Idempotency/duplicate-write protections exist where applicable.

Required validation commands:

```bash
cd services && make vet && make test && make build
cd ../backend && go test ./...
```

## X3 — Performance Budget Gate (high-fanout + activity sessions)

Budget guardrails:

- **Realtime message latency (P95):** `< 500ms`
- **HTTP 5xx rate:** `< 1%` over rolling 5m windows for alerting
- **WS connection pressure warning:** trigger when active connections exceed 5000
- **Pub/Sub drop rate:** must remain at `0` in steady-state

These are monitored by existing alert rules in `monitoring/alerts.yml`:

- `HighMessageLatency`
- `HighErrorRate`
- `HighWSConnections`
- `PubSubDrops`

If any budget alert is sustained during rollout, deployment is treated as blocked until mitigated.
