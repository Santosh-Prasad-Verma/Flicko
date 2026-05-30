# Server Economy — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze + threat model | 2d | PM/Sec |
| 1 | DB migration 175 + ledger primitives | 2d | Backend |
| 2 | Service: credit/debit/transfer with idem | 3d | Backend |
| 3 | Earn-worker (NATS), velocity guard, daily | 3d | Backend |
| 4 | Mobile UI: wallet, claim, leaderboard | 4d | Mobile |
| 5 | Mod tools + currency settings + audit hookup | 2d | Both |
| 6 | Realtime via Centrifugo + cache | 1d | Backend |
| 7 | QA, recon job, load test | 3d | QA |
| 8 | Beta (1% -> 10%) | 5d | All |
| 9 | GA | 1d | All |

Total: ~26 dev days.

## 2. Backend Tasks

- [ ] `supabase/migrations/175_server_economy.up.sql` (tables, RLS, triggers, grants).
- [ ] `175_server_economy.down.sql`.
- [ ] `backend/internal/models/economy.go` — `Wallet`, `Currency`, `Entry`, `Transaction`, `ClaimResult`.
- [ ] `backend/internal/repo/economy_repo.go` — pgx queries, all wallet writes inside `tx.BeginTx(SerializableReadWrite)` + `SELECT ... FOR UPDATE`.
- [ ] `backend/internal/services/economy/server-economy/service.go`:
  - `Credit`, `Debit`, `Transfer` — accept `idempotencyKey`; on conflict return existing transaction id.
  - `ClaimDaily` — single-flight per `wallet_id` to dedupe storms.
  - Apply velocity check via Redis `INCRBY` with TTL aligned to bucket.
- [ ] `backend/internal/services/economy/server-economy/earn_worker.go` — durable jetstream consumer.
- [ ] `backend/internal/services/economy/server-economy/reconciliation_worker.go` — nightly drift check, alert via PagerDuty.
- [ ] `backend/internal/handlers/economy/wallet_handler.go`, `currency_handler.go`, `daily_handler.go`, `mod_handler.go`.
- [ ] Wire routes in `backend/cmd/server/main.go` under `/api/v1/servers/:sid/economy/...`.
- [ ] Permission middleware: introduce `MANAGE_ECONOMY` permission bit (extend permission map).
- [ ] Centrifugo channel publisher in `service.go` after every wallet mutation, never inside the tx (publish post-commit).
- [ ] Audit log entries via existing `audit_service.go` with `category=economy`.
- [ ] Metrics counters wired to existing prometheus registry.
- [ ] OpenAPI updates in `backend/api/openapi.yaml`.
- [ ] Tests:
  - Table-driven credit/debit/transfer (concurrency, idempotency, negative balance).
  - Property test: random sequence of 10k ops never violates `SUM(entries) == balance`.
  - Velocity cap unit test.
  - Race test using `go test -race` with 32 goroutines on a single wallet.

## 3. Mobile Tasks

- [ ] Feature folder `mobile/lib/features/economy/server_economy/`.
- [ ] Data layer: `economy_dto.dart`, `economy_remote_datasource.dart`, `economy_repository_impl.dart`.
- [ ] Domain: `wallet.dart`, `currency.dart`, `transaction_entry.dart`, usecases (`claim_daily`, `transfer`, `mod_grant`).
- [ ] Application: Riverpod `walletProvider`, `leaderboardProvider`, `currencyConfigProvider`, `dailyStatusProvider`.
- [ ] Presentation: `wallet_screen.dart`, `leaderboard_screen.dart`, `currency_settings_screen.dart`, `mod_grant_sheet.dart`, `transaction_detail_sheet.dart`, widgets (`balance_card.dart`, `daily_claim_button.dart`, `transaction_tile.dart`, `leaderboard_row.dart`).
- [ ] Routing in `mobile/lib/core/router/app_router.dart`: routes `/server/:id/wallet`, `/server/:id/wallet/leaderboard`, `/server/:id/wallet/settings`.
- [ ] L10n keys in `mobile/lib/l10n/app_en.arb` (locks: `walletTitle`, `claimDailyCta`, `streakLabel`, `frozenBanner`, ...).
- [ ] Centrifugo subscription manager in `economy_remote_datasource.dart` listens to `economy:<sid>` and dispatches into providers.
- [ ] Tests: widget test for `BalanceCard`, provider test for `WalletProvider`, golden tests for wallet screen across light/dark/amoled.
- [ ] Empty / error / loading / frozen states implemented and visually verified in `widgetbook` story.

