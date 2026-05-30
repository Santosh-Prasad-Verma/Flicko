# TRD - Creator Subscriptions

## Architecture
```
+----------------------------------------------------------+
|                Mobile (Flutter)                          |
| features/economy/creator_subscriptions                   |
|   tier_browser  +  manage_screen  +  paywall_overlay     |
+--------------------+-------------------------------------+
                     | REST + Realtime
+--------------------v-------------------------------------+
|              backend Go Echo                             |
|  internal/services/economy/creator_subscriptions         |
|     plan_service        - CRUD for SubscriptionPlan      |
|     subscription_service- CreateCheckout, Cancel, Modify |
|     entitlement_service - role/channel grant on tier     |
|     dunning_service     - schedules retries (cron+queue) |
|     gift_service        - bulk gifts via product code    |
|     webhook_service     - invoice.paid, invoice.payment_ |
|                             failed, customer.subscription|
+--------------------+-------------------------------------+
                     |                          |
              Postgres + ledger          Stripe Subscriptions
                                          (Connect destination)
                     |
              outbox -> NATS -> notifications, analytics
```

## REST Routes
- `POST   /v1/creators/{creator_id}/plans` create tier (idempotency-key required).
- `GET    /v1/creators/{creator_id}/plans` public list, filtered by `active=true`.
- `POST   /v1/plans/{plan_id}/subscribe` returns Stripe Checkout session URL or PaymentIntent client_secret for in-app sheet.
- `POST   /v1/subscriptions/{sub_id}/cancel` `?at_period_end=true|false`.
- `POST   /v1/subscriptions/{sub_id}/modify` body `{plan_id}` triggers proration.
- `POST   /v1/plans/{plan_id}/gift` body `{recipient_user_ids[], quantity, message}`.
- `POST   /v1/promo-codes` create promo (creator scope).
- `GET    /v1/me/subscriptions` user's active and past subs, paginated.
- `POST   /v1/webhooks/stripe` shared with marketplace.

## Stripe Webhook Handling
Distinct dispatch handlers wired into the shared webhook router:
- `customer.subscription.created` -> insert subscription row, grant entitlements (role, channels).
- `customer.subscription.updated` -> reconcile state, handle plan change, role swap.
- `customer.subscription.deleted` -> revoke entitlements after grace 24h, mark churned.
- `invoice.paid` -> write 4 ledger rows, advance current_period_end, fire `subscription.renewed` event.
- `invoice.payment_failed` -> mark past_due, enqueue dunning, send email + push.
- `invoice.payment_action_required` -> notify user 3DS challenge.
- `customer.subscription.trial_will_end` -> 3-day-out reminder.
- `charge.refunded` (subscription invoice) -> reverse ledger rows, optionally revoke entitlements.

Smart Retries on. Configured retry schedule mirrors Stripe Smart Retries with 4 attempts over 21 days. After last attempt, subscription auto-cancels with `cancellation_reason=payment_failed`.

## Non-Functional Requirements
- p99 plan create <= 250 ms; subscribe checkout <= 600 ms (Stripe round trip).
- Webhook idempotent and tolerant of out-of-order delivery (we re-fetch subscription via Stripe API for ground truth on critical state changes).
- Entitlement propagation to chat/role services <= 2 s p99.
- Cancel at period end is reversible up to period end with no proration penalty.

## Observability
- OTel: `subscription.create`, `subscription.modify`, `subscription.cancel`, `webhook.invoice_paid`, `entitlement.apply`.
- Metrics: `mrr_cents{creator}`, `arr_cents{creator}`, `churn_rate_30d`, `failed_invoice_count`, `dunning_recovery_count`.
- Sentry tag `economy_module=subscriptions`. Audit log per state change.

## Fraud / Abuse Mitigation
- Self-subscribe block: subscriber_user_id must not equal creator_user_id.
- Promo code abuse: per-user max-redemptions enforced server-side; `idempotency_key=user_id+code`.
- Velocity: max 5 sub create attempts per user per minute.
- Refund laundering: refunds via Stripe only; no manual ledger reversals; refund > $200 requires support approval.
- Trial abuse: Stripe Radar fingerprint on payment method blocks repeat trial usage on same card across creators (configurable, default off, on for high-risk creators).
