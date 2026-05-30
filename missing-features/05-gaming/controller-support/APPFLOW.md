# Controller Support — APPFLOW

```mermaid
sequenceDiagram
    participant C as Controller
    participant S as ControllerService
    participant F as FocusEngine
    participant W as Widget
    participant API as Backend

    C->>S: button press (A)
    S->>F: invoke action 'confirm'
    F->>W: trigger primary action
    W->>API: any associated request

    Note over C,S: D-pad navigation
    C->>S: D-pad right
    S->>F: nextFocus(direction: right)
    F->>F: pick nearest focusable
    F->>W: highlight + scroll into view

    Note over C,S: disconnect
    C->>S: BT disconnect
    S->>S: emit disconnected
    S->>W: snap focus to safe spot; toast
```

## State Machine
```
[disconnected] -> [connecting] -> [connected]
[connected] -> [low_battery] (warning toast)
[connected] -> [text_input_active] (virtual keyboard up)
```

## Edge Cases
- Multiple controllers: last-active wins.
- Battery <10%: warning + reduce vibration.
- Sleep/wake desktop: re-enumerate on wake.
- Conflict with screen reader: controller off when TalkBack on.
- Steam Big Picture overlay: don't intercept system buttons.

## Background
- Periodic battery poll every 30s; toast on threshold.
- Auto-save preference changes after 1s debounce.

## Notifications
- "Controller battery low" in-app toast only; no push.
