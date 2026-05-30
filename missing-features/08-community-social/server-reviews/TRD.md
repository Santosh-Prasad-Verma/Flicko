# Server Reviews — Technical Requirements

## 1. Architecture Overview

```
+------------------+   POST /reviews   +-------------------+
|  Mobile (Flutter)| ----------------> |  Go Backend       |
+------------------+                   |  reviews_service  |
        ^                              +---------+---------+
        |  GET /reviews                          |
        +------------------------------          |
                                       \         v
                              Centrifugo   +-----------+
                              reviews:<sid>|  Postgres |
                                           |  server_  |
                                           |  reviews  |
                                           +-----+-----+
                                                 |
                                                 v
                                           Materialized
                                           server_review_aggs
                                           (avg, count, dist)
```

Reviews persist in `server_reviews`, aggregates rebuilt on insert/update via trigger and a worker re-checks every 10 minutes for safety. Discovery query reads from materialized aggregates.

## 2. Components

### Backend (Go)
- **Service:** `backend/internal/services/social/server-reviews/service.go`
- **Eligibility:** `backend/internal/services/social/server-reviews/eligibility.go`
- **Handlers:** `backend/internal/handlers/social/server_reviews_handler.go`
- **Models:** `backend/internal/models/social/server_review.go`
- **Repo layer:** `backend/internal/repo/social/server_review_repo.go`

### Mobile (Flutter)
- **Feature folder:** `mobile/lib/features/social/server-reviews/`
  - `data/`: dto, repository, datasource
  - `domain/`: review entity, eligibility result
  - `application/`: provider with paginated cursor
  - `presentation/`: review_list_screen, compose_screen, review_card

### Infra
- DB: `server_reviews`, migration 192
- Realtime: Centrifugo `reviews:<server_id>`
- Cache: Redis keys `reviews:<server_id>:page:<n>:<sort>` TTL 60s
- Aggregate cache: `reviews_agg:<server_id>` TTL 5m

## 3. API Contracts

### REST
```
GET    /api/v1/servers/:id/reviews?sort=helpful|newest|lowest|highest&cursor=&limit=20
GET    /api/v1/servers/:id/reviews/aggregates
GET    /api/v1/servers/:id/reviews/eligibility
POST   /api/v1/servers/:id/reviews
PATCH  /api/v1/servers/:id/reviews/:rid
DELETE /api/v1/servers/:id/reviews/:rid
POST   /api/v1/servers/:id/reviews/:rid/helpful
DELETE /api/v1/servers/:id/reviews/:rid/helpful
POST   /api/v1/servers/:id/reviews/:rid/owner-reply
POST   /api/v1/servers/:id/reviews/:rid/report
```

### WebSocket / Centrifugo
- Channel: `reviews:<server_id>`
- Events: `review.created`, `review.updated`, `review.deleted`, `review.replied`, `review.aggregates`

### Payloads
```jsonc
{
  "id": "uuid",
  "server_id": "uuid",
  "user_id": "uuid",
  "rating": 5,
  "body": "Great community for Rust devs",
  "helpful_count": 12,
  "owner_reply": { "body": "Thanks", "edited_at": null },
  "created_at": "iso8601",
  "edited_at": "iso8601|null"
}
```

## 4. Permissions & Auth

- Create requires server membership >=14 days and >=20 messages
- Edit/delete requires `user_id == auth.uid()` within 30 days
- Owner reply requires server owner role
- Report visible to mods
- Public read for public servers; member-only read for private servers (rare)

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| p50 list latency | <100 ms |
| p99 list latency | <300 ms |
| Throughput | 200 rps |
| Availability | 99.9% |
| Storage | <$0.0002 per user/mo |

## 6. Dependencies

- `server_members`, `messages` for eligibility
- Mod tooling for reports

## 7. Observability

- Metrics: `flicko_reviews_created_total`, `flicko_reviews_helpful_total`, `flicko_reviews_eligibility_blocked_total`
- Logs: structured per event
- Traces: OTel
- Dashboards: `social-reviews`

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| Aggregates drift | wrong stars | nightly recompute, diff alert |
| Brigading | inflated/deflated stars | brigade guard + mod review |
| Hostile reviews | author distress | report flow within 1 tap |
| Owner reply abuse | retaliation | rate-limited; mod-removable |
