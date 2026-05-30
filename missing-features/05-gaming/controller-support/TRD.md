# Controller Support — TRD

## Architecture
```
controller (HID/Bluetooth) → SDL2 / gamepads pkg → ControllerService (Riverpod)
                                                          ↓
                                                  FocusTraversalPolicy → Widgets
                                                          ↓
                                                  ActionMap → app actions
```

## Components
- Mobile/Desktop: `mobile/lib/core/controller/{service.dart, focus_policy.dart, action_map.dart, hint_overlay.dart}`
- Plug uses `gamepads` Flutter package; desktop wraps SDL2 via FFI.
- Native bridges: WearOS no, Android TV yes, Steam Deck yes.

## API (in-app, not REST)
```dart
final controllerProvider = StreamProvider<ControllerEvent>((_) async* { ... });
abstract class ControllerEvent { ButtonCode? button; ButtonState state; }
abstract class ActionInvoker { void invoke(ActionId id, [args]); }
```

Mappings:
| Action | Default | Steam Deck |
|--------|---------|------------|
| Confirm | A / Cross | A |
| Back | B / Circle | B |
| Menu | Y / Triangle | Y |
| Mic mute | LB | L1 |

## NFRs
| NFR | Target |
|-----|--------|
| Input → focus move latency | <16ms |
| Battery overhead idle | <1%/h |

## Observability
- `flicko_controller_connected_total`
- `flicko_controller_action_total{action}`

## Failure
| Failure | Mitigation |
|---------|------------|
| Controller disconnect mid-action | snap focus to last visited; toast |
| Unknown gamepad | falls back to "generic" mapping |