## 4. AI / Infra Tasks

- N/A. No AI dependency. Anti-fraud uses rule-based + simple ratio detector in v1; ML scoring deferred.

## 5. Files Touched (predicted)

```
backend/
  internal/models/economy.go                              (new)
  internal/repo/economy_repo.go                           (new)
  internal/services/economy/server-economy/service.go     (new)
  internal/services/economy/server-economy/earn_worker.go (new)
  internal/services/economy/server-economy/reconciliation_worker.go (new)
  internal/handlers/economy/{wallet,currency,daily,mod}_handler.go  (new)
  cmd/server/main.go                                      (edit: routes)
  internal/auth/permissions.go                            (edit: MANAGE_ECONOMY)
  api/openapi.yaml                                        (edit)
mobile/
  lib/features/economy/server_economy/...                 (new tree)
  lib/core/router/app_router.dart                         (edit)
  lib/l10n/app_en.arb                                     (edit)
supabase/
  migrations/175_server_economy.up.sql                    (new)
  migrations/175_server_economy.down.sql                  (new)
```

## 6. Test Plan

- Unit: >=85% on service + repo. Property test with `pgo/quick` for ledger invariant.
- Integration: testcontainers Postgres + Redis + NATS. Full flow: enable currency -> provision -> earn -> daily -> grant -> revoke -> reconcile.
- Concurrency: 200 goroutines hammering `Debit` on same wallet; assert no negative balance and exactly N debits succeed.
- Idempotency: replay every write 5x; expect single ledger entry.
- Reconciliation: inject 1 fake drift row; verify worker alerts.
- E2E: Patrol flow — admin enables economy, member claims daily, mod grants 500, member sees push.
- Load: k6 — 1k rps mixed credit/debit on 50 servers, 5 minutes; p99 <300ms.
- Accessibility: axe audit + manual TalkBack + VoiceOver pass on wallet + claim flow.
- Security: tabletop threat model — abuse vectors (alt accounts, time-zone bypass, idempotency-key reuse, mod self-grant). All mitigated.

## 7. Rollout & Feature Flags

- Flag: `feature.server_economy.enabled` (Doppler).
- Default OFF in prod.
- Beta: 10 internal communities for 5 days.
- Canary: 1% -> 10% -> 50% -> 100% over 7 days.
- Kill switch tested in staging by toggling flag mid-traffic, verifying gracefully disabled UI.

## 8. Rollback Plan

1. Toggle flag OFF — UI hides instantly, server returns 503 from economy endpoints with copy `Economy is temporarily off.`.
2. Stop earn-worker + daily-worker.
3. Leave tables in place. Down migration only on data corruption.
4. Centrifugo channels remain — clients ignore events when feature flag is off.

## 9. Dependencies / Blockers

- Depends on: existing `auth-svc`, `audit-svc`, `notification-svc`, Centrifugo cluster, Redis.
- Blocks: server-marketplace, digital-gifts, reward-system, server-shop, event-tickets.
- External: none.

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Ledger drift due to bug | low | sev-1 outage | invariant test + nightly recon + immutable rules |
| Velocity cap miscomputed under clock skew | med | unfair earn loss | use server time only; bucket key includes UTC hour |
| Mod self-grant abuse | med | inflation | per-mod daily cap, audit, alert if >5x median |
| Cross-tenant leak via Centrifugo | low | severe | namespace channel `economy:<sid>`; client SDK rejects mismatched server |
| CSV importer (phase 2) corrupts ledger | med | reversible | importer uses dedicated `kind=import` txn, dry-run mode default |

## 11. Cost Model

| Component | Free tier? | Estimated $ at 100k DAU |
|-----------|-----------|--------------------------|
| Compute (economy-svc + workers) | Railway Hobby | $0-12 |
| Postgres rows + storage | Supabase free up to 500MB | $0 |
| Redis | Upstash free 10k cmd/day | $0-5 |
| NATS jetstream | self-hosted on existing VM | $0 |
| **Total** | | **<$20** target |

## 12. Done Definition

- [ ] All tasks above checked.
- [ ] Code merged to `main`, all CI green.
- [ ] Beta cohort feedback >=4.0/5 on the wallet experience.
- [ ] Reconciliation worker has run 7 nights with zero drift in beta.
- [ ] No P0/P1 bugs open after 7-day post-GA window.
- [ ] Metrics dashboard live + alert routes configured.
- [ ] INDEX.md status flipped to `shipped` for this slug.
