# TRD - Server Marketplace

## Architecture
```
+-------------------------------------------------------------+
|                       Mobile (Flutter)                      |
|  features/economy/server_marketplace                        |
|     listings_repo  +  checkout_repo  +  realtime_listener   |
+------------------+--------------------+---------------------+
                   |                    |
            REST (signed)         Supabase Realtime
                   |                    |
+------------------v---------------------v--------------------+
|              backend (Go monolith, Echo)                    |
|   internal/services/economy/server_marketplace              |
|       listing_service                                       |
|       auction_service     -> redis sorted set per auction   |
|       purchase_service    -> idempotent intent creation     |
|       webhook_service     -> stripe event router            |
|       payout_service      -> server treasury split          |
|   internal/services/economy/ledger                          |
|       double_entry writer (immutable, hash-chained)         |
+------------------+--------------------+---------------------+
                   |                    |
              Postgres 15            Stripe Connect
              (RLS, pg_partman)         Express
                   |
              Outbox -> NATS -> reward-system, analytics
```

## REST Routes
- `POST   /v1/servers/{server_id}/listings` create draft (idempotency-key required).
- `PATCH  /v1/listings/{listing_id}` edit draft fields.
- `POST   /v1/listings/{listing_id}/publish` flip to live, server treasury must have onboarded payouts.
- `GET    /v1/servers/{server_id}/listings?status=live&cursor=` paginated, RLS-scoped.
- `POST   /v1/listings/{listing_id}/purchase` returns Stripe PaymentIntent client_secret.
- `POST   /v1/listings/{listing_id}/bids` for auction listings, body `{amount_cents}`.
- `POST   /v1/purchases/{purchase_id}/refund` mod/owner only.
- `POST   /v1/webhooks/stripe` raw body, signature verified, idempotent on `event.id`.

## Stripe Webhook Handling
- Verify `Stripe-Signature` against per-environment secret, reject if drift > 5 min.
- Insert raw event into `stripe_events(event_id PK, payload jsonb, processed_at)`. Unique constraint enforces idempotency.
- Dispatch table: `payment_intent.succeeded` -> finalize purchase, write ledger; `payment_intent.payment_failed` -> mark intent failed, free auction hold; `charge.refunded` -> reverse ledger entries; `charge.dispute.created` -> freeze related listing, notify owner; `account.updated` -> refresh KYC cache.
- All handlers wrapped in a single tx with `SET LOCAL idle_in_transaction_session_timeout='5s'` to avoid lock storms.
- Failed dispatch retries via NATS DLQ with exponential backoff (15s, 1m, 5m, 30m, 4h).

## Non-Functional Requirements
- p99 purchase intent creation <= 350 ms (excluding Stripe round trip).
- Webhook ingress >= 800 events/sec sustained.
- Listing read fan-out via Cloudfront edge cache, 30 s TTL keyed on `(server_id, version)`.
- All money values stored as `bigint` minor units; never floats.
- Schema migrations 175-184 must be backwards compatible for one release.

## Observability
- OTel spans: `marketplace.create_listing`, `marketplace.purchase.intent`, `marketplace.webhook.dispatch{event_type}`, `ledger.write`.
- RED metrics per route, plus `marketplace_gmv_cents` counter labeled by `server_id` (high-cardinality, scraped to ClickHouse not Prom).
- Sentry tag `economy_module=marketplace`, fingerprint by `event_id` to dedupe webhook noise.
- Audit log table `marketplace_audit_log` immutable append-only, 7-year retention.

## Fraud / Abuse Mitigation
- Velocity: per buyer max 8 purchases / 10 min; per IP 25 / 10 min; per device 15 / 10 min. Backed by Redis token bucket.
- 3DS forced for first purchase on any new card and for amounts > $250.
- Listing scanner: AI moderation pass (Sightengine for media, in-house keyword model for title/desc) before publish.
- Refund abuse: hard limit of 4 refunds requested by same buyer in 30 days routes to manual queue.
- Auction sniping protection: any bid in last 60 s extends auction by 90 s, capped at 10 extensions.
- Self-purchase block: buyer cannot equal listing.creator_id; checked at intent + at webhook (defence in depth).
