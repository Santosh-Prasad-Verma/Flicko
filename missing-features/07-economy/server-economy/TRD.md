# Server Economy — Technical Requirements

## 1. Architecture Overview

```
            +------------------+
 Mobile --> | gateway (Go)     | --REST/Grpc-->  economy-svc (Go)
            +------------------+                   |
                  |   ^                            v
                  |   |                    +--------------+
                  |   +--Centrifugo<-------|  ledger.go   |
                  |     economy:<srv_id>   +------+-------+
                  v                               |
            +------------------+                  v
            | NATS jetstream    | <----+   Postgres (Supabase)
            | flicko.economy.*  |      |   - wallets
            +------------------+      |   - wallet_entries  (immutable)
                                       |   - transactions
                  ^                    |   - currency_config
                  |                    |   - daily_claims
            earn-worker (cron) --------+   - velocity_buckets (Redis-mirrored)
            anti-fraud-worker
```

Single source of truth for balances is the **sum of `wallet_entries`** for a wallet. The `wallets.balance` column is a denormalized cache, updated transactionally inside the same DB tx that inserts the entries. Reconciliation job runs nightly.

## 2. Components

### Backend (Go)

- **Service:** `backend/internal/services/economy/server-economy/service.go`
  - `CreateCurrency(ctx, serverID, cfg)`
  - `GetWallet(ctx, serverID, userID) -> Wallet`
  - `Credit(ctx, walletID, amount, source, refID, idempotencyKey)`
  - `Debit(ctx, walletID, amount, sink, refID, idempotencyKey)`
  - `Transfer(ctx, fromWallet, toWallet, amount, reason, idempotencyKey)`
  - `ClaimDaily(ctx, walletID) -> ClaimResult`
  - `Leaderboard(ctx, serverID, window) -> []Row`
- **Handlers:** `backend/internal/handlers/economy/wallet_handler.go`, `currency_handler.go`, `daily_handler.go`, `mod_handler.go`.
- **Models:** `backend/internal/models/economy.go` (Wallet, Entry, Currency, ClaimResult).
- **Workers:**
  - `earn-worker.go` — drains NATS `flicko.economy.earn.*`, applies velocity caps, writes credits.
  - `daily-reset-worker.go` — at server-tz midnight, mark eligible.
  - `reconciliation-worker.go` — nightly sums every wallet, alerts on drift.
- **Repo:** `backend/internal/repo/economy_repo.go` — pgx + sqlc. **No ORM, no string-concatenated SQL.**

### Mobile (Flutter)

- `mobile/lib/features/economy/server_economy/`
  - `data/`: `economy_dto.dart`, `economy_remote_datasource.dart`, `economy_repository_impl.dart`
  - `domain/`: `wallet.dart`, `transaction.dart`, `usecases/{claim_daily,transfer,...}.dart`
  - `application/`: `wallet_provider.dart` (Riverpod AsyncNotifier), `leaderboard_provider.dart`
  - `presentation/`: `wallet_screen.dart`, `currency_settings_screen.dart`, `mod_grant_sheet.dart`, `widgets/{balance_card,daily_claim_button,transaction_tile,leaderboard_row}.dart`

### Infra

- DB: Supabase Postgres (migration `175_server_economy.up.sql`).
- Realtime: Centrifugo channel `economy:<server_id>` (events: `balance.updated`, `daily.claimed`, `currency.updated`).
- Cache: Redis keys
  - `econ:wallet:<wallet_id>` -> JSON, TTL 30s, busted on write.
  - `econ:lb:<server_id>:<window>` -> ZSET, TTL 5m.
  - `econ:velocity:<source>:<wallet_id>:<bucket>` -> INTCR, TTL bucket-aligned.
- Queue: NATS subjects `flicko.economy.earn.*`, `flicko.economy.spend.*`, `flicko.economy.audit`.
- Search: none (leaderboards are SQL with cached snapshot).

## 3. API Contracts

### REST

