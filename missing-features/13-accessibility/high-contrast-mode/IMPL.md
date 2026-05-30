# High Contrast Mode — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Token spec freeze + designer review | 2d | Design |
| 1 | Migration 253 (idempotent JSONB column add) | 0.5d | Backend |
| 2 | Theme files + tokens + provider | 2d | Mobile |
| 3 | Settings page + onboarding step | 1.5d | Mobile |
| 4 | CI contrast verifier script | 0.5d | DevOps |
| 5 | Cross-cutting widget audit (gradients, borders) | 2d | Mobile |
| 6 | Tests: golden, contrast math, Patrol | 2d | QA |
| 7 | Beta with low-vision testers | 4d | All |
| 8 | GA + a11y release notes | 0.5d | All |

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/253_accessibility_high_contrast.up.sql`
- [ ] Down migration `253_accessibility_high_contrast.down.sql`
- [ ] No new service or handler — reuse `user_preferences_handler.go`
- [ ] Add metrics counter `flicko_accessibility_hc_mode_total{mode}` in preferences-write path
- [ ] OpenAPI doc update for new keys

## 3. Mobile Tasks

- [ ] `mobile/lib/core/theme/contrast_tokens.dart` — declare token consts (light + dark) with comments noting WCAG ratio
- [ ] `mobile/lib/core/theme/high_contrast_theme.dart` — export `highContrastLightTheme`, `highContrastDarkTheme`
- [ ] `mobile/lib/core/theme/theme_provider.dart` — extend with HC resolution; integrate `MediaQuery.highContrast`
- [ ] `mobile/lib/features/accessibility/high_contrast/application/high_contrast_provider.dart`
- [ ] `mobile/lib/features/accessibility/high_contrast/application/contrast_resolver.dart`
- [ ] `mobile/lib/features/accessibility/high_contrast/data/preferences_datasource.dart`
- [ ] `mobile/lib/features/accessibility/high_contrast/presentation/screens/high_contrast_settings_screen.dart`
- [ ] `mobile/lib/features/accessibility/high_contrast/presentation/widgets/contrast_mode_picker.dart`
- [ ] `mobile/lib/features/accessibility/high_contrast/presentation/widgets/theme_preview_card.dart`
- [ ] `mobile/lib/features/onboarding/.../onboarding_a11y_hc_step.dart`
- [ ] `mobile/lib/features/server/.../accent_resolver.dart` — neutralise server accents under HC
- [ ] Routing: add to `mobile/lib/core/router/app_router.dart` (`/settings/accessibility/high-contrast`)
- [ ] L10n keys in `mobile/lib/l10n/app_en.arb` for all settings copy
- [ ] Tests: golden theme tests; contrast math unit tests; provider unit; Patrol switch test
- [ ] Empty/error/loading states on settings screen

## 4. AI / Infra Tasks

Not applicable.

## 5. Files Touched (predicted)

```
backend/
  supabase/migrations/253_accessibility_high_contrast.up.sql      (new)
  supabase/migrations/253_accessibility_high_contrast.down.sql    (new)
  internal/handlers/user_preferences_handler.go                   (edit, optional metrics)

mobile/
  lib/core/theme/contrast_tokens.dart                             (new)
  lib/core/theme/high_contrast_theme.dart                         (new)
  lib/core/theme/theme_provider.dart                              (edit)
  lib/core/theme/app_theme.dart                                   (edit)
  lib/features/accessibility/high_contrast/...                    (new tree)
  lib/features/onboarding/.../onboarding_a11y_hc_step.dart        (new)
  lib/features/server/.../accent_resolver.dart                    (edit)
  lib/features/server_channels/.../message_bubble.dart            (edit, gradient → flat)
  lib/features/voice/.../voice_tile.dart                          (edit, border weight)
  lib/core/router/app_router.dart                                 (edit)
  lib/l10n/app_en.arb                                             (edit)

tools/
  check_contrast.dart                                             (new CI script)
```

## 6. Test Plan

- **Unit:**
  - Contrast math: every body-text token pair ≥7:1; large text/components ≥4.5:1.
  - `accent_resolver.dart`: nearest-safe-color picker for arbitrary input colour.
  - `contrast_resolver.dart`: deterministic mapping `(mode, system_hc, brightness) → ThemeData`.
- **Widget golden:**
  - `MessageBubble` rendered under HC light + dark + neutralised server accent.
  - `VoiceTile` with HC border weight.
  - `ContrastModePicker` radio states.
- **Integration:**
  - Patrol: toggle HC mode, expect re-rendered tokens after 100 ms.
  - Patrol: change OS pref mid-test (using `flutter_test` `MediaQuery.highContrast`).
- **CI:** `dart run tools/check_contrast.dart` blocks merges on regression.
- **Manual:** quarterly low-vision tester pass.
- **Security:** preferences write always scoped to `auth.uid()`; tested with mismatched JWT.

## 7. Rollout & Feature Flags

- Flag: `feature.high_contrast_mode.enabled` (default ON).
- Sub-flag: `feature.high_contrast_mode.neutralize_accents.enabled` (default ON; per-server breakglass).
- Beta: 20 low-vision testers + general 2% canary.
- Canary ramp: 2% → 10% → 50% → 100% over 5 days.
- Kill switch: turning the flag off forces theme back to default (with one-time live region announcement).

## 8. Rollback Plan

1. Disable flag — UI reverts to default theme.
2. Leave migration in place; preference column is harmless when not read.
3. No data backfill needed.

## 9. Dependencies / Blockers

- Depends on: `theme_provider` (existing).
- Blocks: `color-blind-mode` (shares contrast resolver); `dyslexia-font` (shares preferences path).
- External: low-vision tester recruitment (1 week lead).

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Token drift over time | High | Med | CI contrast verifier |
| Server accent neutralisation backlash | Med | Low | Per-user opt-out |
| Theme switch flicker on web | Low | Low | `AnimatedTheme` cross-fade |
| Some illustrations look out of place | Low | Low | Document in design system; iterate post-GA |

## 11. Cost Model

| Component | Free tier? | Estimated $ at 100k DAU |
|-----------|-----------|--------------------------|
| Compute | Railway free | $0 |
| DB | Supabase free | $0 |
| AI | n/a | $0 |
| Storage | n/a | $0 |
| **Total** | | **$0** |

## 12. Done Definition

- [ ] All tasks above checked
- [ ] CI contrast verifier green for both light + dark
- [ ] Patrol test passes on Android 13/14 + iOS 17
- [ ] Manual low-vision tester sign-off (n≥3 testers, ≥4.5/5 satisfaction)
- [ ] Metrics dashboard live with adoption & accent-neutralisation counts
- [ ] Zero P0/P1 visual bugs in 14-day window post-GA
