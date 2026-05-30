# Custom Fonts (App-Wide) — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze + design review | 1d | PM/Design |
| 1 | DB migration 208 | 0.5d | Backend |
| 2 | Backend persistence service + handler | 1d | Backend |
| 3 | Curated bundle + asset wiring | 2d | Mobile |
| 4 | Provider + theme integration | 2d | Mobile |
| 5 | Settings screen + preview | 2d | Mobile |
| 6 | System-font platform channel (Android) | 2d | Mobile |
| 7 | QA + a11y audit | 2d | QA |
| 8 | GA | 1d | All |

Total: ~13d.

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/208_font_choices.up.sql`.
- [ ] Down migration.
- [ ] Model `backend/internal/models/font_choice.go`.
- [ ] Service `backend/internal/services/fonts/service.go`:
  - `Get(ctx, uid)`, `Set(ctx, uid, choice)`.
  - Validates font keys are in known list.
- [ ] Handler `backend/internal/handlers/fonts_handler.go`.
- [ ] Wire routes.
- [ ] Service tests, ≥80% cov.

## 3. Mobile Tasks

- [ ] Asset bundle in `mobile/assets/fonts/`:
  - Inter, Roboto, NotoSans, NotoSerif, OpenDyslexic, AtkinsonHyperlegible, JetBrainsMono (regular + bold; subset).
- [ ] Update `mobile/pubspec.yaml` font declarations.
- [ ] Provider `mobile/lib/features/themes/application/font_choice_provider.dart`:
  - state: body, header, mono, useSystemFont.
- [ ] Theme integration in `mobile/lib/core/theme/theme_engine.dart`:
  - Build `TextTheme` from chosen families using `GoogleFonts.getFont(family)` for any Google-hosted; bundled local for OpenDyslexic + Atkinson + Inter.
- [ ] Platform channel `core/platform/system_font_channel.dart` (Android) — query system font via Java reflection on `Typeface.DEFAULT`.
- [ ] Settings screen `mobile/lib/features/settings/presentation/font_settings_screen.dart`.
- [ ] Tests: provider state; widget golden of chat under each font.

## 4. AI / Infra Tasks

- N/A.

## 5. Files Touched (predicted)

```
backend/
  internal/services/fonts/service.go              (new)
  internal/handlers/fonts_handler.go              (new)
  internal/models/font_choice.go                  (new)
  cmd/server/main.go                              (edit)
mobile/
  assets/fonts/...                                (new bundle)
  pubspec.yaml                                    (edit)
  lib/features/themes/application/font_choice_provider.dart (new)
  lib/features/settings/presentation/font_settings_screen.dart (new)
  lib/core/platform/system_font_channel.dart      (new)
  lib/core/theme/theme_engine.dart                (edit)
supabase/
  migrations/208_font_choices.up.sql              (new)
  migrations/208_font_choices.down.sql            (new)
```

## 6. Test Plan

- Unit: provider applies font + persists.
- Widget golden: chat under each curated font.
- E2E: pick OpenDyslexic in settings, restart, persists.
- Perf: cold start delta ≤20ms.
- A11y: every preset passes 4.5:1 contrast and ≥14sp body.
- Security (v2): malformed `.ttf` upload returns 400 without crashing parser.

## 7. Rollout & Feature Flags

- Flag: `feature.custom_fonts.enabled` for v1.
- Sub-flag: `feature.custom_fonts.user_upload.enabled` for v2.
- Beta: 10% rollout 5d.
- Canary 50% → 100%.

## 8. Rollback Plan

1. Disable flag (instant).
2. App falls back to default Inter.
3. No data loss; rows remain.

## 9. Dependencies / Blockers

- Depends on: `full-theme-engine` (uses same Riverpod plumbing).
- Blocks: nothing.

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Font subsetting drops a glyph users need | M | M | ship full Latin + CJK ranges of NotoSans |
| iOS system-font misnamed | L | L | fallback to SF Pro |
| TTF parser CVE (v2) | L | M | sandboxed parse, reject expressions |
| Layout shift on swap | M | L | crossfade 80ms |

## 11. Cost Model

| Component | Free tier? | Estimated $ at 100k DAU |
|-----------|-----------|--------------------------|
| Compute | Railway free | $0 |
| DB | Supabase free | $0 |
| Storage | bundle in app | $0 |
| **Total** | | **$0** |

## 12. Done Definition

- [ ] All tasks above checked
- [ ] APK size delta ≤3MB
- [ ] Cold start regression ≤20ms
- [ ] Code merged
- [ ] Zero P0/P1 bugs in 7-day window
