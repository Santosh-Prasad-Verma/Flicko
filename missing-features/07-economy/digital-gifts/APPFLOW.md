# APPFLOW - Digital Gifts

## Sequence: Top-up + send gift
```mermaid
sequenceDiagram
  participant U as User
  participant M as Mobile
  participant API as Backend
  participant S as Stripe
  participant DB as Postgres
  participant N as NATS
  participant R as Recipients

  U->>M: open gift drawer
  M->>API: GET /me/coins
  API-->>M: balance=200
  M-->>U: shows balance, gifts > 200 disabled
  U->>M: tap top-up 5000
  M->>API: POST /coins/topup pack_id=p5k
  API->>S: PaymentIntents.create $50, metadata.purpose=coin_topup
  S-->>API: client_secret
  API-->>M: client_secret
  M->>S: confirmPayment Apple Pay
  S-->>API: webhook payment_intent.succeeded
  API->>DB: BEGIN; +5000 to user.coin_balance; ledger DR cash CR coin_liability; outbox; COMMIT
  API-->>M: realtime balance update
  U->>M: tap rose x5
  M->>API: POST /gifts/send {gift_id, recipient_id, surface_id, idem}
  API->>DB: BEGIN; UPDATE coin_balance -= 50 WHERE balance>=50; insert sent_gifts; ledger DR coin_liability CR creator.coin_payable + platform.coin_revenue + server.coin_share; outbox; COMMIT
  API->>N: gift.sent
  N->>R: realtime stage overlay
  R-->>U: animation plays for all participants
```

## State Machine: coin_topup
```
   created -> requires_payment -> processing -> succeeded -> credited
                                            -> failed
   credited -> partial_refunded (if user requested coins back, if unspent)
            -> disputed -> dispute_won | dispute_lost (debit balance if lost)
```

## State Machine: sent_gift
```
   pending_spend -> committed -> overlay_dispatched -> archived
                 -> rejected (insufficient balance, recipient invalid, velocity)
   committed -> reversed (admin only, abuse)
```

## Edge Cases
- **Race - 2 sends with balance=50 and gift cost=50**: handled by `UPDATE coin_balance SET balance = balance - 50 WHERE balance >= 50 RETURNING balance`. Second concurrent UPDATE returns 0 rows -> rejected with 402.
- **Webhook payment_intent.succeeded duplicate**: `stripe_events` PK on event_id, only first processes balance credit.
- **Overlay broadcast lag during stage**: if NATS publish fails, gift is still committed in ledger; on reconnect, mobile pulls last 30s of inbox events to backfill UI. Animations have a 60s freshness window beyond which we render only as silent inbox entries.
- **Recipient blocked sender**: API checks block list before commit, returns 403 with refund-of-coins of 0 (no spend).
- **Sender deletes account post-spend**: ledger is immutable; recipient still keeps payable. Sender's user row tombstoned, references retained.
- **Recipient deletes account before payout**: payable converted to platform.unclaimed liability after 365 days.
- **Refund disputed top-up**: dispute won by Stripe = balance debited; if user already spent some, debit goes negative, reconciliation alerts AML, support follows up.
- **Coins purchased via Apple IAP**: coins flagged `source=iap`, lower yield to absorb 30% Apple cut, separate ledger account `apple_iap_clearing` to keep platform revenue accurate.
- **Underage account upgrades to adult**: prior coins remain locked until KYC if existing top-ups were blocked; otherwise no-op.
- **Server cut bps changed mid-event**: snapshot at gift commit time, not at payout.
- **Big gift (>$50) during outage**: API returns 503 with retry-after, no partial spend. Mobile retries with same idempotency_key.
- **Currency mismatch on top-up**: top-up always priced in user's home currency; coins are dimensionless internally.
