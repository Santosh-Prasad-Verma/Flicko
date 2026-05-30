# IMPL - Digital Gifts

## Phases
- **P0 Foundation (week 1)**: migration 177, gift_catalog seeded with 30 packs, coin_balances + topup pipeline.
- **P1 Send + overlays (week 2-3)**: send gift atomic spend, NATS broadcast, mobile overlay renderer with lottie + rive.
- **P2 Inbox + leaderboards (week 4)**: creator inbox, weekly leaderboards, MV refresh cron.
- **P3 Apple/Google IAP (week 5-6)**: iOS in-app coin purchases via StoreKit, Android Play Billing; reduced-yield packs.
- **P4 Hardening (week 7)**: velocity, fraud, AML report, COPPA gates.
- **P5 Beta (week 8)**: 100 stages with > 20 listeners, ARPPU target $2.
- **P6 GA (week 10)**: feature flag flip.

## Backend tasks - `backend/internal/services/economy/digital_gifts`
- `domain/gift.go`, `domain/coin_balance.go`, `domain/topup.go`, `domain/sent_gift.go` aggregates.
- `service/catalog_service.go` - read with Redis cache 60s TTL, invalidate on admin write.
- `service/coin_service.go` - GetBalance, CreateTopup (idempotent), CreditOnWebhook, RefundUnused.
- `service/gift_service.go` - SendGift (atomic SELECT FOR UPDATE -> UPDATE balance -> INSERT sent_gifts -> ledger -> outbox).
- `service/overlay_service.go` - builds overlay payload, dedupes rapid-send into combo, publishes to NATS topic `surface.{type}.{id}.gifts`.
- `service/leaderboard_service.go` - reads MV, REFRESH MATERIALIZED VIEW CONCURRENTLY every 60s.
- `service/iap_verifier.go` - Apple ASN1 receipt verification + Google Play Developer API; credits coins on verified purchase.
- `service/webhook_service.go` - handles `payment_intent.succeeded` purpose=coin_topup, `charge.refunded`.
- `repo/...sqlc generated`.
- `http/handler.go` - REST routes, idempotency middleware shared.
- Wire in `cmd/api/wire.go`. Module registration similar to `backend/internal/gaming/module.go`.

## Mobile tasks - `mobile/lib/features/economy/digital_gifts`
- `data/{catalog_api.dart,coins_api.dart,gifts_api.dart}` retrofit.
- `domain/models/{gift,coin_balance,topup,sent_gift}.dart` freezed.
- `presentation/widgets/gift_drawer.dart` slide-up, virtualized grid.
- `presentation/widgets/topup_sheet.dart`.
- `presentation/widgets/gift_overlay_renderer.dart` queue-based, supports lottie + rive, respects reduce_motion.
- `presentation/screens/gift_inbox_screen.dart` (creator).
- `presentation/screens/leaderboard_screen.dart`.
- `providers/coin_balance_provider.dart` riverpod with Realtime channel sub.
- Hook into existing stage screen `mobile/lib/features/server_channels/stage/presentation/screens/stage_channel_screen.dart` to mount overlay renderer and gift drawer.
- Routes `/gifts/inbox`, `/gifts/leaderboard/:creatorId`.

## Test Plan
- **Unit (Go)**: balance arithmetic property tests (no negative balance, conservation), idempotent send replays.
- **Integration**: top-up via stripe-mock then send 100 gifts in burst, verify ledger reconciles to cent.
- **E2E (Maestro)**: top up, send rose burst on stage, see overlay; refund unused coins.
- **Load**: k6 - 1000 sends/sec for 5 minutes, p99 < 100 ms, zero balance drift.
- **Animation perf**: golden tests for overlay lottie at 30 FPS on iPhone SE 2020.
- **Security**: self-gift block, blocked-recipient block, COPPA gating with synthetic minors.
- **Compliance**: monthly AML rule replay on synthetic dataset, expect alerts on suspicious patterns.

## Rollout
- Flag `economy.gifts.enabled` per server, default off.
- Internal stages 7 days.
- Closed beta 100 stages, 14 days; check overlay perf on low-end Android.
- Open beta gated by server age > 14 days and member count > 20.
- GA when ARPPU > $2, refund < 1%, overlay p99 < 250 ms.

## Cost Model (per 1M gifts at avg 50 coins / $0.50)
- Stripe top-up fees: 2.9% + 30c on top-up (not per gift), aggregated -> ~3.5% effective.
- Postgres writes: ~$60.
- NATS broadcast: ~$15.
- Lottie/Rive CDN egress: ~$80 (bigger files cached aggressively).
- Net platform take @ 30% of $500k = $150k - infra ($1k) - reserves (1.5%) = ~$141k.
- Coin liability reserve held at 12% of unspent balance per ASC 606 deferred revenue.
