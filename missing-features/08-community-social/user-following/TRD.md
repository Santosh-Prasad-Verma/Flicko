# User Following — Technical Requirements

## 1. Architecture Overview

```
+------------------+   POST /follows    +-------------------+
|  Mobile (Flutter)| -----------------> |  Go Backend       |
+------------------+                    |  follow_service   |
                                        +---------+---------+
                                                  |
                +------------------+              v
                |  Centrifugo      |   +-----------------+
                |  user:<uid>      |   |   Postgres      |
                +------------------+   |  follows + ...  |
                          ^            +--------+--------+
                          |                     |
                          |                     v
                          |            NATS flicko.follows.*
                          |                     |
                          |                     v
                          |            +-------------------+
                          +----------- |  Fanout worker    |
                                       |  home_feed builder|
                                       +-------------------+
```

When a followed user posts a public blog post or top-vote message, a fanout worker writes denormalized rows into followers' `home_feed_items` (push-on-write, capped at 5k followers; pull-on-read for the long tail).

## 2. Components

### Backend (Go)
- **Service:** `backend/internal/services/social/user-following/service.go`
- **Fanout worker:** `backend/internal/services/social/user-following/fanout.go`
- **Handlers:** `backend/internal/handlers/social/follow_handler.go`
- **Models:** `backend/internal/models/social/follow.go`
- **Repo layer:** `backend/internal/repo/social/follow_repo.go`

### Mobile (Flutter)
- **Feature folder:** `mobile/lib/features/social/user-following/`
  - `data/`: dto, repository, datasource
  - `domain/`: follow entity, settings, counts
  - `application/`: follow_provider, home_feed_provider
  - `presentation/`: home_feed_screen, profile_follow_button, followers_list_screen, requests_screen

### Infra
- DB: tables in migration 193
- Realtime: Centrifugo `user:<uid>` per-user channel
- Cache: Redis follower sets
- Queue: NATS subjects `flicko.follows.created`, `flicko.follows.deleted`, `flicko.posts.created`

## 3. API Contracts

### REST
```
POST   /api/v1/users/:id/follow
DELETE /api/v1/users/:id/follow
PATCH  /api/v1/users/:id/follow            { "notify_level": "highlights" }
POST   /api/v1/users/:id/follow/accept
POST   /api/v1/users/:id/follow/decline
GET    /api/v1/users/:id/followers
GET    /api/v1/users/:id/following
GET    /api/v1/me/home-feed?cursor=&limit=20
PATCH  /api/v1/me/follow-settings
```

### WebSocket / Centrifugo
- Channel: `user:<uid>`
- Events: `follow.created`, `follow.accepted`, `follow.removed`, `home_feed.new`

### Payloads
```jsonc
{
  "follower_id": "uuid",
  "followee_id": "uuid",
  "status": "accepted",
  "notify_level": "highlights",
  "mutual": true,
  "created_at": "iso8601"
}
```

## 4. Permissions & Auth

- Cannot follow self (DB check)
- Cannot follow blocked users (RLS)
- Cannot follow users with `followable=false`
- Approval flow when `require_approval=true`

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| p50 follow action | <80 ms |
| Home feed read p50 | <120 ms |
| Fanout p99 | <2s for 5k followers |
| Throughput | 500 follow rps |
| Storage | <$0.0008 per user/mo |

## 6. Dependencies

- `users`, `user_blocks`, `messages`
- Sibling: `user-blog-posts` for source of feed entries

## 7. Observability

- Metrics: `flicko_follows_created_total`, `flicko_home_feed_fanout_seconds`
- Logs: structured per follow event
- Traces: OTel
- Dashboards: `social-following`

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| Fanout worker lag | stale home feed | NATS replay, lag alert |
| Hot influencer with 50k followers | fanout storm | switch to pull-on-read above 5k |
| Block bypass via stale cache | unwanted follow | invalidate Redis on block |
