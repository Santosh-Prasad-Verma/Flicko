# Regional Content Filters — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze, legal review on initial rule set | 5d | Legal/PM |
| 1 | Migration 262 + region_rules tables | 1d | Backend |
| 2 | Region middleware + MaxMind integration | 2d | Backend |
| 3 | Filter service (regex/hash/attribute/age_gate) | 4d | Backend |
| 4 | Audit logging + NATS pipe | 1d | Backend |
| 5 | Hidden placeholder + explainer mobile UI | 3d | Mobile |
| 6 | Age attestation flow | 2d | Mobile |
| 7 | Pre-send warning composer integration | 2d | Mobile |
| 8 | Appeal form + admin appeals queue | 2d | Both |
| 9 | Admin rules editor (web) | 4d | Web |
| 10 | Transparency report page | 2d | Web |
| 11 | Compliance corpus + regression suite | 3d | QA |
| 12 | Beta + GA per region | 2w | All |

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/262_regional_content_filters.up.sql`
- [ ] Down migration
- [ ] Models in `backend/internal/models/region_rule.go`, `region_filter_audit.go`, `region_appeal.go`
- [ ] Service `backend/internal/services/i18n/regional-content-filters/service.go`
- [ ] Match engine: `regex.go`, `hash.go`, `attribute.go`, `age_gate.go` sub-files
- [ ] Region middleware `backend/internal/middleware/region.go` with priority chain
- [ ] MaxMind GeoLite2 loader (refresh monthly via cron)
- [ ] Wire filter into:
  - `messages_handler.go` (read)
  - `channels_handler.go` (read + write)
  - `servers_handler.go` (read + write)
  - `search_handler.go` (read)
  - `notifications_builder.go` (build-time)
  - `mail-gateway/internal/build.go` (build-time)
  - `aura_handler.go` (response sanitization)
- [ ] Pre-send classifier endpoint `POST /api/v1/i18n/preflight` returning warnings
- [ ] Audit writer (NATS publisher to async writer worker)
- [ ] Appeals endpoints
- [ ] Admin rules CRUD endpoints (RBAC: legal team only)
- [ ] Tests: ≥85% coverage on match engine; adversarial corpus
- [ ] Metrics & dashboards
- [ ] OpenAPI doc

## 3. Mobile Tasks

- [ ] `mobile/lib/core/region/data/region_repository.dart`
- [ ] `mobile/lib/core/region/application/region_provider.dart`
- [ ] `mobile/lib/core/region/presentation/hidden_placeholder.dart`
- [ ] `mobile/lib/core/region/presentation/hidden_explainer_sheet.dart`
- [ ] `mobile/lib/core/region/presentation/age_attestation_dialog.dart`
- [ ] `mobile/lib/core/region/presentation/appeal_form.dart`
- [ ] `mobile/lib/core/region/presentation/pre_send_warning.dart`
- [ ] Wire `HiddenAware<T>` adapter into:
  - `mobile/lib/features/messages/`
  - `mobile/lib/features/server_channels/`
  - `mobile/lib/features/search/`
  - `mobile/lib/features/profile/` (bio render)
- [ ] Settings: `mobile/lib/features/settings/presentation/region_settings_screen.dart`
- [ ] Tests: golden snapshot for hidden placeholder, age dialog
- [ ] E2E: simulate DE viewer + flagged message; verify placeholder + explainer

## 4. Web Admin Tasks

- [ ] `admin/regional-rules/` page (Next.js)
- [ ] Rule list, create, edit, soft-delete
- [ ] Activity log per rule
- [ ] Appeal queue with reviewer actions
- [ ] Transparency report public page

## 5. Files Touched (predicted)

```
backend/
  internal/services/i18n/regional-content-filters/service.go   (new)
  internal/services/i18n/regional-content-filters/regex.go     (new)
  internal/services/i18n/regional-content-filters/hash.go      (new)
  internal/services/i18n/regional-content-filters/attribute.go (new)
  internal/services/i18n/regional-content-filters/age_gate.go  (new)
  internal/middleware/region.go                                (new)
  internal/handlers/messages_handler.go                        (edit)
  internal/handlers/channels_handler.go                        (edit)
  internal/handlers/servers_handler.go                         (edit)
  internal/handlers/search_handler.go                          (edit)
  internal/handlers/aura_handler.go                            (edit)
  internal/handlers/admin/region_rules_handler.go              (new)
  internal/handlers/i18n/preflight_handler.go                  (new)
  internal/handlers/i18n/appeals_handler.go                    (new)
  internal/services/notifications/builder.go                   (edit)
