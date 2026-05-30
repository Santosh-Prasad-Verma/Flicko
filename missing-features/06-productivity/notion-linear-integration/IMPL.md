# Notion / Linear Integration — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec + provider research | 3d | PM |
| 1 | Migration 166 + models + envelope encryption | 3d | Backend |
| 2 | Linear client + OAuth + webhook | 5d | Backend |
| 3 | Notion client + OAuth + poller + webhook | 5d | Backend |
| 4 | Normalizer + Mapper + ReverseSyncWorker | 5d | Backend |
| 5 | Mobile/web admin UI for install + mappings | 5d | Mobile/Web |
| 6 | Backfill engine + progress UI | 3d | Both |
| 7 | QA, security review, load | 4d | QA/Sec |
| 8 | Beta -> GA | 28d | All |

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/166_integrations.up.sql`
- [ ] Down migration
- [ ] Envelope encryption helper (KMS or libsodium)
- [ ] Models for `integrations`, `integration_mappings`, `integration_links`, `integration_audit`, `integration_outbox`
- [ ] Linear GraphQL client + OAuth flow + webhook subscription mgmt
- [ ] Notion REST client + OAuth flow + DB poller
- [ ] Webhook verification middleware (HMAC + bearer)
- [ ] Normalizer: external event -> canonical Task patch
- [ ] Mapper: route patch to mapping/channel
- [ ] Backfill engine with progress + pause
- [ ] ReverseSyncWorker batching outbox
- [ ] Token refresh scheduler
- [ ] Handlers: oauth_handler, webhook_handler, config_handler
- [ ] Wire routes
- [ ] Audit log entries
- [ ] Prometheus counters
- [ ] OpenAPI doc update
- [ ] Tests: webhook fuzz, idempotency, conflict resolution, token refresh

## 3. Mobile Tasks

- [ ] Folder `mobile/lib/features/productivity/integrations/`
- [ ] Settings entry
- [ ] Connector list + detail screens
- [ ] Mapping editor
- [ ] OAuth handoff to system browser; deep link return
- [ ] Audit log view
- [ ] L10n
- [ ] Tests

## 4. AI / Infra Tasks

- [ ] KMS key configured for envelope encryption
- [ ] Provider OAuth apps created (Linear public, Notion private)
- [ ] Webhook URLs registered on health-checked DNS

## 5. Files Touched

```
backend/
  internal/services/integrations/
    linear/{client,oauth,webhook,types}.go
    notion/{client,oauth,poller,webhook,types}.go
    normalizer.go
    mapper.go
    reverse_sync_worker.go
    encryption.go
  internal/handlers/integrations/
    oauth_handler.go
    webhook_handler.go
    config_handler.go
  internal/models/integration.go
  internal/repo/integration_repo.go
  cmd/server/main.go                       (edit)
  api/openapi.yaml                         (edit)
mobile/lib/features/productivity/integrations/...
mobile/lib/core/router/app_router.dart    (edit)
mobile/lib/l10n/app_en.arb                (edit)
supabase/migrations/166_integrations.up.sql
supabase/migrations/166_integrations.down.sql
```

## 6. Test Plan

- Unit: 80% on integrations package
- Integration: full flow Linear webhook -> task created
- Contract tests against provider sandbox (Linear and Notion)
- Backfill perf: 1000 items/min target
- Security: token at rest encrypted, signature verification fuzz
- Load: 100 webhook events/sec sustained

## 7. Rollout & Feature Flags

- Flag `feature.notion_linear_integration.enabled`
- Server-level allowlist during beta
- 1% -> 10% -> 50% -> 100% over 28d
- Kill switch revokes webhooks

## 8. Rollback Plan

1. Flip flag -> UI hides, webhooks return 410
2. Revoke webhook subscriptions
3. Pause poller and reverse worker
4. Tables stay; tokens encrypted

## 9. Dependencies / Blockers

- Depends on: tasks (must exist), audit-log, secrets/KMS
- External: Linear and Notion OAuth app review (lead time 1-2 weeks)

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| OAuth review delay | M | M | start early; dev mode while waiting |
| Token leak | L | H | KMS + rotation + audit |
| Sync loop | L | H | idempotency keys; outbox dedup |
| Provider rate limit | M | M | bucketed queue + backoff |
| Bad mapping deletes data | L | M | dry-run mode; soft archive only |

## 11. Cost Model

| Component | Free tier | $ at 100k DAU |
|-----------|-----------|----------------|
| Compute | Railway free | $5/mo |
| KMS | AWS | $1/mo |
| DB | Supabase | $0 |
| **Total** | | **~$6/mo** |

## 12. Done Definition

- [ ] All tasks checked
- [ ] Security review passed
- [ ] Provider apps approved
- [ ] Beta NPS >= 25
- [ ] Zero P0 in 14 days
