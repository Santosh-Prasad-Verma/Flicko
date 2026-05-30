# Custom Fonts (Basic) — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze, font licensing review, design review | 1d | PM/Design + Legal |
| 1 | Source + subset 7 font families; commit assets | 1d | Mobile |
| 2 | DB migration `128_custom_fonts_basic` + seed catalog | 0.5d | Backend |
| 3 | Backend validator + handler extension | 0.5d | Backend |
| 4 | Mobile feature folder + provider + repository | 1d | Mobile |
| 5 | Mobile FontPickerScreen + LiveChatPreview + entry rows | 1.5d | Mobile |
| 6 | Wire ThemeData propagation | 0.5d | Mobile |
| 7 | Onboarding step | 0.5d | Mobile |
| 8 | QA + golden + a11y audit | 1d | QA |
| 9 | Beta rollout (1% → 10% → 50% → 100%) | 3d | All |
| 10 | GA + dashboard | 0.5d | All |

Total: ~10 working days.

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/128_custom_fonts_basic.up.sql` and `.down.sql`.
- [ ] Seed `font_catalog` with the 7 v1 entries.
- [ ] Extend `backend/internal/models/user_settings.go` with `FontFamily string \`db:"font_family" json:"font_family"\``.
- [ ] Validator `backend/internal/services/font_family_validator.go`:
  - `var allowedFonts = []string{...}`
  - `IsAllowed(name string) bool`
- [ ] Service test `font_family_validator_test.go` table-driven, ≥95% cov.
- [ ] Update `user_settings_service.go::UpdateSettings` to call validator when `font_family` is present in patch; `SET LOCAL flicko.font_source = ...`.
- [ ] Update `user_settings_handler.go` to parse + return field; map validator error to 422.
- [ ] Add `GET /api/v1/font-catalog` (cached, public): returns enabled rows from `font_catalog` for clients to surface new fonts before app update.
- [ ] Handler tests for: valid font ✓, invalid font ✗, unset = no-change.
- [ ] Prometheus counters `flicko_font_family_changes_total{family}` and `flicko_font_family_validation_failures_total{reason}`.
- [ ] OpenAPI doc update.

## 3. Mobile Tasks

- [ ] Source font files into `mobile/assets/fonts/<Family>/`:
  - Inter (Regular, Medium, Bold).
  - Roboto (Regular, Medium, Bold).
  - OpenDyslexic (Regular, Bold).
  - Atkinson Hyperlegible (Regular, Bold).
  - JetBrains Mono (Regular, Bold).
  - Lora (Regular, Bold).
  - Comfortaa (Regular, Bold).
- [ ] Run `mobile/scripts/subset_fonts.py` to subset Latin + Latin Extended + Cyrillic + Greek; commit subsetted output.
- [ ] Add `LICENSE.txt` per family to `mobile/assets/fonts/<Family>/`.
- [ ] Update `mobile/pubspec.yaml` `fonts:` section with all 7 families and weights.
- [ ] Create `mobile/lib/features/custom_fonts/`:
  - `data/font_repository.dart` (delegates to existing user-settings repo).
  - `domain/font_catalog.dart` — `const` list of `FontEntry`.
  - `domain/font_entry.dart`.
  - `application/font_family_provider.dart`:
    - `Notifier<String>`,
    - reads `SharedPreferences` synchronously on first build,
    - subscribes to `userSettingsProvider` for cross-device reconcile,
    - exposes `set(String id)`, `reset()`, retry queue.
  - `presentation/font_picker_screen.dart`.
  - `presentation/widgets/font_card.dart`, `live_chat_preview.dart`.
- [ ] Wrap `themeDataProvider` in `mobile/lib/core/theme/theme_provider.dart`:
  - read `fontFamilyProvider`,
  - apply via `theme.copyWith(textTheme: theme.textTheme.apply(fontFamily: chosen, fontFamilyFallback: ...))`.
- [ ] Ensure code-block style overrides global font (always JetBrains Mono).
- [ ] Add row to `mobile/lib/features/settings/presentation/appearance_settings_screen.dart`.
- [ ] Add link in `mobile/lib/features/settings/presentation/accessibility_settings_screen.dart`.
- [ ] Add to `mobile/lib/core/router/app_router.dart` route `/settings/appearance/font`.
- [ ] Onboarding step in `mobile/lib/features/onboarding/presentation/...`.
- [ ] L10n keys in `mobile/lib/l10n/app_en.arb` (~14 strings).
- [ ] Tests:
  - widget: `font_picker_screen_test.dart`,
  - widget: `font_card_test.dart`,
  - provider: `font_family_provider_test.dart`,
  - golden: every font × dark + light + AMOLED + Plus, sample line "The quick brown fox",
  - asset: `font_assets_present_test.dart` asserts each declared family loads,
  - integration: bold-text on/off renders bold weight.
- [ ] App-bundle-size CI check: assert `mobile/build/app/outputs/...apk` increase ≤ 4.0 MB.

## 4. AI / Infra Tasks

- [ ] None.

## 5. Files Touched (predicted)