```
POST   /api/v1/servers/:sid/economy/currency      admin: create/update currency
GET    /api/v1/servers/:sid/economy/currency      member: read

GET    /api/v1/servers/:sid/economy/wallet        self wallet
GET    /api/v1/servers/:sid/economy/wallet/:uid   public profile (admin or self)
GET    /api/v1/servers/:sid/economy/transactions  paginated, cursor=<entry_id>

POST   /api/v1/servers/:sid/economy/daily         claim daily
GET    /api/v1/servers/:sid/economy/daily         status (claimed_at, streak, next_at)

POST   /api/v1/servers/:sid/economy/mod/grant     mod: {user_id, amount, reason}
POST   /api/v1/servers/:sid/economy/mod/revoke    mod: {user_id, amount, reason}
POST   /api/v1/servers/:sid/economy/mod/freeze    mod: {user_id, frozen: bool}

GET    /api/v1/servers/:sid/economy/leaderboard?window=weekly
```

All write endpoints require `Idempotency-Key` header. Server-side cache: 24h.

### Centrifugo

- Channel: `economy:<server_id>`
- Events:
  - `balance.updated` `{wallet_id, balance, delta, source}`
  - `daily.claimed` `{user_id, amount, streak}`
  - `currency.updated` `{name, icon_url}`
  - `wallet.frozen` `{user_id, frozen}`

### Payloads

```jsonc
// POST currency
{ "name": "Stardust", "icon_url": "https://cdn.flicko.app/srv/123/coin.png", "starting_balance": 100, "tz": "America/Los_Angeles" }

// Wallet
{ "wallet_id": "uuid", "user_id": "uuid", "server_id": "uuid", "balance": 1240, "frozen": false, "updated_at": "..." }

// Daily claim result
{ "amount": 25, "streak": 4, "multiplier": 1.5, "next_at": "2026-05-30T00:00:00-07:00" }
```

## 4. Permissions & Auth

- Required scopes: `economy.read`, `economy.write`, `economy.mod`.
- Role checks:
  - Read self wallet -> any member.
  - Read leaderboard -> any member (admin can disable).
  - Mod grant/revoke -> requires server permission `MANAGE_ECONOMY` (new bit).
  - Currency config -> server owner or `ADMINISTRATOR`.
- RLS in `SCHEMA.md`. **Never** trust `auth.uid()` alone for wallet lookups; always join through `server_members`.

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| p50 latency `GET wallet` | <40ms |
| p99 latency `POST daily` | <250ms |
| Throughput per shard | 800 rps sustained |
| Availability | 99.95% |
| Ledger drift | 0 entries per day |
| Storage cost | <$0.0006 / wallet / month |
| Idempotency window | 24h |

## 6. Dependencies

- Existing: `auth-svc`, `server-svc`, `notification-svc`, `audit-svc`.
- New libs: `github.com/shopspring/decimal v1.4.0` (defensive even though we use int64 minor units), `github.com/oklog/ulid/v2 v2.1.0` for entry IDs.
- External: none (no Stripe in v1).

## 7. Observability

- Metrics:
  - `flicko_economy_credit_total{server,source}`
  - `flicko_economy_debit_total{server,sink}`
  - `flicko_economy_balance_drift{server}` gauge
  - `flicko_economy_daily_claim_total{server}`
  - `flicko_economy_velocity_blocked_total{source}`
  - histogram `flicko_economy_op_seconds{op}`
- Logs: structured JSON, zerolog. Errors -> Sentry with `server_id` tag.
- Traces: OTel span around every public service method.
- Dashboards: Grafana board `flicko/economy` with 8 panels (rps, latency, drift, claim rate, top sources, fraud blocks, queue lag, error rate).

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| Postgres replica lag | stale balance | always read from primary after a write within 200ms, fall back to cache stamped with version |
| Redis cache miss storm | DB hammered | request coalescing in service layer (singleflight per wallet) |
| NATS earn-worker crash | missed credits | jetstream durable consumer + retry; audit reconciles |
| Velocity cap false-positive | user blocked from earning | downgrade to "warn" log if user has trust score >0.8 |
| Currency rename storms cache | wrong icon shown briefly | publish `currency.updated`; cache TTL <=30s |
| Double-spend race | negative balance | row-level `SELECT ... FOR UPDATE` on wallet during debit, plus CHECK constraint balance >= 0 |
| Time skew across regions | wrong daily window | server stores TZ; worker uses `AT TIME ZONE` consistently |
| Mod abuse (mass grant) | inflation | per-mod daily grant cap (configurable, default 50k); audit |
