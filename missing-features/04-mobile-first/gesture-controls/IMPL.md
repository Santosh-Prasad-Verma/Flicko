# Gesture Controls — Implementation

## 1. Phases
| Phase | Goal | Days |
|-------|------|------|
| 0 | Spec + a11y review | 1 |
| 1 | Settings schema + screen | 1 |
| 2 | Swipe-reply | 2 |
| 3 | Double-tap react | 1 |
| 4 | Long-press menu refit | 2 |
| 5 | Undo stack + snackbar | 1 |
| 6 | 2-finger nav | 1 |
| 7 | First-run hint + tests | 1 |
| 8 | Beta + GA | 2 |

## 2. Tasks
- [ ] `supabase/migrations/146_gestures_pref.up.sql`
- [ ] `mobile/lib/features/settings/presentation/gestures_screen.dart`
- [ ] `mobile/lib/features/server_channels/chat/widgets/gesture_message_row.dart`
- [ ] `mobile/lib/features/server_channels/chat/widgets/undo_snackbar.dart`
- [ ] `mobile/lib/features/server_channels/chat/services/undo_stack.dart` (Hive)
- [ ] `mobile/lib/features/onboarding/widgets/gesture_hint.dart` (one-shot SharedPreferences)
- [ ] Provider: `gesturePrefsProvider` reading `user_settings.gestures`
- [ ] L10n keys
- [ ] Tests: widget golden for swipe affordance; integration test for undo

## 3. Files Touched
```
mobile/lib/features/settings/presentation/gestures_screen.dart                    (new)
mobile/lib/features/server_channels/chat/widgets/gesture_message_row.dart         (new)
mobile/lib/features/server_channels/chat/widgets/message_bubble.dart              (edit, wrap)
mobile/lib/features/server_channels/chat/services/undo_stack.dart                 (new)
mobile/lib/features/onboarding/widgets/gesture_hint.dart                          (new)
supabase/migrations/146_gestures_pref.up.sql                                      (new)
```

## 4. Test Plan
- Widget golden: swipe affordance reveal at 40 dp, 80 dp.
- Integration: simulate fling → reply composer opens with quoted message.
- A11y test: TalkBack on disables gestures, long-press menu still works.
- Manual: low-end Android device for haptic perf.

## 5. Rollout
- Flag `feature.gestures.enabled`. Default ON for new users; existing users opted-in via banner.
- Beta: testflight + internal channel.

## 6. Risks
| Risk | Mitigation |
|------|------------|
| Accidental delete via gesture | Always show 5 s undo snackbar |
| iOS edge-swipe collision | ignore swipes starting <16 dp from edge |
| Pin-pad confusion on very fast taps | debounce 250 ms |

## 7. Cost
$0. Pure client work.

## 8. Done
- All gestures toggleable
- A11y audit passes
- Undo coverage 100% on destructive actions
- Beta NPS ≥4
