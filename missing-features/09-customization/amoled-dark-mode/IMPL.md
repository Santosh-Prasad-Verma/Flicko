# AMOLED Dark Mode — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Token audit (find hardcoded grays) | 1d | Mobile |
| 1 | AMOLED ThemeSpec preset asset | 1d | Mobile |
| 2 | Settings toggle + scheduler | 2d | Mobile |
| 3 | Battery-saver suggestion | 1d | Mobile |
| 4 | Backend: persist preference per user | 1d | Backend |
| 5 | QA + a11y audit | 1d | QA |
| 6 | GA | 1d | All |

Total: ~7d wall.

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/206_amoled_pref.up.sql` — add `amoled_pref` JSONB to `user_settings` table (or a new column to user_theme_overrides).
- [ ] Down migration.
- [ ] Service touch: `internal/services/themes/service.go::SetAmoledPref`.
- [ ] Handler `PATCH /api/v1/users/me/settings/amoled`.
- [ ] Service tests.
- [ ] Audit log entries.
- [ ] Metrics counters.

## 3. Mobile Tasks

- [ ] Asset `mobile/assets/themes/amoled.json` (compiled-in default).
- [ ] Token audit pass on:
  - `mobile/lib/features/server_channels/`
  - `mobile/lib/features/messaging/`
  - `mobile/lib/features/ai_assistant/`
  - `mobile/lib/features/gaming/`
  - any `Color(0x...)` literals replaced with `Theme.of(context).colorScheme...`.
- [ ] Provider `mobile/lib/features/themes/application/amoled_provider.dart`:
  - mode: `off | always | systemDark | sunset`
  - reads system brightness, location for sunset
- [ ] UI: extend `mobile/lib/features/settings/presentation/storage_settings_screen.dart` ... actually use Appearance settings screen. Add `amoled_settings_section.dart`.
- [ ] Battery saver listener via `battery_plus` package; one-shot snackbar.
- [ ] Hive persistence of mode.
- [ ] L10n keys.
- [ ] Tests: provider state transitions; widget golden of message list under AMOLED.

## 4. AI / Infra Tasks

- N/A.

## 5. Files Touched (predicted)

```
backend/
  internal/services/themes/service.go             (edit, add SetAmoledPref)
  internal/handlers/themes_handler.go             (edit)
mobile/
  lib/features/themes/application/amoled_provider.dart       (new)
  lib/features/settings/presentation/appearance_settings_screen.dart (edit or new section)
  lib/features/settings/presentation/widgets/amoled_settings_section.dart (new)
  lib/core/theme/theme_engine.dart                (edit, add applyAmoledPreset)
  assets/themes/amoled.json                       (new)
  lib/l10n/app_en.arb                             (edit)
supabase/
  migrations/206_amoled_pref.up.sql               (new)
  migrations/206_amoled_pref.down.sql             (new)
```

## 6. Test Plan

- Unit: provider state machine — every mode transition.
- Widget: golden of inbox + message thread under AMOLED.
- Integration: user opens settings, toggles mode, restarts, persists.
- Lint: a CI script greps for `Color(0xff[0-9a-f]{6})` outside `core/theme/` and fails build.
- Battery saver: simulator fakes battery saver, snackbar fires once per device per 30d.

## 7. Rollout & Feature Flags

- Flag: `feature.amoled.enabled`.
- Default OFF in prod (can ship with engine).
- Beta: 10% rollout for 3 days.
- Canary: 50% → 100% over 5d.

## 8. Rollback Plan

1. Disable flag (instant).
2. Mobile clients fall back to standard dark.
3. Leave preference rows; harmless when disabled.

## 9. Dependencies / Blockers

- Depends on: `full-theme-engine` (uses the same renderer).
- Blocks: nothing.

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Hardcoded grays leak (unaudited surfaces) | M | M | CI grep + golden tests |
| Sunset mode requires location | M | L | gated, default off, fallback to systemDark |
| Pure black on LCD looks crushed | L | L | settings hint |

## 11. Cost Model

| Component | Free tier? | Estimated $ at 100k DAU |
|-----------|-----------|--------------------------|
| Compute | Railway free | $0 |
| DB | Supabase free | $0 |
| **Total** | | **$0** |

## 12. Done Definition

- [ ] All tasks above checked
- [ ] Hardcoded gray lint passes on full mobile tree
- [ ] Goldens recorded
- [ ] Toggle visible in Settings → Appearance
- [ ] Battery saver one-shot prompt working
- [ ] Zero P0/P1 bugs in 7-day window
