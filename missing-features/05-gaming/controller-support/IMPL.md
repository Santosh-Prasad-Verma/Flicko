# Controller Support — IMPL

## Phases
| # | Goal | Days |
|---|------|------|
| 0 | Spec | 2 |
| 1 | gamepads + SDL2 FFI | 3 |
| 2 | Custom FocusTraversalPolicy | 4 |
| 3 | Action map + hint overlay | 3 |
| 4 | Virtual keyboard | 4 |
| 5 | Steam Deck preset + tuning | 2 |
| 6 | Settings screen + sync | 2 |
| 7 | QA on Xbox/PS/Deck/Android TV | 5 |
| 8 | Beta + GA | 3 |

## Tasks
- [ ] `mobile/lib/core/controller/service.dart`
- [ ] `mobile/lib/core/controller/focus_policy.dart` (overrides Flutter default)
- [ ] `mobile/lib/core/controller/action_map.dart`
- [ ] `mobile/lib/core/controller/hint_overlay.dart`
- [ ] `mobile/lib/core/controller/virtual_keyboard.dart`
- [ ] `mobile/lib/features/settings/presentation/controller_screen.dart`
- [ ] `desktop/src-tauri/src/sdl2.rs` for Tauri FFI bridge
- [ ] `supabase/migrations/156_controller_profiles.up.sql`
- [ ] Riverpod providers, L10n keys, golden tests

## Files
```
mobile/lib/core/controller/...                    (new)
mobile/lib/features/settings/presentation/controller_screen.dart (new)
desktop/src-tauri/src/sdl2.rs                     (new, only if desktop)
supabase/migrations/156_controller_profiles.up.sql (new)
```

## Test
- Manual matrix: Xbox X|S, PS5, 8BitDo Pro, Steam Deck, generic.
- Auto: focus traversal walks every screen via D-pad.
- A11y: TalkBack ON disables controller mode.

## Rollout
- Flag `feature.controller.enabled`. Auto-detect on connect.
- Beta: gaming-tagged servers.

## Risks
| Risk | Mitigation |
|------|------------|
| Focus traversal misses widgets | exhaustive widget audit + golden tests |
| Battery drain via polling | 30s poll, not continuous |
| Layout shifts swallow focus | restore last focus on rebuild |

## Cost
$0. No new infra.
