# Color Blind Mode — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec + matrix audit (validate Brettel/Vienot models against Sim Daltonism) | 2d | Design |
| 1 | Migration 259 | 0.5d | Backend |
| 2 | Provider + matrices + token override | 1.5d | Mobile |
| 3 | App-root ColorFiltered wiring + per-platform tuning | 1d | Mobile |
| 4 | Settings page + preview | 1.5d | Mobile |
| 5 | Status icon shape supplement | 1d | Mobile |
| 6 | Admin role-colour checker | 1.5d | Mobile |
| 7 | Tests: golden + Patrol + matrix verification | 2d | QA |
| 8 | Beta with self-id'd CVD users | 5d | All |
| 9 | GA + a11y notes | 0.5d | All |

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/259_accessibility_color_blind.up.sql`
- [ ] Down migration
- [ ] No new service. Reuse `user_preferences_handler.go`.
- [ ] Validation in handler: clamp preset enum.
- [ ] OpenAPI doc update.

## 3. Mobile Tasks

- [ ] `mobile/lib/features/accessibility/color_blind/application/color_blind_provider.dart`
- [ ] `mobile/lib/features/accessibility/color_blind/application/cvd_matrix.dart`
- [ ] `mobile/lib/features/accessibility/color_blind/application/cvd_token_override.dart`
- [ ] `mobile/lib/features/accessibility/color_blind/data/preferences_datasource.dart`
- [ ] `mobile/lib/features/accessibility/color_blind/presentation/screens/color_blind_settings_screen.dart`
- [ ] `mobile/lib/features/accessibility/color_blind/presentation/widgets/preset_picker.dart`
- [ ] `mobile/lib/features/accessibility/color_blind/presentation/widgets/cvd_preview_card.dart`
- [ ] `mobile/lib/features/accessibility/color_blind/presentation/widgets/admin_role_color_checker.dart`
- [ ] `mobile/lib/main.dart` — wrap router in `ColorFilteredAppRoot`
- [ ] `mobile/lib/core/theme/app_theme.dart` — token override hook
- [ ] Cross-cutting:
  - `mobile/lib/features/server/.../status_indicator.dart` — shape supplement
  - `mobile/lib/features/server_channels/.../mention_chip.dart` — palette swap
  - `mobile/lib/features/voice/.../speaker_ring.dart` — palette swap
  - `mobile/lib/features/server_settings/.../role_color_picker.dart` — CVD warning
  - `mobile/lib/features/server/.../boost_celebration.dart` — flat amber under CVD
- [ ] Routing: add to `mobile/lib/core/router/app_router.dart` (`/settings/accessibility/color-blind`)
- [ ] L10n keys
- [ ] Tests: golden snapshots per preset (4 presets × 5 surfaces = 20 goldens); matrix verification unit; Patrol switch; CVD checker unit (pairs ΔE)
- [ ] Empty/error/loading on settings screen

## 4. AI / Infra Tasks

Not applicable.

## 5. Files Touched (predicted)

```
backend/
  supabase/migrations/259_accessibility_color_blind.up.sql       (new)
  supabase/migrations/259_accessibility_color_blind.down.sql     (new)
  internal/handlers/user_preferences_handler.go                  (edit, validation)

mobile/
  lib/features/accessibility/color_blind/...                     (new tree)
  lib/main.dart                                                  (edit, root filter)
  lib/core/theme/app_theme.dart                                  (edit, token override hook)
  lib/features/server/.../status_indicator.dart                  (edit, shape)
  lib/features/server_channels/.../mention_chip.dart             (edit, palette)
  lib/features/voice/.../speaker_ring.dart                       (edit, palette)
  lib/features/server_settings/.../role_color_picker.dart        (edit, warning)
  lib/features/server/.../boost_celebration.dart                 (edit, flat amber)
  lib/core/router/app_router.dart                                (edit)
  lib/l10n/app_en.arb                                            (edit)
```

## 6. Test Plan

- **Unit:**
  - Matrix functions return expected RGB output for known input pixels (validate against published Brettel reference).
  - Token override map deterministic for each preset.
  - CVD checker pair-distinguishability ΔE math.
- **Widget golden:**
  - 20 goldens covering presets × surfaces (status icons, mention chips, voice speaker ring, role colour pill, boost celebration).
- **Integration (Patrol):**
  - Toggle preset → expect filter applied + tokens swapped within 60 ms.
  - Combine with HC mode → assert both stack correctly.
- **Manual:**
  - Verify against Sim Daltonism on macOS and Coblis on web for visual sanity.
- **CI:**
  - Frame-time regression test (must stay under 2 ms p99 hit).
- **Security:** preference write scoped to `auth.uid()`.

## 7. Rollout & Feature Flags

- Flag: `feature.color_blind_mode.enabled` (default ON).
- Sub-flag: `feature.color_blind_mode.image_filter.enabled` so admins can disable image filtering server-wide if too jarring.
- Beta: 5% canary including self-identified CVD users.
- Canary: 5% → 25% → 100% over 5 days.
- Kill switch: turning the flag off forces preset=off.

## 8. Rollback Plan

1. Disable flag.
2. Filter and token overrides revert.
3. Migration safe to leave in place.

## 9. Dependencies / Blockers

- Depends on: `theme_provider`.
- Blocks: WCAG SC 1.4.1 conformance.
- External: CVD tester recruitment (1 week).

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Filter doubled with system correction | Med | Med | Detect via platform channel; warn user |
| Matrices imprecise for severe cases | Low | Low | Future severity slider |
| Admin warns false positives | Med | Low | Threshold tunable; document |
| Filter changes user photos unwantedly | Med | Med | Per-feature toggle to disable image filter |
| Performance hit on web | Low | Low | CSS-level filter; benchmark Chrome/Safari |

## 11. Cost Model

| Component | Free tier? | Estimated $ at 100k DAU |
|-----------|-----------|--------------------------|
| Compute | n/a | $0 |
| DB | n/a | $0 |
| AI | n/a | $0 |
| Storage | n/a | $0 |
| **Total** | | **$0** |

## 12. Done Definition

- [ ] All tasks above checked
- [ ] 20 golden snapshots green
- [ ] Patrol journey passes on Android + iOS + web
- [ ] Frame-time regression <2 ms p99
- [ ] Admin CVD checker validated against published examples
- [ ] Beta feedback ≥4.4/5 from CVD cohort
- [ ] Zero P0/P1 bugs in 14-day window post-GA
- [ ] WCAG SC 1.4.1 conformance documented
