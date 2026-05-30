# Accent Colors — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze + design review of palette + contrast | 1d | PM/Design |
| 1 | DB migration `125_accent_colors` | 0.5d | Backend |
| 2 | Backend: extend `user_settings_service` + handler validation + entitlement | 1d | Backend |
| 3 | Mobile: feature folder, providers, repository | 1d | Mobile |
| 4 | Mobile: AccentColorScreen + CustomHexSheet + entry rows | 1.5d | Mobile |
| 5 | Wire ThemeData override + audit retry queue | 0.5d | Mobile |
| 6 | QA, golden tests, contrast tests, a11y audit | 1d | QA |
| 7 | Beta rollout (1% → 10% → 50% → 100%) | 3d | All |
| 8 | GA + dashboard | 0.5d | All |

Total: ~10 working days.

## 2. Backend Tasks

- [ ] Create `supabase/migrations/125_accent_colors.up.sql` and `.down.sql`.
- [ ] Extend `backend/internal/models/user_settings.go` with `AccentColor string \`db:"accent_color" json:"accent_color"\``.
- [ ] Add `backend/internal/services/accent_color_validator.go`:
  - `IsPaletteColor(hex string) bool` checks against `paletteV1` const slice.
  - `ContrastRatio(hex string, bg string) float64` (relative-luminance per WCAG 2.1).
  - `Validate(hex string, isPlus bool) error` returns typed errors.
- [ ] Extend `backend/internal/services/user_settings_service.go::UpdateSettings`:
  - If patch contains `accent_color`, call validator.
  - Emit Prometheus counter.
  - `SET LOCAL flicko.accent_source = 'palette'|'custom'` inside the txn before UPDATE.
- [ ] Update `backend/internal/handlers/user_settings_handler.go` to surface 400/402/422 with stable error codes.
- [ ] Service test `accent_color_validator_test.go` — table-driven, ≥95% cov on validator.
- [ ] Handler test in `user_settings_handler_test.go` covering: free + palette ✓, free + custom ✗, plus + custom ✓, plus + low-contrast ✗, malformed hex ✗.
- [ ] No new route — extends existing PATCH.
- [ ] Add Prometheus counters to `backend/internal/metrics/metrics.go`.
- [ ] OpenAPI doc: add `accent_color` field to UserSettings schema.

## 3. Mobile Tasks

- [ ] Create `mobile/lib/features/accent_colors/`:
  - `data/accent_color_repository.dart` (DTO + Dio call).
  - `domain/accent_palette.dart` (16 const swatches with name + ratio).
  - `domain/accent_validator.dart` (mirrors backend; pure Dart).
  - `application/accent_color_provider.dart` (`Notifier<Color>`):
    - reads from `SharedPreferences` synchronously on first build,
    - subscribes to `userSettingsProvider` for cross-device reconcile,
    - exposes `setAccent(Color)`, `reset()`, retry queue logic.
  - `presentation/accent_color_screen.dart`.
  - `presentation/widgets/swatch_grid.dart`, `swatch_tile.dart`, `live_preview.dart`, `custom_hex_sheet.dart`.
- [ ] Wrap `themeDataProvider` in `mobile/lib/core/theme/theme_provider.dart`:
  - Read `accentColorProvider`.
  - `themeData.copyWith(colorScheme: themeData.colorScheme.copyWith(primary: accent, secondary: accent))`.
- [ ] Add row to `mobile/lib/features/settings/presentation/appearance_settings_screen.dart`.
- [ ] Add to `mobile/lib/core/router/app_router.dart` route `/settings/appearance/accent`.
- [ ] L10n keys in `mobile/lib/l10n/app_en.arb` (10 strings — see UIUX.md §7).
- [ ] Onboarding step in `mobile/lib/features/onboarding/presentation/...` with skip + continue.
- [ ] Tests:
  - widget: `accent_color_screen_test.dart`,
  - provider: `accent_color_provider_test.dart`,
  - golden: dark + light + AMOLED palette grids,
  - contrast: `accent_palette_contrast_test.dart` asserts ≥4.5:1 for every swatch in every theme.
- [ ] States: empty (n/a), error, loading skeleton, paywall, saved-locally.

## 4. AI / Infra Tasks

None.

## 5. Files Touched (predicted)

