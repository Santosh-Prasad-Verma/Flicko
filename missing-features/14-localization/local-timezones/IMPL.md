# Local Timezones — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze, audit existing DateFormat usages | 1d | Mobile |
| 1 | Migration 261 + profiles.timezone column | 0.5d | Backend |
| 2 | Backend: receipt + notification time formatting per recipient TZ | 1d | Backend |
| 3 | Mobile: `Timestamp` widget + `RelativeTime` helper | 1d | Mobile |
| 4 | Sweep: replace all date renderers across feature modules | 2d | Mobile |
| 5 | Settings TZ picker + dev pseudo-zone toggle | 1d | Mobile |
| 6 | Scheduled-event dual-TZ rendering | 1d | Mobile |
| 7 | CSV export augmentation | 0.5d | Backend |
| 8 | QA, golden tests, beta | 2d | All |

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/261_local_timezones.up.sql` — adds `profiles.timezone TEXT`
- [ ] Down migration
- [ ] Validation: regex `^[A-Za-z_]+/[A-Za-z_]+(/[A-Za-z_]+)?$|^UTC$`
- [ ] Service `backend/internal/services/i18n/local-timezones/service.go`
  - `FormatLocal(t time.Time, tz, locale string) string`
  - `IsValidTZ(tz string) bool`
- [ ] Notification builder uses `recipient.timezone` for date formatting
- [ ] Mail-gateway template helper `{{formatTime .Time .User.TZ .User.Locale}}`
- [ ] CSV export adds `timestamp_local`, `tz` columns
- [ ] PATCH `/profile/me` validates TZ before commit
- [ ] Tests: validity table-driven 50 cases (positive + negative)
- [ ] Metrics: counter on TZ change, gauge on null-TZ users

## 3. Mobile Tasks

- [ ] `mobile/lib/core/datetime/data/tz_repository.dart`
- [ ] `mobile/lib/core/datetime/application/tz_provider.dart` (Riverpod, watches profile)
- [ ] `mobile/lib/core/datetime/presentation/timestamp.dart` widget
- [ ] `mobile/lib/core/datetime/relative_time.dart` helper using `intl`
- [ ] Pubspec: ensure `timezone: ^0.9.4` is pinned
- [ ] Init `tz.initializeTimeZones()` in `main.dart` once
- [ ] Sweep:
  - [ ] `mobile/lib/features/messages/**`
  - [ ] `mobile/lib/features/notifications/**`
  - [ ] `mobile/lib/features/server_channels/**`
  - [ ] `mobile/lib/features/voice/**`
  - [ ] `mobile/lib/features/scheduled_events/**`
  - [ ] `mobile/lib/features/audit_log/**`
  - [ ] `mobile/lib/features/transactions/**`
- [ ] Replace `DateFormat` direct usages with `Timestamp` widget
- [ ] Settings: `mobile/lib/features/settings/presentation/timezone_settings_screen.dart`
- [ ] Dev menu: pseudo-zone toggle (`Etc/GMT-13` etc.)
- [ ] Tests: golden snapshot for `Timestamp` × 5 zones × 3 ages (now, hour ago, year ago)
- [ ] E2E: change TZ in Settings; confirm message list re-renders

## 4. Files Touched (predicted)

```
backend/
  internal/services/i18n/local-timezones/service.go     (new)
  internal/services/i18n/local-timezones/service_test.go (new)
  internal/handlers/profile_handler.go                  (edit — validation)
  internal/services/notifications/builder.go            (edit)
  internal/handlers/exports_handler.go                  (edit — csv columns)
mail-gateway/
  internal/template_funcs.go                            (edit — formatTime helper)
  templates/_shared/footer.html                         (edit)
mobile/
  lib/main.dart                                         (edit — initializeTimeZones)
  lib/core/datetime/...                                 (new tree)
  lib/features/**/...                                   (broad edit sweep, ~30 files)
  lib/features/settings/presentation/timezone_settings_screen.dart (new)
supabase/
  migrations/261_local_timezones.up.sql                 (new)
  migrations/261_local_timezones.down.sql               (new)
test/
  golden/timestamp/<tz>_<age>.png                       (new, 15 files)
```

## 5. Test Plan

- Unit: timezone validity (pos + neg), `FormatLocal` cases incl. half-hour zones, DST transitions.
- Widget: golden snapshots at "now", "5 min ago", "yesterday", "1 year ago" × `UTC`, `Asia/Tokyo`, `America/New_York`, `Asia/Kolkata`, `Pacific/Chatham` (12:45 zone).
- Integration: CSV export contains both UTC + local columns; sample rows match expected.
- E2E: switch TZ in Settings; observe message list reformat.
- Regression: pseudo-zone (`Etc/GMT-13`) reveals any hardcoded `DateFormat.Hms()` without TZ argument.

## 6. Rollout & Feature Flags

- Flag: `feature.local_timezones.enabled` (default ON once tests stable).
- Off: timestamps render in UTC (current behavior).
- Per-cohort: 100% rollout (low risk; reverts cleanly).

## 7. Rollback Plan

1. Disable flag → timestamps render in UTC.
2. `profile.timezone` column kept; no harm if unused.
3. CSV exports retain extra column even on rollback (forward-compatible).

## 8. Dependencies / Blockers

- Depends on: `multi-language-50` (locale passed to date formatting).
- Blocks: nothing.
- External: none — `tzdata` is bundled with `timezone` Dart package.

## 9. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Hardcoded DateFormat slips through | High | Medium | Lint rule banning `DateFormat.format(dt)` outside `core/datetime/` |
| Wrong TZ persisted from corrupted client | Low | Low | Server-side validation rejects |
| DST edge case mishandled | Low | Low | `intl` + `timezone` packages handle |
| User confused by relative+absolute | Low | Low | UX testing; clear copy |

## 10. Cost Model

| Component | Free? | Estimated $ at 100k DAU |
|-----------|-------|--------------------------|
| `timezone` package (bundled IANA) | yes | $0 |
| Storage of 1 TEXT col on profiles | trivial | $0 |
| **Total** | | **$0** target |

## 11. Done Definition

- [ ] All sweep tasks done
- [ ] Lint rule live in CI for 30 days
- [ ] Pseudo-zone reveals 0 hardcoded usages
- [ ] 15 golden tests green
- [ ] Receipts and notifications honor recipient TZ
- [ ] Beta feedback ≥4.0/5
- [ ] Zero P0/P1 timestamp bugs in 7-day window
