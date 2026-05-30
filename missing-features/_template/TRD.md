# [Feature Name] — Technical Requirements

## 1. Architecture Overview

```
[ASCII or mermaid diagram showing components and data flow]
```

## 2. Components

### Backend (Go)
- **Service:** `internal/services/<feature>/service.go`
- **Handlers:** `internal/handlers/<feature>_handler.go`
- **Models:** `internal/models/<feature>.go`
- **Workers:** `internal/services/<feature>/worker.go` (if async)
- **Repo layer:** `internal/repo/<feature>_repo.go`

### Mobile (Flutter)
- **Feature folder:** `mobile/lib/features/<feature>/`
  - `data/`: repository, dto, datasource
  - `domain/`: entities, usecases
  - `application/`: providers (Riverpod)
  - `presentation/`: screens, widgets

### Infra
- DB: Supabase Postgres (tables in `SCHEMA.md`)
- Realtime: Centrifugo channel `<feature>:<id>` or Supabase Realtime
- Cache: Redis keys `<feature>:<id>` (TTL: __)
- Storage: Appwrite bucket `<feature>` (or R2 if bigger)
- Search: Meilisearch index `<feature>` (if needed)
- AI: Ollama / Groq / Whisper (specify which)
- Queue: NATS subject `flicko.<feature>.*`

## 3. API Contracts

### REST
```
POST   /api/v1/<feature>          create
GET    /api/v1/<feature>/:id      read
PATCH  /api/v1/<feature>/:id      update
DELETE /api/v1/<feature>/:id      delete
```

### WebSocket / Centrifugo
- Channel: `<feature>:<scope-id>`
- Events: `<feature>.created`, `<feature>.updated`, `<feature>.deleted`

### Payloads
```jsonc
// Create request
{ "...": "..." }

// Response
{ "id": "uuid", "...": "..." }
```

## 4. Permissions & Auth

- Required scope: `<feature>.read`, `<feature>.write`
- Role checks: server owner / admin / member / role-X
- RLS policies in `SCHEMA.md`

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| p50 latency | <__ ms |
| p99 latency | <__ ms |
| Throughput | __ rps |
| Availability | 99.9% |
| Storage cost | <$0.__ per user/month |
| Compute cost | <$0.__ per call |
| GDPR/data residency | EU-isolated DB shard if EU user |

## 6. Dependencies

- Existing services: <list>
- New libraries: <list with versions>
- External APIs: <list with quota>

## 7. Observability

- Metrics: Prometheus counters/histograms `flicko_<feature>_*`
- Logs: structured JSON, level INFO, error → Sentry
- Traces: OTel spans wrapping handlers + service calls
- Dashboards: Grafana board `<feature>`

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| AI provider down | feature unavailable | fallback model / cached result |
| DB lag | stale reads | retry + indicator UI |
| ... | ... | ... |
