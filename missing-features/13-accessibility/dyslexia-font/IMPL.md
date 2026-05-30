# Dyslexia Font — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | License audit + font asset prep | 1d | Legal/Mobile |
| 1 | Bundle fonts, register in pubspec | 0.5d | Mobile |
| 2 | TextTheme builder + provider | 1d | Mobile |
| 3 | Settings screen + preview | 1.5d | Mobile |
| 4 | Cross-cutting: monospace exclusion | 1d | Mobile |
| 5 | Tests: golden, provider unit | 1.5d | QA |
| 6 | Beta with self-identified users | 4d | All |
| 7 | GA + release notes | 0.5d | All |

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/254_accessibility_reader_font.up.sql` (idempotent JSONB key seeding only)
- [ ] Down migration `254_accessibility_reader_font.down.sql`
- [ ] No new service. Reuse `user_preferences_handler.go`.
- [ ] Validation in handler: clamp `reader_line_height` to [1.2, 2.0]; `reader_letter_spacing` to [0, 0.08].
- [ ] OpenAPI doc update.

## 3. Mobile Tasks

- [ ] Add fonts to `mobile/assets/fonts/`:
  - `OpenDyslexic-Regular.otf`
  - `OpenDyslexic-Bold.otf`
  - `AtkinsonHyperlegible-Regular.ttf`
  - `AtkinsonHyperlegible-Bold.ttf`
  - `LICENSE-OpenDyslexic.txt`
  - `LICENSE-AtkinsonHyperlegible.txt`
- [ ] Update `mobile/pubspec.yaml` `flutter.fonts` with the two families
- [ ] `mobile/lib/features/accessibility/dyslexia_font/application/reader_font_provider.dart`
- [ ] `mobile/lib/features/accessibility/dyslexia_font/application/text_theme_builder.dart`
- [ ] `mobile/lib/features/accessibility/dyslexia_font/data/preferences_datasource.dart`
- [ ] `mobile/lib/features/accessibility/dyslexia_font/domain/reader_font_prefs.dart`
- [ ] `mobile/lib/features/accessibility/dyslexia_font/presentation/screens/reader_font_settings_screen.dart`
- [ ] `mobile/lib/features/accessibility/dyslexia_font/presentation/widgets/reader_font_picker.dart`
- [ ] `mobile/lib/features/accessibility/dyslexia_font/presentation/widgets/spacing_slider.dart`
- [ ] `mobile/lib/features/accessibility/dyslexia_font/presentation/widgets/reader_font_preview.dart`
- [ ] `mobile/lib/features/accessibility/dyslexia_font/presentation/widgets/font_credits_dialog.dart`
- [ ] `mobile/lib/features/onboarding/.../onboarding_reader_font_step.dart`
- [ ] Routing: add to `mobile/lib/core/router/app_router.dart` (`/settings/accessibility/reader-font`)
- [ ] L10n keys
- [ ] `mobile/lib/core/theme/app_theme.dart` — accept `ReaderFontPrefs` and rebuild `textTheme`
- [ ] `mobile/lib/features/server_channels/.../code_block_widget.dart` — pin `fontFamily: 'JetBrainsMono'`
- [ ] Tests: golden snapshots per font; clamp tests; provider unit; Patrol toggle
- [ ] Empty/error/loading states on settings screen

## 4. AI / Infra Tasks

Not applicable.

## 5. Files Touched (predicted)

```
mobile/
  pubspec.yaml                                                (edit, register fonts)
  assets/fonts/OpenDyslexic-*.otf                             (new)
  assets/fonts/AtkinsonHyperlegible-*.ttf                     (new)
  assets/fonts/LICENSE-*.txt                                  (new)
  lib/core/theme/app_theme.dart                               (edit)
  lib/core/theme/theme_provider.dart                          (edit)
  lib/features/accessibility/dyslexia_font/...                (new tree)
  lib/features/onboarding/.../onboarding_reader_font_step.dart(new)
  lib/features/server_channels/.../code_block_widget.dart     (edit)
  lib/core/router/app_router.dart                             (edit)
  lib/l10n/app_en.arb                                         (edit)

backend/
  supabase/migrations/254_accessibility_reader_font.up.sql    (new)
  supabase/migrations/254_accessibility_reader_font.down.sql  (new)
  internal/handlers/user_preferences_handler.go               (edit, validation)
```

## 6. Test Plan

- **Unit:**
  - `text_theme_builder.dart` deterministic from prefs.
  - Backend handler clamps out-of-range values; returns 400 for invalid family enum.
- **Widget golden:**
  - Sample message rendered in three fonts.
  - Code-block widget unaffected by font preference.
- **Integration:**
  - Patrol test: toggle font, expect new metrics within 200 ms.
- **Manual:**
  - Confirm CJK fallback (Japanese / Hindi text renders cleanly).
  - Confirm emoji rendering unchanged.
- **Security:** preference write scoped to `auth.uid()`.

## 7. Rollout & Feature Flags

- Flag: `feature.dyslexia_font.enabled` (default ON).
- Sub-flag: `feature.dyslexia_font.atkinson.enabled` (in case we want to land OpenDyslexic first).
- Beta: 5% canary including dyslexia-self-id users.
- Canary: 5% → 25% → 100% over 5 days.
- Kill switch: turning off the flag forces system default font (preference preserved).

## 8. Rollback Plan

1. Disable flag.
2. UI reverts to system default font.
3. Bundled fonts remain in app; small APK footprint left in place.

## 9. Dependencies / Blockers

- Depends on: `user_preferences_service`.
- Blocks: none.
- External: legal review of OFL licences (1 day).

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| APK size bloat | Med | Low | OFL fonts ~600 KB combined; acceptable |
| CJK glyph fallback misalignment | Med | Med | Explicit `fontFamilyFallback` chain |
| OFL attribution missed | Low | Med | Settings credits dialog + LICENSE files |
| Comic Sans community petition | High | Low | Plan post-v1 release |

## 11. Cost Model

| Component | Free tier? | Estimated $ at 100k DAU |
|-----------|-----------|--------------------------|
| Compute | n/a | $0 |
| DB | n/a | $0 |
| AI | n/a | $0 |
| Storage | bundled in app | $0 |
| **Total** | | **$0** |

## 12. Done Definition

- [ ] All tasks above checked
- [ ] APK delta verified < 650 KB
- [ ] OFL licences shipped + dialog wired
- [ ] Patrol test passes on Android + iOS
- [ ] Onboarding nudge tested
- [ ] Beta feedback ≥4.4/5
- [ ] Zero P0/P1 bugs in 14-day window
