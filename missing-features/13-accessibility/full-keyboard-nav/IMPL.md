# Full Keyboard Navigation — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze + shortcut catalog review | 2d | PM/Design |
| 1 | Migration 256 (idempotent prefs) | 0.5d | Backend |
| 2 | Root Shortcuts/Actions wire-up + theme extension | 2d | Mobile |
| 3 | FocusRing widget + 25-widget retrofit | 4d | Mobile |
| 4 | Skip-to-content + modal focus trap utility | 1d | Mobile |
| 5 | Shortcut help overlay + settings screen | 2d | Mobile |
| 6 | Per-screen tab order audit | 3d | QA |
| 7 | Integration tests + Patrol | 2d | QA |
| 8 | Beta with motor-impaired testers | 4d | All |
| 9 | GA + docs in help center | 0.5d | All |

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/256_accessibility_keyboard.up.sql`
- [ ] Down migration `256_accessibility_keyboard.down.sql`
- [ ] No new service. Reuse `user_preferences_handler.go`.
- [ ] OpenAPI doc update for new keys.

## 3. Mobile Tasks

- [ ] Feature folder `mobile/lib/features/accessibility/keyboard/`
- [ ] `application/shortcut_provider.dart`
- [ ] `application/keyboard_pref_provider.dart`
- [ ] `domain/shortcut_catalog.dart` (40+ entries)
- [ ] `presentation/intents/` — 12+ Intent classes
- [ ] `presentation/widgets/focus_ring.dart`
- [ ] `presentation/widgets/skip_to_content.dart`
- [ ] `presentation/widgets/shortcut_help_overlay.dart`
- [ ] `presentation/widgets/shortcut_chip.dart`
- [ ] `presentation/screens/keyboard_settings_screen.dart`
- [ ] `mobile/lib/core/theme/focus_ring_theme.dart` (`ThemeExtension`)
- [ ] `mobile/lib/core/theme/app_theme.dart` — register the extension
- [ ] `mobile/lib/main.dart` (or root scaffold) — wrap with `Shortcuts(GlobalShortcuts.map)` and `Actions(GlobalActions.map)`
- [ ] Routing: add to `mobile/lib/core/router/app_router.dart` (`/settings/accessibility/keyboard`)
- [ ] L10n keys for shortcut catalog labels
- [ ] Cross-cutting: 25-widget retrofit (mirrors `screen-reader-full`):
  - Wrap interactive widgets in `Focus(focusNode, child: FocusRing(child: ...))`
  - Replace `InkWell` with `InkResponse(canRequestFocus: true)`
  - Add `RawKeyboardListener` shims where needed (legacy widgets)
- [ ] Tests: golden focus-ring tests; Patrol traversal across each top screen; help overlay open + Esc close
- [ ] Empty/error/loading on help overlay search

## 4. AI / Infra Tasks

Not applicable.

## 5. Files Touched (predicted)

```
backend/
  supabase/migrations/256_accessibility_keyboard.up.sql       (new)
  supabase/migrations/256_accessibility_keyboard.down.sql     (new)
  internal/handlers/user_preferences_handler.go               (edit)

mobile/
  lib/main.dart                                               (edit)
  lib/core/theme/focus_ring_theme.dart                        (new)
  lib/core/theme/app_theme.dart                               (edit)
  lib/features/accessibility/keyboard/...                     (new tree)
  lib/core/router/app_router.dart                             (edit)
  lib/l10n/app_en.arb                                         (edit)
  lib/features/server_channels/.../message_input.dart         (edit, send shortcut)
  lib/features/server_channels/.../message_bubble.dart        (edit, R/E/T shortcuts)
  lib/features/voice/.../voice_controls_bar.dart              (edit, mute/deafen)
  lib/features/server/.../server_list_tile.dart               (edit, focus + arrow nav)
  lib/features/server_channels/.../channel_list_item.dart     (edit, focus)
  lib/features/server_channels/.../typing_indicator.dart      (edit)
  lib/features/server_channels/.../reactions_row.dart         (edit, arrow key cycle)
  lib/features/server_channels/.../message_attachment.dart    (edit)
  lib/features/server_channels/.../mention_chip.dart          (edit)
  lib/features/notifications/.../notification_tile.dart       (edit)
  lib/features/direct_messages/.../dm_thread_tile.dart        (edit)
  lib/features/calling/.../incoming_call_sheet.dart           (edit)
  lib/features/profile/.../profile_action_button.dart         (edit)
  lib/features/settings/.../settings_tile.dart                (edit)
  lib/features/auth/.../oauth_button.dart                     (edit)
  lib/features/onboarding/.../onboarding_step.dart            (edit)
  lib/features/search/.../search_result_item.dart             (edit)
  lib/features/store/.../store_card.dart                      (edit)
  lib/features/gaming/.../game_card.dart                      (edit)
  lib/features/ai_assistant/.../aura_message_bubble.dart      (edit)
  lib/features/shared/presentation/widgets/snackbar.dart      (edit)
  lib/features/shared/presentation/widgets/bottom_sheet.dart  (edit, focus trap)
```

## 6. Test Plan

- **Unit:**
  - Shortcut catalog round-trip (intent → key set → l10n).
  - Focus traversal policy unit tests: given a tree, the order is deterministic.
- **Widget golden:**
  - Focus ring rendering across themes (light, dark, HC light, HC dark).
  - Help overlay layout phone + tablet.
- **Integration (Patrol):**
  - `keyboard_only_journey.dart` — Tab through home → server → channel → send message; assert each transition.
  - Focus trap test: open modal, Tab through, Esc, verify return focus.
- **Manual:** every shortcut invoked once on Android (with external kbd), iOS (Magic Keyboard), macOS, Windows, Linux web.
- **CI:** AccessibilityScanner / axe finds zero keyboard traps on top 25 screens.
- **Security:** no new endpoints; preference write scoped to `auth.uid()`.

## 7. Rollout & Feature Flags

- Flag: `feature.full_keyboard_nav.enabled` (default ON).
- Sub-flag: `feature.full_keyboard_nav.help_overlay.enabled` to disable `?` overlay if it conflicts with anything unexpected.
- Beta: 5% canary including motor-impaired testers (recruit via WebAIM forums).
- Canary: 5% → 25% → 100% over 5 days.
- Kill switch: turning the flag off reverts to default Material focus + no help overlay.

## 8. Rollback Plan

1. Disable flag.
2. Focus rings revert to Material defaults; shortcuts revert to baseline (Send via Enter, etc.).
3. Migration is preference-only and harmless to leave in place.

## 9. Dependencies / Blockers

- Depends on: existing `quick_switcher` (already shipped).
- Blocks: WCAG 2.1 SC 2.1.1 / 2.1.2 conformance claim.
- External: motor-impaired tester recruitment (1 week lead).

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Shortcut conflicts with browser | High | Med | Allowlist; document clearly |
| Focus traversal regressions on long lists | Med | Med | Use `FocusTraversalGroup` per row |
| Performance hit from extra Focus widgets | Low | Low | Profile p95; reuse FocusNodes |
| RTL bugs | Med | Low | Localization tests with `Locale('ar')` |
| Single-letter shortcut firing while typing | High | High | Strict context check; CI test |

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
- [ ] All 25 retrofitted widgets pass focus-ring golden tests
- [ ] Patrol journey passes on web + Android + iOS
- [ ] Zero keyboard traps in CI accessibility scan
- [ ] Help overlay tested against NVDA, VoiceOver, Orca
- [ ] Beta feedback ≥4.5/5 from motor-impaired testers
- [ ] Zero P0/P1 bugs in 14-day window post-GA
