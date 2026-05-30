# LFG System — Technical Requirements

## 1. Architecture Overview

```
┌────────────────────┐    ┌──────────────────┐    ┌──────────────┐
│ Mobile (Flutter)   │───▶│ Go Backend       │───▶│ Postgres     │
│ Riverpod providers │    │ /api/v1/lfg/*    │    │ lfg_posts    │
└─────────┬──────────┘    │ + LFGService     │    │ lfg_slots    │
          │               └────────┬─────────┘    └──────────────┘
          │                        │                     │
          │   Centrifugo SSE       │   NATS              │
          ▼                        ▼                     ▼
   lfg:server:<id>         flicko.lfg.expire     Redis cache + lock
                           cron worker (asynq)
```

Flow: client posts → service validates per-game schema → row in `lfg_posts` →
Centrifugo broadcasts to `lfg:server:<id>` and (if public) `lfg:hub:<game_id>`.
On `accept`, service creates ephemeral voice channel via existing `internal/services/voice` and links via `lfg_posts.voice_channel_id`.

## 2. Components

### Backend (Go)
- **Service:** `backend/internal/services/gaming/lfg/service.go`
- **Validator:** `backend/internal/services/gaming/lfg/schema.go` (per-game JSON Schema, embedded via `go:embed`)
- **Handlers:** `backend/internal/handlers/gaming/lfg/handler.go`
- **Models:** `backend/internal/models/lfg.go`
- **Worker:** `backend/internal/services/gaming/lfg/expirer.go` (asynq cron)
- **Repo:** `backend/internal/repo/lfg_repo.go`
- **Wire-up:** extend `backend/internal/gaming/module.go`

### Mobile (Flutter)
- **Feature folder:** `mobile/lib/features/gaming/lfg/`
  - `data/`: `lfg_remote_datasource.dart`, `lfg_repository_impl.dart`, dto classes
  - `domain/`: `lfg_post.dart`, `lfg_slot.dart`, usecases (CreatePost, AcceptSlot, FilterBoard)
  - `application/`: `lfg_board_provider.dart` (StreamProvider over Centrifugo), `lfg_filter_provider.dart`
  - `presentation/`: `lfg_board_screen.dart`, `lfg_compose_sheet.dart`, `lfg_post_card.dart`

### Infra
- DB: Postgres (Supabase) — tables `lfg_posts`, `lfg_slots`, `lfg_games_catalog`
- Realtime: Centrifugo channels `lfg:server:<server_id>` (ACL: server members) and `lfg:hub:<game_id>` (public)
- Cache: Redis `lfg:list:<server_id>` (60s TTL), `lfg:post:<id>` (30s TTL)
- Queue: NATS subject `flicko.lfg.expire` + asynq for periodic sweep
- Voice: reuse existing `internal/services/voice` ephemeral channel API

## 3. API Contracts

### REST
```
POST   /api/v1/gaming/lfg                      create post
GET    /api/v1/gaming/lfg?server_id=&game_id=  list (filtered)
GET    /api/v1/gaming/lfg/:id                  read one
PATCH  /api/v1/gaming/lfg/:id                  update (owner only)
DELETE /api/v1/gaming/lfg/:id                  cancel
POST   /api/v1/gaming/lfg/:id/slots/:slot/accept  fill slot
POST   /api/v1/gaming/lfg/:id/slots/:slot/leave   leave slot
GET    /api/v1/gaming/lfg/games                game catalog
```

### Centrifugo
- Channel: `lfg:server:<server_id>` (presence enabled)
- Channel: `lfg:hub:<game_id>` (cross-server, opt-in posts only)
- Events: `lfg.post.created`, `lfg.post.updated`, `lfg.slot.filled`, `lfg.post.expired`

### Payloads
```jsonc
// Create
{
  "server_id": "uuid",
  "game_id": "valorant",
  "title": "Need duo for ranked",
  "mode": "competitive",
  "filters": {
    "rank_min": "diamond1", "rank_max": "immortal3",
    "region": "na-east", "mic_required": true,
    "agents_wanted": ["sage", "killjoy"]
  },
  "slots_total": 4,
  "expires_at": "2026-05-29T22:00:00Z",
  "cross_server": true
}

// Response
{
  "id": "uuid",
  "voice_channel_id": null,
  "slots_filled": 1,
  "status": "open"
}
```

## 4. Permissions & Auth

- Required scope: `lfg.read`, `lfg.write`
- Members of server can read; only members can post; cross-server hub only reads public posts.
- Server admin can configure `lfg_enabled`, `lfg_max_per_user_per_hour`, `lfg_default_voice_size`.
- RLS policies in `SCHEMA.md`.

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| p50 list latency | <90 ms |
| p99 list latency | <250 ms |
| Realtime fanout | <800 ms post→subscriber |
| Throughput | 500 rps create burst |
| Availability | 99.9% |
| Storage cost | <$0.001/user/month |
| GDPR | EU shard via existing region routing |

## 6. Dependencies

- Existing `internal/services/voice` for channel creation
- Existing Centrifugo setup
- New Go libs: `github.com/santhosh-tekuri/jsonschema/v5` (BSD-2)
- Game-stats-integration (rank verification) — optional, soft-fail if absent

## 7. Observability

- Prometheus: `flicko_lfg_posts_created_total`, `flicko_lfg_post_fill_seconds` histogram, `flicko_lfg_active_posts` gauge
- Logs: structured JSON, post id + server id + game id correlation
- Traces: OTel spans `lfg.create`, `lfg.accept_slot`, `lfg.expire_sweep`
- Sentry: capture validation errors and voice-channel allocation failures
- Dashboard: Grafana board `gaming-lfg` with fill rate, stale rate, rate-limit hits

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| Voice service unavailable | Slot accept blocked | Queue accept, retry 30s, fall back to "join later" link |
| Centrifugo down | No realtime updates | Fall back to 30s polling on board screen |
| Schema validation regression | Posts rejected | Schema versioned; per-game schema cached in service |
| Spam posts | Board flooded | Rate limit 3/hr/user/game (Redis token bucket); soft-block on heuristic flags |
| Cross-server abuse | Brigading | Posts in hub limited to verified servers (>30 day age + >50 members) |
