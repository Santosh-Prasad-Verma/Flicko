# IMPL - Server Marketplace

## Phases
- **P0 Foundation (week 1-2)**: migrations 175, ledger plumbing, Connect Express onboarding flow reused from server-economy.
- **P1 Fixed listings (week 3-4)**: composer, list/detail, checkout sheet, webhook reconciliation, refund.
- **P2 Auctions (week 5-6)**: bidding, redis hold pattern, snipe-extend, ended-state payment capture.
- **P3 Hardening (week 7)**: fraud rules, dispute UI, admin takedown, Sentry/OTel sweep.
- **P4 Beta (week 8)**: 25 hand-picked servers, GMV target $5k/week.
- **P5 GA (week 10)**: feature flag flip, marketing event, Help Center docs.

## Backend tasks - `backend/internal/services/economy/server_marketplace`
- `domain/listing.go` - aggregate, invariants, version bump on edit.
- `domain/auction.go` - bid validation, snipe-extend rules, end-time computation.
- `service/listing_service.go` - Create, Publish, Edit, Pause, Remove (with mod auth).
- `service/purchase_service.go` - CreateIntent (idempotent), Finalize (called by webhook), Refund.
- `service/auction_service.go` - PlaceBid, with redis ZADD + lua compare-and-set.
- `service/webhook_service.go` - dispatcher map, DLQ enqueue on dispatch error.
- `service/payout_service.go` - daily cron, generates Connect transfers, splits server cut to treasury.
- `repo/listings_repo.go`, `repo/purchases_repo.go`, `repo/bids_repo.go` (sqlc generated).
- `http/handler.go` - Echo handlers, request DTOs, response shapers.
- `http/middleware_idempotency.go` - reads `Idempotency-Key`, hashes body, persists.
- `outbox/publisher.go` - reuses shared outbox to NATS.
- Wire in `backend/internal/gaming/module.go` style: `cmd/api/wire.go` adds module.
- Update `internal/handlers/game/stats_handler.go` pattern for stats endpoint at `/v1/marketplace/stats`.

## Mobile tasks - `mobile/lib/features/economy/server_marketplace`
- `data/listing_dto.dart`, `data/listings_api.dart` (retrofit).
- `data/checkout_api.dart` integrating `flutter_stripe`.
- `domain/models/{listing,bid,purchase}.dart` with `freezed`.
- `presentation/screens/marketplace_home_screen.dart`.
- `presentation/screens/listing_detail_screen.dart`.
- `presentation/screens/checkout_sheet.dart`.
- `presentation/screens/listing_composer_screen.dart` (multi-step form, draft persistence).
- `presentation/widgets/{listing_card,price_tag,countdown_timer,bid_input}.dart`.
- `providers/marketplace_providers.dart` riverpod, with realtime channel subscription.
- Add route entries in `mobile/lib/core/router/app_router.dart`: `/marketplace/:serverId`, `/listing/:id`, `/marketplace/new`.

## Test Plan
- **Unit (Go)**: domain invariants 100% lines, service happy + error paths, idempotency replay equivalence test.
- **Contract**: pact between mobile checkout repo and backend purchase handler.
- **Integration**: spin postgres + stripe-mock + redis in compose, exercise full purchase + refund + dispute lifecycles.
- **E2E (Maestro)**: buy fixed listing with Apple Pay sandbox, place bid, snipe-extend, refund flow.
- **Load**: k6 - 500 RPS purchase intent for 10 min, p99 < 350 ms, error < 0.5%.
- **Security**: ZAP baseline scan, manual RLS bypass attempts (cross-server reads must 0%).
- **Chaos**: kill stripe-mock mid-tx, verify outbox replay.

## Rollout
- Flag `economy.marketplace.enabled` per server, default off.
- Internal dogfood (Flicko HQ server) for 7 days.
- Closed beta 25 servers, 14 days.
- Open beta self-serve, gated by KYC step.
- GA when refund rate < 2.4%, p99 < 350ms for 7 consecutive days.
- Kill-switch: env `MARKETPLACE_KILL=1` returns 503 on `/v1/listings/*/purchase`, leaves reads live.

## Cost Model (per 1k purchases, avg $12 GMV)
- Stripe fees: 2.9% + 30c -> $648 of $12k.
- Stripe Tax: 0.5% -> $60.
- Postgres write+read: ~$0.40.
- NATS + Redis: ~$0.15.
- Object storage media (avg 600 KB / listing, 1k unique listings -> 600 GB at $0.023 = $13.80, amortized).
- Net platform take @ 5% = $600 - Stripe pass-through is paid by buyer/seller per Connect destination charge config; platform fee 5% nets ~$420 after infra and reserves.
- Refund/dispute reserve: 3% of GMV held 90 days.
