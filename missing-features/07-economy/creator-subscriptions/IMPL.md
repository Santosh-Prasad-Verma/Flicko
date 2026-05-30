# IMPL - Creator Subscriptions

## Phases
- **P0 Foundation (week 1-2)**: migration 176, plan CRUD, Stripe Product/Price sync.
- **P1 Subscribe + entitlements (week 3-4)**: checkout, customer.subscription.created, role/channel grant via entitlement_service.
- **P2 Renewals + dunning (week 5-6)**: invoice.paid + payment_failed, Smart Retries config, dunning emails.
- **P3 Mods, gifts, promos (week 7)**: upgrade/downgrade with proration, gift bulk, promo redemption.
- **P4 Hardening (week 8)**: churn dashboards, observability, Sentry filters.
- **P5 Beta (week 9-10)**: 50 creators with > 100 followers, NRR target 100%.
- **P6 GA (week 12)**: feature flag flip, marketing.

## Backend tasks - `backend/internal/services/economy/creator_subscriptions`
- `domain/plan.go`, `domain/subscription.go`, `domain/invoice.go`, `domain/promo.go`, `domain/gift.go` aggregates with invariants.
- `service/plan_service.go` - Create, Edit, Archive; sync to Stripe Product/Price; idempotent on Flicko plan_id.
- `service/subscription_service.go` - StartCheckout, ApplyPromo, ChangePlan, Cancel, Reactivate.
- `service/entitlement_service.go` - Apply (role grant + channel ACL upsert), Revoke, Reconcile (cron daily).
- `service/dunning_service.go` - listens to `invoice.payment_failed`, schedules push + email per attempt; on final failure, cancel.
- `service/gift_service.go` - bulk create, idempotent on `(gifter_id, batch_id, recipient_id)`.
- `service/promo_service.go` - atomic redemption increment, Stripe coupon sync.
- `service/webhook_service.go` - extends shared dispatcher with subscription handlers.
- `repo/...sqlc generated` - parameterized queries.
- `http/handler.go` - REST routes; uses idempotency middleware from server-marketplace.
- Wire in `cmd/api/wire.go`. Add module registration mirroring `backend/internal/gaming/module.go`.

## Mobile tasks - `mobile/lib/features/economy/creator_subscriptions`
- `data/{plans_api.dart,subscriptions_api.dart}` retrofit.
- `domain/models/{plan,subscription,invoice}.dart` freezed.
- `presentation/screens/tier_browser_screen.dart`.
- `presentation/screens/checkout_sheet.dart`.
- `presentation/screens/manage_subscription_screen.dart`.
- `presentation/screens/tier_composer_screen.dart` (creator-only).
- `presentation/widgets/{tier_card,perk_list,promo_input,price_toggle}.dart`.
- `providers/subscription_providers.dart` riverpod with realtime channel `subscription:{id}`.
- Paywall overlay reusable widget for gated channels: `presentation/widgets/paywall_overlay.dart` shown by chat module when ACL denies.
- Routes in `mobile/lib/core/router/app_router.dart`: `/creator/:id/subscribe`, `/subscriptions/manage/:id`, `/creator/:id/tiers/new`.

## Test Plan
- **Unit (Go)**: domain invariants (price floor, max trial days, mutual exclusivity of pct vs amount promo); 100% lines.
- **Integration**: full lifecycle test - subscribe with trial, upgrade, downgrade, cancel-at-period-end, reactivate, refund.
- **Webhook fixtures**: capture real Stripe events into `testdata/`, replay through dispatcher.
- **E2E (Maestro)**: subscribe, see badge in chat, access gated channel, downgrade flow, cancel flow.
- **Load**: k6 - 200 webhooks/sec for 10 minutes, p99 dispatch < 200 ms, zero double-grants.
- **Security**: RLS bypass attempts (subscriber should not read other subscribers); promo brute-force rate limit test.
- **Chaos**: kill Stripe-mock during invoice.paid, verify outbox replay grants entitlement at most once.

## Rollout
- Flag `economy.subscriptions.enabled` per creator, default off.
- Internal dogfood 7 days.
- Closed beta 50 creators, 30 days, watch involuntary churn.
- Open beta gated by KYC + minimum follower count (250).
- GA when involuntary churn < 4.5% over 30-day window and entitlement reconcile drift = 0.

## Cost Model (per 10k MAU subscriptions, $7 ARPU)
- Stripe fees: 2.9% + 30c + 0.5% recurring = ~$3300 of $70k.
- Stripe Tax: 0.5% = $350.
- Postgres + ledger I/O: ~$80.
- Email + push (dunning + reminders): ~$60.
- Net platform take @ 5% = $3500 - infra ($150) - reserves (1%) = ~$2650.
- Reserve fund 1% of MRR for refunds, held 60 days.
