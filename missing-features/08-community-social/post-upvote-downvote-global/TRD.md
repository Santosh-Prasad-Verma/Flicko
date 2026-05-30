# Post Upvote/Downvote Global — Technical Requirements

## 1. Architecture Overview

```
+------------------+       POST /votes        +-----------------+
|  Mobile (Flutter)| -----------------------> |  Go Backend     |
+------------------+                          |  vote_service   |
        ^                                     +--------+--------+
        |                                              |
        |         Centrifugo                            v
        +---  votes:<channel_id>  <-------+   +-------------------+
                                          |   |  Postgres votes   |
                                          |   +---------+---------+
                                          |             |
                                          |             v
                                          |   +-------------------+
                                          +---+  Redis dedup +    |
                                              |  rate limiter     |
                                              +-------------------+
                                                        |
                                                        v
                                              NATS flicko.votes.*
```

Vote casts are written to `votes` (unique per `(user_id, target_kind, target_id)`), denormalized counts updated on `messages` and `forum_posts`. Anti-abuse runs in `brigade_guard.go`. Realtime updates publish to `votes:<channel_id>`.

## 2. Components

### Backend (Go)
- **Service:** `backend/internal/services/social/post-upvote-downvote-global/service.go`
- **Brigade guard:** `backend/internal/services/social/post-upvote-downvote-global/brigade_guard.go`
- **Handlers:** `backend/internal/handlers/social/votes_handler.go`
- **Models:** `backend/internal/models/social/vote.go`
- **Repo layer:** `backend/internal/repo/social/vote_repo.go`

### Mobile (Flutter)
- **Feature folder:** `mobile/lib/features/social/post-upvote-downvote-global/`
  - `data/`: `vote_repository.dart`, `vote_dto.dart`
  - `domain/`: `vote.dart`, `vote_target.dart`
  - `application/`: `vote_provider.dart`
  - `presentation/`: `widgets/vote_arrows.dart`, `widgets/vote_count.dart`

### Infra
- DB: Supabase Postgres, table `votes`, migration 191
- Realtime: Centrifugo channel `votes:<channel_id>`
- Cache: Redis keys `vote:user:<u>:target:<t>` TTL 60s, dedup
- Rate limiter: Redis token bucket keyed by user
- Queue: NATS subjects `flicko.votes.cast`, `flicko.votes.retracted`, `flicko.votes.threshold`

## 3. API Contracts

### REST
```
POST   /api/v1/votes
  body: { "target_kind": "message|forum_post", "target_id": "uuid", "value": 1|-1 }
DELETE /api/v1/votes/:target_kind/:target_id
GET    /api/v1/votes/:target_kind/:target_id     -> { score, my_vote }
GET    /api/v1/channels/:id/votes/audit          (mod only)
PATCH  /api/v1/channels/:id/settings             { "votes_enabled": true }
```

### WebSocket / Centrifugo
- Channel: `votes:<channel_id>`
- Events: `vote.score.updated` payload `{ target_id, score, my_vote? }`

### Payloads
```jsonc
// Cast request
{ "target_kind": "message", "target_id": "uuid-of-msg", "value": 1 }

// Cast response
{ "target_id": "uuid", "score": 3, "my_vote": 1, "rate_limited": false }
```

## 4. Permissions & Auth

- Cast requires authenticated session and server membership
- Mod audit requires `MANAGE_MESSAGES`
- Channel toggle requires `MANAGE_CHANNEL`
- Account age >= 24h required to cast (anti-abuse)
- RLS: votes readable only by self plus mods of the server

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| p50 latency | <60 ms |
| p99 latency | <180 ms |
| Throughput | 5000 rps per region |
| Availability | 99.95% |
| Storage | <$0.0003 per user/month |
| Compute | <$0.000005 per call |

## 6. Dependencies

- Existing services: messages, forum, channel_settings
- Libraries: existing rate limiter, Centrifugo client
- External APIs: none

## 7. Observability

- Metrics: `flicko_votes_cast_total`, `flicko_votes_brigade_blocks_total`, `flicko_votes_latency_seconds`
- Logs: structured `event=vote.cast user_id target_kind target_id value channel_id`
- Traces: OTel
- Dashboards: Grafana board `social-votes`

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| Hot row contention on counts | high latency | row-level UPDATE with batched apply via worker |
| Brigade undetected | sad authors | layered checks; mod can re-trigger review |
| Centrifugo lag | stale UI | client refetches on focus |
| Disable-downvote flip mid-session | UI mismatch | server response wins |
