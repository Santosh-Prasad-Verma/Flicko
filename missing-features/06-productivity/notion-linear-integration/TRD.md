# Notion / Linear Integration — Technical Requirements

## 1. Architecture Overview

```
   ┌──────────┐                         ┌──────────┐
   │ Linear   │──webhooks──▶  /ingest ──│ Backend  │
   │ Notion   │              webhook    │  Go      │
   └──────────┘                         └────┬─────┘
                                              │
                                              ▼
                                   ┌────────────────────┐
                                   │ NormalizerEvent    │
                                   │ -> Mapper          │
                                   └────────┬───────────┘
                                              ▼
                                   ┌────────────────────┐
                                   │ TaskService.Apply  │
                                   └────────┬───────────┘
                                              ▼
                                   ┌────────────────────┐
                                   │ Postgres tasks +   │
                                   │ integration_links  │
                                   └────────┬───────────┘
                                              ▼
                                   ┌────────────────────┐
                                   │ ReverseSyncWorker  │
                                   │ (Flicko -> ext.)   │
                                   └────────────────────┘
```

## 2. Components

### Backend (Go)
- `services/integrations/linear/client.go` (HTTP client + GraphQL)
- `services/integrations/linear/webhook.go`
- `services/integrations/notion/client.go` (REST)
- `services/integrations/notion/poller.go` (5min DB poll)
- `services/integrations/normalizer.go` (canonical event)
- `services/integrations/mapper.go` (project -> channel rules)
- `services/integrations/reverse_sync_worker.go`
- `handlers/integrations/oauth_handler.go`
- `handlers/integrations/webhook_handler.go`
- `handlers/integrations/config_handler.go`
- `models/integration.go`

### Mobile (Flutter)
- `mobile/lib/features/productivity/integrations/`
  - Connectors list, install flow (opens browser to OAuth), mapping config

### Infra
- DB: Postgres, migration 166
- Encrypted secrets: KMS-wrapped DEK in `integrations.encrypted_token`
- Queue: NATS subjects `flicko.integ.linear.*`, `flicko.integ.notion.*`
- Cron: Notion poller every 5m; secret rotation daily

## 3. API Contracts

### REST (Flicko)
```
GET    /api/v1/integrations                          list per server
POST   /api/v1/integrations/linear/install/start    -> redirect_url
GET    /api/v1/integrations/linear/install/callback
POST   /api/v1/integrations/notion/install/start    -> redirect_url
GET    /api/v1/integrations/notion/install/callback
DELETE /api/v1/integrations/:id                      uninstall
POST   /api/v1/integrations/:id/mappings             create mapping
PATCH  /api/v1/integrations/:id/mappings/:mid
DELETE /api/v1/integrations/:id/mappings/:mid
POST   /api/v1/integrations/:id/backfill             trigger backfill
```

### Webhooks (inbound)
```
POST /webhooks/linear   verify HMAC X-Linear-Signature
POST /webhooks/notion   verify Bearer token (per-connector secret)
```

## 4. Permissions & Auth

- Server admin/owner installs connectors
- Linear OAuth scopes: `read,write` (write only when reverse sync enabled)
- Notion: workspace-level integration with explicit page sharing required
- RLS: only server admins can read connector rows

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| Webhook ingest p99 | <120 ms (then queued) |
| Sync delay p99 | <60 s |
| Backfill rate | 50 items/sec |
| Token rotation | every 60d |

## 6. Dependencies

- Existing: tasks, audit-log, server-members, Centrifugo
- New libraries: `github.com/aws/aws-sdk-go-v2/service/kms` or local libsodium for envelope encryption
- External: Linear OAuth app, Notion integration

## 7. Observability

- `flicko_integ_webhook_total{provider,verb}`
- `flicko_integ_sync_seconds` histogram
- `flicko_integ_token_refresh_total{provider,result}`

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| Webhook signature mismatch | spoof | reject 401, alert |
| Token expired | sync down | refresh; if refresh_token gone, mark needs_reinstall + DM admin |
| Provider rate-limit | sync slow | backoff with jitter; queue depth metric |
| Provider outage | sync paused | DLQ; resume on health check |
| Conflict (both sides changed) | data divergence | external-wins policy; audit warn |
| Field mapping mismatch | partial sync | mapping rule editor + dry run |
| Reverse sync loop | duplicate events | idempotency key `<provider>:<event_id>` UNIQUE |
