# TRD: App & Theme Store

## Architecture
```
+------------------+     +----------------------+
| Mobile / Web     |     | Reviewer Console     |
+--------+---------+     +-----------+----------+
         |  REST                     |  REST + WS
         v                           v
+------------------------------------------------+
|  store-api (Go)                                |
|  - listing CRUD                                |
|  - search (Postgres FTS + trigram)             |
|  - purchase orchestrator                       |
|  - review queue                                |
+--------+---------------+-----------------+-----+
         |               |                 |
   +-----v-----+   +-----v------+   +------v------+
   | Postgres  |   | flicko-pay |   | plugin-     |
   | store_*   |   | (Stripe)   |   | registry    |
   +-----------+   +------------+   +-------------+
         |
         v
   +-----------+
   | Supabase  |
   | Storage   |
   | assets    |
   +-----------+
```

## REST Routes
- `GET /api/v1/store/listings?q=&type=&sort=` browse.
- `GET /api/v1/store/listings/:id` detail.
- `POST /api/v1/store/listings` create draft (creator).
- `POST /api/v1/store/listings/:id/submit` submit for review.
- `POST /api/v1/store/listings/:id/review/decision` approve/reject (reviewer).
- `POST /api/v1/store/listings/:id/purchase` start checkout (returns flicko-pay session).
- `POST /api/v1/store/listings/:id/install` finalize after payment webhook.
- `GET /api/v1/store/orders` user purchase history.
- `POST /api/v1/store/listings/:id/reviews` write rating after 24 h install.
- `POST /api/v1/store/listings/:id/refund` self-serve within 7 days.
- `GET /api/v1/store/payouts` creator payout ledger.

## Purchase Flow
1. Client calls `purchase`, server creates `store_purchases` row with `state=pending`.
2. flicko-pay session URL returned; client redirects.
3. Webhook hits `/internal/payments/webhook`, signed with HMAC; transitions state to `paid`.
4. Webhook handler calls plugin-registry install for plugin/theme.
5. Receipt entry written, push notification sent.

## NFRs
- Catalog listing read p95 under 80 ms via Redis cache (5 min TTL).
- Search p95 under 250 ms across 100 k listings.
- Purchase flow availability target 99.9%; webhook idempotent on `event_id`.
- Reviewer console real-time updates via Supabase realtime channel.

## Observability
- Funnel events: `store.viewed`, `store.detail_viewed`, `store.purchase_started`, `store.purchase_completed`, `store.refunded`.
- Dashboards: queue depth, p95 review time, conversion by category, refund rate, payout failures.
- Alerts: webhook failure rate over 1% per 5 min, queue depth over 200, payout retries over 3.

## Security Review
- All listing assets scanned with ClamAV before publish.
- Reviewer role gated; actions logged to `audit_log` with reviewer id and decision.
- Buyer identity required (server admin role) for paid purchases.
- Refund issued only by purchaser or platform admin; replay protection via idempotency-key.
- PII: only billing email in flicko-pay; store DB never holds card data.
- Webhook signature `hmac-sha256` with rotating secret.

## Search
- Postgres FTS on `display_name` + `summary` + `tags`.
- trigram fallback for typo tolerance.
- Reranking by `install_count * avg_rating + recency_decay`.

## Caching
- Listing detail: Redis 5 min TTL, invalidate on update.
- Review aggregates recomputed on insert via trigger.
- Featured slot: edge cache 60 s.

## Failure Modes
- Stripe outage: queued purchases retried with backoff, user sees "payment provider slow, we will email you".
- Asset upload partial: row stays draft, GC after 24 h.
- Reviewer disagreement: two-reviewer consensus required for capability escalation cases.
