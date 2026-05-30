# APPFLOW - Creator Subscriptions

## Sequence: First subscribe with trial
```mermaid
sequenceDiagram
  participant U as User
  participant M as Mobile
  participant API as Backend
  participant S as Stripe
  participant DB as Postgres
  participant E as EntitlementSvc

  U->>M: tap Subscribe (Silver)
  M->>API: POST /plans/{id}/subscribe {idempotency_key}
  API->>DB: SELECT plan FOR SHARE; SELECT existing subs
  API->>S: customers.create or retrieve
  API->>S: subscriptions.create trial_period_days=7, payment_behavior=default_incomplete
  S-->>API: subscription incomplete + setup intent
  API-->>M: client_secret
  M->>S: confirmSetupIntent (Apple Pay)
  S-->>API: webhook customer.subscription.updated status=trialing
  API->>DB: UPSERT subscriptions row
  API->>E: grant role, channel access
  E-->>API: ok
  API-->>M: realtime push, badge appears
  Note over S,API: 7 days later
  S-->>API: invoice.paid
  API->>DB: insert ledger entries x4
  API->>DB: update subscription current_period_end
```

## State Machine: subscription
```
        incomplete
          |
       trial start
          v
        trialing -- trial_will_end (3d) -> trialing
          |
       trial end
          v
         active <-> past_due (dunning)
          |             |
        cancel        4 retries
        at end          v
          |          canceled (involuntary)
          v
       canceled (voluntary, period ends)
          |
          v
         ended (entitlements revoked)
```

## State Machine: invoice
```
   open -> finalized -> paid           -> archived
                    -> uncollectible   -> archived
                    -> void
```

## Edge Cases
- **Upgrade mid-cycle**: Stripe prorates. Backend updates entitlements optimistically on `customer.subscription.updated`, ledger writes on the immediate proration invoice with `invoice.paid`.
- **Downgrade mid-cycle**: schedule plan change at period end via `subscription_schedules`; entitlements stay until period end.
- **Cancel during trial**: subscription deletes immediately, no charge, entitlements revoke at end of trial date for content predictability.
- **Card fails on first attempt at trial end**: enter past_due, dunning kicks in, entitlements remain active for 7-day grace.
- **Card fails on N-th renewal**: retain entitlements during dunning until 4 retries exhausted, then revoke.
- **Stripe webhook out of order**: subscription.updated may arrive before subscription.created on some scenarios. We handle with `INSERT ... ON CONFLICT DO UPDATE WHERE excluded.updated_at > subscriptions.updated_at`.
- **Promo code race**: promo with max_redemptions tracked atomically using Postgres `UPDATE promo_codes SET redeemed = redeemed + 1 WHERE redeemed < max_redemptions RETURNING id`. Mismatched returns rejection.
- **Gift to user who already has same tier**: extends current period by 1 cycle, no double-charge, no role change.
- **Refund within 7-day window after first payment**: full refund + immediate revocation, ledger reverses entries, churn reason recorded as 'refund'.
- **Creator deleted account**: existing subs honored until period end, no renewal, refund prorated remainder.
- **Server hosting creator changes ownership**: server cut routing recomputed at next renewal; in-flight cycle keeps original cut.
- **Currency change attempt**: not supported in v1; user must cancel and resubscribe in new currency.
- **3DS required on renewal**: Stripe sends `payment_action_required`. We push notify, deep-link to `/subscriptions/{id}/authenticate`. Grace 5 days, else past_due.
- **Race - cancel during dunning**: cancel-at-period-end overrides dunning; no further retries; entitlements end at original period_end.
