# Game Stats Integration — TRD

## Architecture
```
OAuth flow per provider → tokens encrypted at rest → stats worker
  ↓ Redis token-bucket per provider
fetcher → normalize → Postgres (game_stats_snapshots) → Centrifugo
  ↓
profile widgets / role assigner
```

## Components
- Backend: `backend/internal/services/gaming/stats/{oauth,fetcher,normalizer,role_assigner}.go`
- Per-provider adapters under `stats/providers/{riot,steam,xbox,psn,bnet}.go`.
- Handler: `stats_handler.go` — POST /me/game-accounts (OAuth code), DELETE /me/game-accounts/:id, GET /users/:id/game-stats.
- Worker: cron 6h + on-demand (rate-limited).
- Existing `connected_account_service` to extend.

## API
```
POST /oauth/<provider>/start  → authorize_url
POST /oauth/<provider>/callback {code}
GET  /me/game-accounts
DELETE /me/game-accounts/:id
GET  /users/:id/game-stats?provider=riot
```

## NFRs
| NFR | Target |
|-----|--------|
| OAuth round-trip | <8s |
| Stats refresh | every 6h scheduled, ≤1× / 5min on-demand |
| Token storage | encrypted at rest (libsodium key in Doppler) |

## Observability
- `flicko_stats_oauth_total{provider, status}`
- `flicko_stats_fetch_seconds{provider}`
- `flicko_stats_rate_limited_total{provider}`

## Failure
| Failure | Mitigation |
|---------|------------|
| Provider 429 | back-off; serve cached |
| OAuth refresh expires | re-prompt user with one-tap |
| Provider deprecates | adapter feature flag; surface stale-warning |
