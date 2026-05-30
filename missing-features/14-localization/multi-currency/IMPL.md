# Multi-Currency — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze, OXR signup, Frankfurter fallback test | 1d | PM/Backend |
| 1 | Migration 260 + currency seed data | 1d | Backend |
| 2 | FX sync worker (OXR + fallback) | 2d | Backend |
| 3 | `format_money` Go helper + tests | 2d | Backend |
| 4 | Pricing handlers augmented with display payload | 2d | Backend |
| 5 | Mobile `MoneyFormat` + `LocalizedPrice` widget | 2d | Mobile |
| 6 | Migrate Boost/Premium/Marketplace screens | 3d | Mobile |
| 7 | Settings → currency picker | 1d | Mobile |
| 8 | Receipts in mail-gateway show local + USD | 1d | Backend |
| 9 | QA, A/B test setup, beta | 3d | All |

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/260_multi_currency.up.sql` (creates `currencies`, `currency_rates`; adds `profiles.preferred_currency`, `region_currency_defaults`)
- [ ] Down migration
- [ ] Seed top-50 currencies + region defaults
- [ ] Model `backend/internal/models/currency.go`, `backend/internal/models/currency_rate.go`
- [ ] Service `backend/internal/services/i18n/multi-currency/service.go`
- [ ] Sync worker `backend/internal/services/i18n/multi-currency/sync_worker.go`
- [ ] Sync GitHub Action `.github/workflows/fx-sync.yml`
- [ ] Middleware `backend/internal/middleware/currency.go`
- [ ] Modify pricing handlers (`boosts_handler.go`, `premium_handler.go`, `marketplace_handler.go`, `gifts_handler.go`)
- [ ] Wire `display` payload into responses
- [ ] Receipt template injection in mail-gateway (`receipt.html` shows both)
- [ ] Tests: ≥90% coverage on service + worker
- [ ] Audit log entry on user-initiated currency change
- [ ] Metrics: `fx_sync_total`, `fx_age_hours`, `money_format_errors_total`
- [ ] OpenAPI: document new payload shape

## 3. Mobile Tasks

- [ ] `mobile/lib/core/currency/data/currency_repository.dart`
- [ ] `mobile/lib/core/currency/domain/currency.dart`, `money.dart`
- [ ] `mobile/lib/core/currency/application/currency_provider.dart`
- [ ] `mobile/lib/core/currency/application/fx_rates_provider.dart` (cached, refreshed at app start + 12h)
- [ ] `mobile/lib/core/currency/presentation/localized_price.dart`
- [ ] Settings entry `mobile/lib/features/settings/presentation/currency_settings_screen.dart`
- [ ] Update existing pricing screens to use `LocalizedPrice`:
  - `mobile/lib/features/server_boosts/`
  - `mobile/lib/features/premium/`
  - `mobile/lib/features/marketplace/`
  - `mobile/lib/features/gifts/`
- [ ] Tests: golden test for `LocalizedPrice` × top 10 currencies × dark/light
- [ ] Provider tests for `CurrencyProvider`
- [ ] E2E: locale=pt-BR, region=BR — Premium shows `R$ 24,90` style

## 4. Files Touched (predicted)

```
backend/
  internal/services/i18n/multi-currency/service.go        (new)
  internal/services/i18n/multi-currency/sync_worker.go    (new)
  internal/services/i18n/multi-currency/service_test.go   (new)
  internal/middleware/currency.go                         (new)
  internal/models/currency.go                             (new)
  internal/models/currency_rate.go                        (new)
  internal/handlers/boosts_handler.go                     (edit)
  internal/handlers/premium_handler.go                    (edit)
  internal/handlers/marketplace_handler.go                (edit)
  internal/handlers/gifts_handler.go                      (edit)
  cmd/server/main.go                                      (edit)
mail-gateway/
  templates/receipt/en.html                               (edit)
  templates/receipt/_shared/local_amount_block.html       (new)
mobile/
  lib/core/currency/...                                   (new tree)
  lib/features/server_boosts/presentation/...             (edit)
  lib/features/premium/presentation/...                   (edit)
  lib/features/marketplace/presentation/...               (edit)
  lib/features/gifts/presentation/...                     (edit)
  lib/features/settings/presentation/currency_settings_screen.dart (new)
.github/
  workflows/fx-sync.yml                                   (new)
supabase/
  migrations/260_multi_currency.up.sql                    (new)
  migrations/260_multi_currency.down.sql                  (new)
```

## 5. Test Plan

- Unit: Go ≥90% on currency service; Dart ≥80% on MoneyFormat.
- Property: round-trip USD↔ccy stays within 1 cent for 100 random samples.
- Golden: Boost screen × top 10 ccys = 10 goldens.
- Integration: simulate OXR primary fail → assert Frankfurter fallback.
- Load: k6 — `/api/v1/i18n/fx/rates` 5k rps for 5 min; p99 < 50ms.
- Accessibility: number reading by VoiceOver in 5 locales (it speaks the right currency name).
- A/B test setup: feature flag splits traffic by user_id mod 2; metrics collected.

## 6. Rollout & Feature Flags

- Flag: `feature.multi_currency.enabled` (default ON post-GA).
- Phase 1: shadow — backend computes display ccy, stored in event logs; UI still shows USD.
- Phase 2: secondary display — `$4.99 USD ~ ₹417`.
- Phase 3: primary local, secondary USD — `₹417 (charged $4.99 USD)`.
- Per-currency flag: `feature.multi_currency.allowlist` to disable a problematic ccy.
- Kill switch: turning off reverts to USD-only.

## 7. Rollback Plan

1. Disable flag → all UI reverts to USD-only display; receipts still show USD.
2. If `currency_rates` corrupted (e.g. zeros), worker reseeds from prior day or Frankfurter.
3. No down migration needed for safe rollback — feature flag is sufficient.

## 8. Dependencies / Blockers

- Depends on: `multi-language-50` (locale codes drive `intl.NumberFormat`), `profiles` table (column add).
- Blocks: nothing critical; Receipt enhancement runs in parallel.
- External: OXR free-tier signup (~5 min, automated).

## 9. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| FX provider outage | Low | Medium | Frankfurter fallback; stale rates with banner |
| Mis-rounded display vs charge | Medium | Low | Always show "(charged in USD)" footnote; transparent fine print |
| Restricted-currency divergence | High (for ARS, VES) | Low | "~" prefix + disclaimer |
| User confusion across two currencies on screen | Medium | Medium | UX testing; clear hierarchy (local primary) |
| Storage of duplicate price columns | Low | Trivial | We don't store; format on read |

## 10. Cost Model

| Component | Free tier? | Estimated $ at 100k DAU |
|-----------|-----------|--------------------------|
| OXR free 1k/mo | Yes (~30/mo used) | $0 |
| Frankfurter free | Yes | $0 |
| Storage `currency_rates` | trivial (~10kb) | $0 |
| Compute (format_money in process) | n/a | $0 |
| **Total** | | **$0** target |

## 11. Done Definition

- [ ] All tasks above checked
- [ ] FX sync running 7+ days without manual intervention
- [ ] All four pricing surfaces show local currency
- [ ] Settings picker live; A/B test concluded
- [ ] Conversion lift ≥+5% in non-US cohort (ship even if neutral)
- [ ] Zero P0/P1 currency bugs in 7-day window
- [ ] Receipt emails include both local + USD lines