```
backend/
  internal/services/user_settings_service.go         (edit)
  internal/services/accent_color_validator.go        (new)
  internal/services/accent_color_validator_test.go   (new)
  internal/handlers/user_settings_handler.go         (edit)
  internal/handlers/user_settings_handler_test.go    (edit)
  internal/models/user_settings.go                   (edit)
  internal/metrics/metrics.go                        (edit)
mobile/
  lib/features/accent_colors/data/accent_color_repository.dart   (new)
  lib/features/accent_colors/domain/accent_palette.dart          (new)
  lib/features/accent_colors/domain/accent_validator.dart        (new)
  lib/features/accent_colors/application/accent_color_provider.dart (new)
  lib/features/accent_colors/presentation/accent_color_screen.dart  (new)
  lib/features/accent_colors/presentation/widgets/swatch_grid.dart   (new)
  lib/features/accent_colors/presentation/widgets/swatch_tile.dart   (new)
  lib/features/accent_colors/presentation/widgets/live_preview.dart  (new)
  lib/features/accent_colors/presentation/widgets/custom_hex_sheet.dart (new)
  lib/features/settings/presentation/appearance_settings_screen.dart (edit)
  lib/core/theme/theme_provider.dart                                (edit)
  lib/core/router/app_router.dart                                   (edit)
  lib/l10n/app_en.arb                                              (edit)
  test/features/accent_colors/...                                  (new)
supabase/
  migrations/125_accent_colors.up.sql                              (new)
  migrations/125_accent_colors.down.sql                            (new)
```

## 6. Test Plan

- Unit: validator ≥95%; provider ≥85%; widget renders correct swatch count, marks selected.
- Integration: Postgres migration applies; PATCH round-trip via testcontainers; entitlement matrix.
- Golden: 16 swatches × 4 themes × 2 sizes.
- E2E (Patrol): launch app → settings → accent → pick → relaunch → still applied.
- Load: PATCH endpoint already load-tested at 200 rps; re-run with new validator path.
- Accessibility: axe-flutter pass + manual TalkBack/VoiceOver swatch labelling check.
- Contrast: automated test asserts every swatch ≥ 4.5:1 in dark, light, AMOLED, plus.
- Security: confirm 402/422 cannot be bypassed by client; fuzz hex input with 1k random strings.

## 7. Rollout & Feature Flags

- Flag: `feature.accent_colors.enabled` (Doppler / `flicko_feature_flags`).
- Default OFF in prod.
- Beta cohort: 12 internal staff + 50 invited testers.
- Canary: 1% (24h) → 10% (24h) → 50% (24h) → 100% over 4 days.
- Kill switch tested in staging by toggling Doppler key and verifying app falls back to default purple within one foreground.

## 8. Rollback Plan

1. Disable `feature.accent_colors.enabled` (instant — UI hides entry points; backend keeps reading column).
2. If validator regression, hot-fix patch reverting validator file.
3. Down migration (`125_accent_colors.down.sql`) only if data corruption — accent column drop is destructive; require explicit incident commander sign-off.
4. Audit table is safe to drop; no foreign keys point in.

## 9. Dependencies / Blockers

- Depends on: `user_settings` table (shipped), `premium_handler` entitlement helper (shipped), `flicko_feature_flags` (shipped).
- Blocks: server-level accent override (09-customization) requires this column to exist.
- External: none.

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Palette swatch fails AA in `plus` theme variant | M | M | contrast test in CI; design reviews each swatch in all 4 themes |
| Cross-device race overwrites local pick | L | L | last-write-wins by `updated_at`; UI never blocks |
| Plus downgrade leaves user on custom hex | M | L | nearest-palette snap on read, one-time toast |
| Theme rebuild jank on low-end Android | L | M | benchmark on Pixel 4a; `copyWith` only |
| Color-blind users pick a low-info color | L | L | swatch hidden code overlay + bold-text toggle |

## 11. Cost Model

| Component | Free tier? | Estimated $ at 100k DAU |
|-----------|-----------|--------------------------|
| Compute (PATCH /settings) | Railway free | $0 (rides on existing endpoint) |
| Postgres storage (7 chars per user) | Supabase free | $0 (~700KB at 100k users) |
| Audit table (90d retention) | Supabase free | <$1 (avg 2 changes/user lifetime, ~14 bytes/row) |
| Redis | upstash free | $0 |
| **Total** | | **$0** |

## 12. Done Definition

- [ ] All tasks above checked.
- [ ] Migration applied to staging and dogfood.
- [ ] Code merged to main behind flag.
- [ ] Metrics dashboard live (top colors, change rate, error rate).
- [ ] Beta feedback ≥ 4.0/5 (n ≥ 30).
- [ ] Zero P0/P1 bugs in 7-day beta window.
- [ ] Contrast test in CI green for 30 consecutive runs.
- [ ] L10n strings translated for the top 6 locales.