mobile/
  lib/core/region/...                                          (new tree)
  lib/features/messages/...                                    (edit)
  lib/features/server_channels/...                             (edit)
  lib/features/search/...                                      (edit)
  lib/features/settings/presentation/region_settings_screen.dart (new)
admin/
  src/regional-rules/                                          (new)
  src/transparency/                                            (new)
mail-gateway/
  internal/build.go                                            (edit)
supabase/
  migrations/262_regional_content_filters.up.sql               (new)
  migrations/262_regional_content_filters.down.sql             (new)
```

## 6. Test Plan

- Unit: each rule kind ≥30 cases; assert false-positive rate target on golden corpus.
- Property: random adversarial inputs (zero-width, RTL marks, look-alikes); assert no panic, assert match works on normalized text.
- Integration: pg_notify → cache bust under 1s.
- E2E: 5 personas in 5 regions; assert each sees the right thing.
- Compliance regression: 500-sample golden corpus per region; weekly run.
- Load: k6 — 5k rps with 30 active rules; p99 < 50ms.
- Adversarial security: SSRF on rule definitions, regex DoS via timeout.

## 7. Rollout & Feature Flags

- Flag: `feature.regional_content_filters.enabled` (default OFF; on per region as legal review completes)
- Per-region flag: `feature.regional_content_filters.regions.<code>.enabled`
- Per-rule flag: each rule has its own enabled bool in DB
- Phase 1: shadow mode (audit only, no actual hide) for 7 days per region
- Phase 2: enable hides; monitor false-positive rate
- Phase 3: GA per region

## 8. Rollback Plan

1. Disable global flag → no items filtered, audits stop.
2. Disable per-region flag → that region returns to normal feed.
3. Disable per-rule → only that rule stops; others continue.
4. Hidden items become visible immediately (no cached UI rewrite needed; client refetches).

## 9. Dependencies / Blockers

- Depends on: `multi-language-50` (locale for explainer copy), `multi-currency` (for `profiles.region_code`)
- Blocks: nothing functionally
- External: legal sign-off on each rule before activation

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| False positive hides legitimate content | High | Medium | Appeal flow + golden corpus + phase-shadow |
| Bad regex DoS | Medium | High | RE2 + 50ms timeout |
| Region misdetection | Medium | Medium | Manual override always available |
| Legal change with no rule update | High | High | Quarterly legal review cadence |
| Admin tool misuse | Low | High | RBAC + audit log on every rule edit |
| Privacy concerns over audit data | Medium | Medium | DPIA + retention policies + anonymized exports |

## 11. Cost Model

| Component | Free? | Estimated $ at 100k DAU |
|-----------|-------|--------------------------|
| MaxMind GeoLite2 (free) | yes | $0 |
| Storage of rules + audit | trivial → ~$2/mo | ~$2 |
| NATS infra | already running | $0 |
| Compute for filter (in-process) | n/a | $0 |
| Legal review hours | one-time | sunk |
| **Total** | | **~$2/mo** |

## 12. Done Definition

- [ ] All sweep tasks done
- [ ] DE/KR/UK/US rules legal-reviewed and live
- [ ] False-positive rate <0.5% on golden corpus
- [ ] Audit logs persisted and exportable
- [ ] Transparency page live
- [ ] Appeal queue reviewer assigned
- [ ] Beta feedback ≥4.0/5
- [ ] Zero P0/P1 compliance bugs in 14-day window
