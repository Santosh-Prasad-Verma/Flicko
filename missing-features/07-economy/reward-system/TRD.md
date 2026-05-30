# TRD - Reward System

## Architecture
```
+-----------------------------------------------------------+
|         platform events (any module)                      |
|   purchase.completed, message.sent, stage.hosted,         |
|   subscription.renewed, gift.sent, daily.login...         |
+--------------------+--------------------------------------+
                     | NATS (subject reward.events)
+--------------------v--------------------------------------+
|      backend/internal/services/economy/reward_system      |
|     ingest_worker      - consumes NATS, dedupe by event_id|
|     rule_engine        - evaluates active rules per event |
|     grant_service      - writes grant + ledger atomically |
|     budget_service     - rule budget counters in Redis    |
|     delivery_service   - coins, badges, roles, codes      |
|     admin_service      - CRUD rules, A/B variants         |
|     reconcile_worker   - nightly drift check vs events    |
+--------------------+--------------------------------------+
                     |                |
              Postgres (rules, grants)  Redis (counters, locks)
                     |
              outbox -> NATS -> notifications, analytics
```

## REST Routes
- `POST /v1/admin/reward-rules` create rule with version pin.
- `PATCH /v1/admin/reward-rules/{id}` mutates only `active`, `budget`, `pct_rollout`; semantic edits force new version.
- `GET /v1/admin/reward-rules` list with filters.
- `POST /v1/admin/reward-rules/{id}/dry-run` simulate against last 24h events, returns counts and total budget.
- `GET /v1/me/rewards` user's grants paginated.
- `POST /v1/admin/grants/{id}/reverse` admin-only, audited, requires reason.

## Stripe Webhook Handling
This module does not directly handle Stripe webhooks. It listens to internal events that have already been derived from Stripe webhooks by other services (purchase.completed, subscription.renewed, etc.). When grants include cash payout, settlement is handed off to flicko-pay payouts.

## Non-Functional Requirements
- p99 ingest -> grant write <= 30 s under 5x peak load.
- Throughput >= 5000 events/sec sustained.
- Idempotent across worker restarts and event redelivery.
- Budget enforcement strict-strong (no overspend ever); use Redis Lua compare-decrement.
- Rule changes versioned; in-flight events use the version active at event time.

## Observability
- OTel: `reward.ingest`, `reward.evaluate{rule_id}`, `reward.grant{rule_id}`, `reward.budget.deny{rule_id}`.
- Metrics: `grants_total{rule_id,kind}`, `budget_remaining_cents{rule_id}`, `grant_latency_seconds`, `dlq_depth`.
- Sentry tag `economy_module=rewards`.
- Audit log on rule create/edit, grant reverse.

## Fraud / Abuse Mitigation
- Sybil: device fingerprint + phone verify required for cash rewards; risk score from existing fraud module.
- Velocity: per-user daily cap of N grants per rule (configurable), default 1.
- Cooldowns: rule-level cooldown enforced via Redis SETEX `cd:rule:{id}:user:{u}` TTL = cooldown_seconds.
- Rule expression sandbox: only whitelisted predicates (event field comparisons, count thresholds) - no arbitrary code.
- Budget runaway: per-rule hourly + daily caps, page on 80% consumption, hard stop at 100%.
- Reversal pathway: when fraud detected post-grant, admin reverses grant; ledger writes mirrored CR/DR with `reverses_grant_id`. Coins debited even into negative if needed; user's account flagged.
- KYC: any cash payout > $20 lifetime requires verified phone + email; > $600/year requires full KYC + tax form.
