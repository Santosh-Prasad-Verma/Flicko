# Server Feed Timeline — Technical Requirements

## 1. Architecture Overview

```
                      +------------------+
                      |  Mobile (Flutter)|
                      +---------+--------+
                                |
                  GET /api/v1/servers/:id/feed
                                |
                                v
+-------------------+   +-------+--------+   +-------------------+
| Centrifugo        |<--+  Go Backend    +-->|  Redis (cache)    |
|  feed:<server_id> |   |  feed_service  |   |  feed:<id>:page:N |
+-------------------+   +-------+--------+   +-------------------+
                                |
            +-------------------+-------------------+
            |                   |                   |
            v                   v                   v
   +-----------------+ +------------------+ +------------------+
   | Postgres        | | NATS             | | Backfill Worker  |
   | feed_items      | | flicko.feed.*    | | (cron + listener)|
   +-----------------+ +------------------+ +------------------+
```

A backfill worker reads source events (announcement messages, forum posts, scheduled events, high-vote messages) and inserts denormalized rows into `feed_items`. Read path is cache-then-DB. Mutations publish to NATS, fanned out to Centrifugo.

## 2. Components

### Backend (Go)
- **Service:** `backend/internal/services/social/server-feed-timeline/service.go`
- **Handlers:** `backend/internal/handlers/social/feed_handler.go`
- **Models:** `backend/internal/models/social/feed_item.go`
- **Workers:** `backend/internal/services/social/server-feed-timeline/backfill.go` and `ranker.go`
- **Repo layer:** `backend/internal/repo/social/feed_repo.go`

### Mobile (Flutter)
- **Feature folder:** `mobile/lib/features/social/server-feed-timeline/`
  - `data/`: `feed_repository.dart`, `feed_dto.dart`, `feed_remote_source.dart`
  - `domain/`: `feed_item.dart`, `feed_filter.dart`, `usecases/`
  - `application/`: `feed_provider.dart`, `feed_unread_provider.dart`
  - `presentation/`: `feed_screen.dart`, `widgets/feed_card.dart`, `widgets/catch_up_banner.dart`

### Infra
- DB: Supabase Postgres, table `feed_items`, migration 190
- Realtime: Centrifugo channel `feed:<server_id>`
- Cache: Redis keys `feed:<server_id>:page:<n>` TTL 60s; `feed:unread:<user_id>:<server_id>` TTL 24h
- Queue: NATS subjects `flicko.feed.created`, `flicko.feed.pinned`, `flicko.feed.hidden`
- Ranking: simple weighted score `(votes * 2) + (replies * 3) + (recency_decay)` computed in `ranker.go`

## 3. API Contracts

### REST
```
GET    /api/v1/servers/:server_id/feed?tab=top|new|foryou&cursor=&limit=20
GET    /api/v1/servers/:server_id/feed/unread
POST   /api/v1/servers/:server_id/feed/:item_id/pin
POST   /api/v1/servers/:server_id/feed/:item_id/unpin
POST   /api/v1/servers/:server_id/feed/:item_id/hide
POST   /api/v1/servers/:server_id/feed/mark-read   { "up_to": "2026-05-29T00:00:00Z" }
GET    /api/v1/servers/:server_id/feed/analytics    (owner only)
```

### WebSocket / Centrifugo
- Channel: `feed:<server_id>`
- Events: `feed.item.created`, `feed.item.updated`, `feed.item.pinned`, `feed.item.removed`

### Payloads
```jsonc
// Feed item
{
  "id": "uuid",
  "server_id": "uuid",
  "kind": "announcement|forum_post|event|top_message|owner_pin",
  "source_id": "uuid",
  "source_channel_id": "uuid|null",
  "author_id": "uuid",
  "title": "string",
  "preview": "string up to 240",
  "media_urls": ["string"],
  "vote_score": 12,
  "reply_count": 4,
  "score": 0.87,
  "pinned": false,
  "created_at": "iso8601",
  "expires_at": "iso8601|null"
}
```

## 4. Permissions & Auth

- `feed.read` granted to any server member (RLS enforces server membership)
- `feed.pin` and `feed.hide` require `MANAGE_FEED` (subset of MANAGE_SERVER)
- `feed.analytics` requires server owner or admin
- All endpoints behind `requireServerMember` middleware

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| p50 latency | <80 ms |
| p99 latency | <250 ms |
| Throughput | 1000 rps per region |
| Availability | 99.9% |
| Storage cost | <$0.0008 per user/month |
| Compute cost | <$0.00002 per call |
| GDPR | EU shard for EU servers |

## 6. Dependencies

- Existing services: `messages`, `forum`, `events`, `votes` (the new global vote feature)
- New libraries: none beyond existing
- External APIs: none

## 7. Observability

- Metrics: `flicko_feed_item_created_total`, `flicko_feed_view_seconds`, `flicko_feed_ranker_duration_seconds`
- Logs: structured JSON `event=feed.* server_id user_id item_id`
- Traces: OTel spans wrapping handler -> service -> repo -> redis
- Dashboards: Grafana board `social-feed`

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| Backfill worker lag | new items missing | NATS replay; max-lag alert at 60s |
| Redis down | extra DB load | direct DB read + tighter rate limit |
| Ranker bug producing 0 scores | empty Top tab | fall back to chronological |
| Hot server flood | feed dominated | per-author rate cap 3/day; owner can override |