```
backend/
  internal/services/user_settings_service.go            (edit)
  internal/services/font_family_validator.go            (new)
  internal/services/font_family_validator_test.go       (new)
  internal/handlers/user_settings_handler.go            (edit)
  internal/handlers/font_catalog_handler.go             (new)
  internal/handlers/user_settings_handler_test.go       (edit)
  internal/models/user_settings.go                      (edit)
  internal/metrics/metrics.go                           (edit)
mobile/
  assets/fonts/<7 families>/...                         (new)
  pubspec.yaml                                          (edit)
  scripts/subset_fonts.py                               (new)
  lib/features/custom_fonts/data/font_repository.dart   (new)
  lib/features/custom_fonts/domain/font_catalog.dart    (new)
  lib/features/custom_fonts/domain/font_entry.dart      (new)
  lib/features/custom_fonts/application/font_family_provider.dart (new)
  lib/features/custom_fonts/presentation/font_picker_screen.dart  (new)
  lib/features/custom_fonts/presentation/widgets/font_card.dart   (new)
  lib/features/custom_fonts/presentation/widgets/live_chat_preview.dart (new)
  lib/features/settings/presentation/appearance_settings_screen.dart   (edit)
  lib/features/settings/presentation/accessibility_settings_screen.dart (edit)
  lib/core/theme/theme_provider.dart                                   (edit)
  lib/core/router/app_router.dart                                      (edit)
  lib/l10n/app_en.arb                                                  (edit)
  test/features/custom_fonts/...                                       (new)
supabase/
  migrations/128_custom_fonts_basic.up.sql                             (new)
  migrations/128_custom_fonts_basic.down.sql                           (new)
```

## 6. Test Plan

- Unit: validator ≥95%; provider ≥85%; widget renders correct font count + selection.
- Integration: Postgres migration applies; PATCH round-trip via testcontainers; whitelist enforcement matrix.
- Golden: all 7 fonts × 4 themes × 2 dynamic-type sizes (1.0, 1.4).
- E2E (Patrol): launch app → settings → font → pick OpenDyslexic → relaunch → still applied.
- Asset test: `font_assets_present_test.dart` proves every declared family resolves to a `TextStyle` with correct `fontFamily`.
- Bundle-size CI: gate at +4.0 MB compressed.
- Accessibility: TalkBack/VoiceOver pass; bold-text + dynamic-type smoke.
- Security: confirm 422 cannot be bypassed; fuzz `font_family` with 1k random strings.

## 7. Rollout & Feature Flags

- Flag: `feature.custom_fonts_basic.enabled` (Doppler / `flicko_feature_flags`).
- Default OFF in prod for first release; assets ship anyway (no harm — they're zero-cost when unused; UI just hides the picker).
- Beta cohort: 12 internal staff + 50 invited users (mix of a11y users + design fans).
- Canary: 1% → 10% → 50% → 100% over 4 days.
- Kill switch: disable flag; UI hides; backend keeps reading column.

## 8. Rollback Plan

1. Disable `feature.custom_fonts_basic.enabled` (instant; hides picker; existing chosen fonts still render because assets are bundled).
2. If asset bug regression: hot-fix release with `defaultFont` forcing Inter.
3. Down migration only if data corruption — drops column; destructive; require incident commander sign-off.

## 9. Dependencies / Blockers

- Depends on: `user_settings` table (shipped), `flicko_feature_flags` (shipped), `themeDataProvider` (shipped).
- Blocks: nothing.
- External: SIL OFL / Apache 2.0 license review for the 7 fonts.

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| App size bloat | M | M | Per-family budget ≤600 KB; subsetter; CI gate |
| Glyph missing for non-Latin user | M | L | Fallback chain to system; banner on Save |
| Flutter font cache invalidation hurts cold start | L | M | Bench on Pixel 4a; only `copyWith` |
| License compliance overlooked | L | H | LICENSE.txt per family; Legal sign-off |
| Bold-text + variable axis collision | L | L | Ship Regular + Bold static files; no variable axes in v1 |
| User picks unreadable font and is confused | L | L | Reset always one tap; Inter labelled (default) |

## 11. Cost Model

| Component | Free tier? | Estimated $ at 100k DAU |
|-----------|-----------|--------------------------|
| Compute (PATCH /settings) | Railway free | $0 (rides existing endpoint) |
| Postgres storage (≤14 chars per user) | Supabase free | $0 (~1.4 MB at 100k users) |
| Audit table (90d) | Supabase free | <$1 |
| Mobile asset bundle delta | n/a | ~3.5 MB extra app size |
| **Total** | | **$0** |

## 12. Done Definition

- [ ] All tasks above checked.
- [ ] Migration applied to staging and dogfood.
- [ ] All 7 fonts render across 4 themes in goldens.
- [ ] App-bundle-size CI gate green.
- [ ] Code merged to main behind flag.
- [ ] Metrics dashboard live (top fonts, change rate, error rate, dyslexia uptake).
- [ ] Beta feedback ≥4.0/5 (n ≥ 30).
- [ ] Zero P0/P1 bugs in 7-day window.
- [ ] L10n strings translated for the top 6 locales.
- [ ] License files in repo + Legal sign-off recorded.
