# TRD - Digital Gifts

## Architecture
```
+-----------------------------------------------------------+
|                Mobile (Flutter)                           |
| features/economy/digital_gifts                            |
|   gift_drawer  +  topup_sheet  +  overlay_renderer        |
+--------------------+--------------------------------------+
                     | REST + Realtime (gift_event)
+--------------------v--------------------------------------+
|              backend Go Echo                              |
|  internal/services/economy/digital_gifts                  |
|     catalog_service     - read-only with Redis cache      |
|     coin_service        - balance, top-up, spend          |
|     gift_service        - SendGift atomic spend + emit    |
|     overlay_service     - build payload for stage/chat    |
|     leaderboard_service - per-creator weekly top fans     |
|     webhook_service     - Stripe top-up confirm           |
+--------------------+--------------------------------------+
                     |             |
              Postgres (ledger)   Stripe (PaymentIntents for top-up)
                     |             |
              outbox -> NATS -> stage overlay channel, analytics, reward-system
```

## REST Routes
- `GET    /v1/gifts/catalog?surface=stage` cached (Edge 60s).
- `GET    /v1/me/coins` returns balance, recent ledger.
- `POST   /v1/coins/topup` body `{pack_id}` -> Stripe PaymentIntent.
- `POST   /v1/gifts/send` body `{gift_id, recipient_id, surface_id, idempotency_key}` atomic spend.
- `GET    /v1/creators/{id}/gift-inbox` paginated.
- `GET    /v1/creators/{id}/leaderboard?period=7d`.
- `POST   /v1/coins/refund` user-initiated refund of unused balance > $5.
- `POST   /v1/webhooks/stripe` shared dispatcher.

## Stripe Webhook Handling
- `payment_intent.succeeded` (purpose=coin_topup) -> credit user's coin balance, write ledger DR cash CR coin_liability, emit `coins.credited`.
- `payment_intent.payment_failed` -> notify user, no balance change.
- `charge.refunded` -> if coins unspent, debit balance and reverse ledger; if partially spent, refund only remaining + small admin fee.
- `charge.dispute.created` -> freeze balance, queue review.

Spend (gift send) is internal and not Stripe-mediated; only coin liability moves between users in ledger. Creator payout settles when payable cash threshold met (see flicko-pay).

## Non-Functional Requirements
- p99 gift send <= 80 ms (single Postgres tx).
- Overlay event broadcast to stage participants p99 <= 250 ms.
- Catalog read 99.99% availability (CDN + Redis fallback).
- Coin balance integer-only (no fractional coins).
- Daily reconciliation: sum of `user.coin_balance` + `creator.coin_payable` + `platform.coin_revenue_recognized` must equal `platform.coin_liability` to the cent.

## Observability
- OTel: `gift.send`, `coin.topup.create`, `coin.topup.confirm`, `overlay.broadcast`.
- Metrics: `gifts_sent_total{gift_id}`, `coin_topup_gmv_cents`, `coin_balance_total_cents`, `gift_revenue_recognized_cents{creator_id}`.
- Sentry tag `economy_module=digital_gifts`. Audit log for top-ups and refunds.

## Fraud / Abuse Mitigation
- Velocity: max 60 gifts / minute per user; max 1000 / day per user.
- Stolen card: 3DS forced on top-ups > $50 and on first top-up.
- Coin laundering: same-IP/device send back to original sender flagged; daily AML report.
- Underage: account dob check, hard cap < 18 = $0 of in-app spend (compliant with COPPA-derived policy in our ToS).
- Self-gifting block: sender_id != recipient_id at API + webhook.
- Spam gifts: per-recipient cap of 600 gifts / minute (anti-grief), excess buffered to a single "and X more" overlay collapse.
- KYC: creators receiving > $1k coin payable in 30 days require KYC completion before payout.
