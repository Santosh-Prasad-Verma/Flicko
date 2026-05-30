# Reduced Motion Mode — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Animation audit (catalog 40+ sites) | 2d | Design |
| 1 | Migration 257 | 0.5d | Backend |
| 2 | MotionPolicyProvider + Duration extension | 1d | Mobile |
| 3 | MotionAwarePageRoute, AnimatedSwitcher, Hero wrappers | 1.5d | Mobile |
| 4 | Retrofit 18 animation sites flagged in audit | 4d | Mobile |
| 5 | Settings + onboarding nudge | 1.5d | Mobile |
| 6 | GIF auto-pause logic | 1d | Mobile |
| 7 | Custom analyzer lint | 1d | Mobile |
| 8 | Tests: golden snapshots + Patrol | 2d | QA |
| 9 | Beta with vestibular tester cohort | 5d | All |
| 10 | GA + a11y notes | 0.5d | All |

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/257_accessibility_reduced_motion.up.sql`
- [ ] Down migration
- [ ] No new service. Reuse `user_preferences_handler.go` (validates new enum values).
- [ ] Metrics counter `flicko_accessibility_reduced_motion_set_total{mode}` in pref-write path.
- [ ] OpenAPI doc update.

## 3. Mobile Tasks

- [ ] `mobile/lib/features/accessibility/reduced_motion/application/motion_policy_provider.dart`
- [ ] `mobile/lib/features/accessibility/reduced_motion/application/motion_level.dart`
- [ ] `mobile/lib/features/accessibility/reduced_motion/data/preferences_datasource.dart`
- [ ] `mobile/lib/features/accessibility/reduced_motion/presentation/screens/reduced_motion_settings_screen.dart`
- [ ] `mobile/lib/features/accessibility/reduced_motion/presentation/widgets/motion_mode_picker.dart`
- [ ] `mobile/lib/features/accessibility/reduced_motion/presentation/widgets/motion_preview_card.dart`
- [ ] `mobile/lib/features/accessibility/reduced_motion/presentation/widgets/motion_aware_switcher.dart`
- [ ] `mobile/lib/features/accessibility/reduced_motion/presentation/widgets/motion_aware_page_route.dart`
- [ ] `mobile/lib/features/accessibility/reduced_motion/presentation/widgets/static_celebration.dart`
- [ ] `mobile/lib/features/onboarding/.../onboarding_motion_step.dart`
- [ ] Routing: add to `mobile/lib/core/router/app_router.dart` (`/settings/accessibility/reduced-motion`)
- [ ] L10n keys
- [ ] Cross-cutting retrofits:
  - `app_router.dart` — replace `PageRouteBuilder` with motion-aware route
  - `typing_indicator.dart` — switch wobble for static dots when reduced
  - `reactions_row.dart` — bounce → fade
  - `voice_join_animation.dart` — replace with static check
  - `welcome_animation.dart` — static fallback
  - `gif_attachment.dart` — pause logic
  - `snackbar.dart` — slide → fade
  - `boost_celebration.dart` — sparkle disabled
  - `mention_highlight.dart` — pulse → outline ring
  - `pull_to_refresh.dart` — spinner → text
- [ ] Custom analyzer lint `tools/lint/motion_policy.dart` (best-effort, advisory)
- [ ] Tests: golden snapshots per surface and per mode (3 modes × 6 surfaces = 18 goldens); Patrol test toggles
- [ ] Empty/error/loading states on settings screen

## 4. AI / Infra Tasks

Not applicable.

## 5. Files Touched (predicted)

```
backend/
  supabase/migrations/257_accessibility_reduced_motion.up.sql     (new)
  supabase/migrations/257_accessibility_reduced_motion.down.sql   (new)
  internal/handlers/user_preferences_handler.go                   (edit)

mobile/
  lib/features/accessibility/reduced_motion/...                   (new tree)
  lib/features/onboarding/.../onboarding_motion_step.dart         (new)
  lib/core/router/app_router.dart                                 (edit, MotionAwarePageRoute)
  lib/features/server_channels/.../typing_indicator.dart          (edit)
  lib/features/server_channels/.../reactions_row.dart             (edit)
  lib/features/server_channels/.../gif_attachment.dart            (edit)
  lib/features/server_channels/.../mention_highlight.dart         (edit)
  lib/features/voice/.../voice_join_animation.dart                (edit)
  lib/features/onboarding/.../welcome_animation.dart              (edit)
  lib/features/server/.../boost_celebration.dart                  (edit)
  lib/features/shared/presentation/widgets/snackbar.dart          (edit)
  lib/features/shared/presentation/widgets/pull_to_refresh.dart   (edit)
  lib/l10n/app_en.arb                                             (edit)

tools/
  lint/motion_policy.dart                                         (new)
```

## 6. Test Plan

- **Unit:** Duration extension yields correct adapted duration for each level.
- **Widget golden:** 18 goldens covering full/reduced/instant for the audited surfaces.
- **Integration:** Patrol — toggle modes mid-session, assert specific transitions are/are not animated.
- **Manual:** vestibular consultant pass.
- **CI:** lint rule blocks `AnimationController(...)` usages outside MotionAware contexts.

## 7. Rollout & Feature Flags

- Flag: `feature.reduced_motion_mode.enabled` (default ON).
- Sub-flag: `feature.reduced_motion_mode.gif_autopause.enabled` (default ON when reduced is on).
- Beta: 5% canary including vestibular cohort.
- Canary: 5% → 25% → 100% over 5 days.
- Kill switch: turning the flag off forces full motion regardless of pref.

## 8. Rollback Plan

1. Disable flag.
2. UI returns to full motion; preference preserved.
3. Migration is safe to leave in place.

## 9. Dependencies / Blockers

- Depends on: `theme_provider`, `lottie` package.
- Blocks: WCAG SC 2.3.3 / 2.2.2 conformance.
- External: vestibular tester recruitment (1 week lead).

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Missed animation in retrofit | Med | Med | Lint rule + design QA pass |
| Crossfade still too much for some users | Med | Med | "instant" mode option |
| Lottie pause oddness | Low | Low | Render frame 0 |
| GIF auto-pause backlash | Low | Low | Per-user opt-out; one-shot tap to play |

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
- [ ] 18 golden snapshots green across all three modes
- [ ] Patrol journey passes on Android + iOS
- [ ] Lint rule live in CI
- [ ] Vestibular consultant sign-off
- [ ] Beta feedback ≥4.5/5
- [ ] Zero P0/P1 motion-related bugs in 14-day window
