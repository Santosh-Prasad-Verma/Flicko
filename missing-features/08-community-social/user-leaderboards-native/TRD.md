# User Leaderboards Native — Technical Requirements

## 1. Architecture Overview

```
+------------------+    +-------------------+
|  Existing events |--->| NATS              |
|  (message,voice, |    | flicko.* subjects |
|   vote,reaction) |    +---------+---------+
+------------------+              |
                                  v
                       +---------------------+
                       | xp_aggregator       |
                       | - rate cap          |
                       | - rules apply       |
                       | - ledger insert     |
                       +----------+----------+
                                  |
                                  v
                       +---------------------+
                       | xp_balance_updater  |
                       | (every 30s)         |
                       +----------+----------+
                                  |
                                  v
                            xp_balances
                                  |
                                  v
                          REST + Centrifugo
```

Events flow into a single aggregator service that consults `xp_rules`, applies caps, and writes ledger rows. A periodic balance-updater rebuilds materialized aggregates per window. Reads are cache-then-DB.

## 2. Components

### Backend (Go)
- **Service:** `backend/internal/services/social/user-leaderboards-native/service.go`
- **Aggregator:** `backend/internal/services/social/user-leaderboards-native/aggregator.go`
- **Balance updater:** `backend/internal/services/social/user-leaderboards-native/balance_updater.go`
- **Handlers:** `backend/internal/handlers/social/leaderboards_handler.go`
- **Models:** `backend/internal/models/social/xp.go`
- **Repo:** `backend/internal/repo/social/xp_repo.go`

### Mobile (Flutter)
- **Feature folder:** `mobile/lib/features/social/user-leaderboards-native/`
  - `data/`: dto, repo
  - `domain/`: balance, badge, rule
  - `application/`: leaderboard_provider, my_rank_provider
  - `presentation/`: leaderboard_screen, my_rank_card, badges_strip, settings_panel

### Infra
- DB: tables in migration 198
- Realtime: Centrifugo `xp:server:<sid>` for live rank updates
- Cache: Redis lists per window
- Queue: NATS subjects existing

## 3. API Contracts

### REST
```
GET    /api/v1/servers/:id/leaderboard?window=30d|7d|today|all&page=
GET    /api/v1/servers/:id/leaderboard/me
GET    /api/v1/servers/:id/xp/rules
PATCH  /api/v1/servers/:id/xp/rules
POST   /api/v1/servers/:id/xp/season/reset
```

### WebSocket / Centrifugo
- Channel: `xp:server:<sid>`
- Events: `xp.user.updated`, `xp.level.up`, `xp.season.reset`

### Payloads
```jsonc
// Leaderboard entry
{
  "rank": 7,
  "user": {"id":"uuid","handle":"sarah","avatar_url":"..."},
  "xp_30d": 1842,
  "level": 14,
  "delta_rank_24h": -2
}
```

## 4. Permissions & Auth

- View leaderboard: server members
- Edit rules: `MANAGE_SERVER`
- Reset season: `MANAGE_SERVER` with confirmation
- Self balance always visible to self

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| List p50 | <100 ms |
| Aggregator backlog | <5s |
| Throughput | 5000 events/s peak |

## 6. Dependencies

- Existing message, voice, vote events
- NATS, Centrifugo

## 7. Observability

- Metrics: `flicko_xp_events_total`, `flicko_xp_aggregator_lag_seconds`, `flicko_xp_level_up_total`
- Logs: structured per balance update
- Traces: OTel
- Dashboards: `social-leaderboards`

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| Aggregator backlog | stale ranks | autoscale, alert at 5s lag |
| Spam grinding | unfair ranks | per-minute cap, anti-spam classifier later |
| Voice afk inflation | unfair ranks | activity check; require recent audio |
| Rule edit retroactivity | confusion | new rules apply forward only |
