# Gesture Controls - TRD

## 1. Architecture Overview

```
┌──────────────────────────────────────────────────────────────────┐
│                       Flicko (Flutter)                           │
│                                                                  │
│  ┌─────────────────────────────────────────────────────────┐    │
│  │ GestureRouter (RawGestureDetector tree)                 │    │
│  │   ├── HorizontalDragRecognizer (swipe-reply / dismiss)  │    │
│  │   ├── LongPressRecognizer       (contextual menu)       │    │
│  │   ├── DoubleTapRecognizer       (react)                 │    │
│  │   └── ThreeFingerSwipeRecognizer (undo)                 │    │
│  └────────────────────────┬─────────────────────────────────┘    │
│                           │                                      │
│                           ▼                                      │
│  ┌──────────────────────────────────────────────────────────┐   │
│  │ GesturePolicy                                            │   │
│  │  Reads GesturePrefs, checks accessibility toggles,       │   │
│  │  resolves conflicts, dispatches to feature-specific      │   │
│  │  command handlers.                                       │   │
│  └────────────────────────┬─────────────────────────────────┘   │
│         ┌─────────────────┼─────────────────┬─────────────┐     │
│         ▼                 ▼                 ▼             ▼     │
│  ┌────────────┐    ┌────────────┐    ┌──────────┐  ┌──────────┐│
│  │ ReplyCmd   │    │ ReactCmd   │    │ MenuCmd  │  │ UndoCmd  ││
│  └────────────┘    └────────────┘    └──────────┘  └──────────┘│
│                                                                  │
└──────────────────────────────────────────────────────────────────┘
```

`GestureRouter` lives once at the chat root and delegates per-message gestures via Flutter's hit-testing. We use `RawGestureDetector` so we can register custom recognizers without losing platform conventions.

## 2. Components

### 2.1 GestureRouter
- Wraps each `MessageBubble` with a `RawGestureDetector`.
- Registers HorizontalDrag (with own resolution), LongPress, DoubleTap, and a custom ThreeFingerSwipe recognizer.

### 2.2 ThreeFingerSwipeDownRecognizer
- Custom `OneSequenceGestureRecognizer` subclass.
- Tracks `pointers.length == 3` and `dy > 80`. Fires once.
- Only registers at the chat root (not per-bubble) to keep cost low.

### 2.3 GesturePolicy
- Reads `GesturePrefs` from Hive.
- Checks platform accessibility flags (`MediaQuery.of(context).accessibleNavigation`).
- Maps recognizer events -> commands.

### 2.4 Commands
- `ReplyCmd` opens the composer focused with the parent message attached.
- `ReactCmd` calls existing `POST /api/v1/messages/:id/reactions` with starred emoji.
- `MenuCmd` opens the adaptive long-press sheet.
- `UndoCmd` issues `DELETE /api/v1/messages/:id?undo=true` if message is < 10 s old; client also rolls back optimistic state.

## 3. REST/WS Surface

### 3.1 Existing Endpoints (Reused)
- `POST /api/v1/messages/:id/reactions` for double-tap react.
- `DELETE /api/v1/messages/:id?undo=true` for three-finger undo.
- Reply uses the existing message create with `reply_to` field.

### 3.2 New Surface
- `GET /api/v1/preferences/gestures` and `PUT` for cross-device sync (deferred to v2; v1 is local-only via Hive).

## 4. Gesture Vocabulary

| Gesture                          | Default Action     | Customizable | A11y Equivalent              |
|----------------------------------|---------------------|--------------|------------------------------|
| Swipe-right on bubble (LTR)      | Reply              | Yes (reply / react / pin / forward) | Long-press -> Reply       |
| Swipe-left on bubble             | Mark thread read   | Yes          | Settings -> Mark read button  |
| Long-press on bubble             | Open context menu  | Items reorderable | Tap on overflow icon         |
| Double-tap on bubble             | React with starred | Emoji configurable | Long-press -> React        |
| Three-finger swipe-down (chat)   | Undo last send     | Toggle on/off | Toast -> Undo button         |
| Pull-to-refresh                  | Reload chat        | -            | Refresh button in app bar    |

## 5. Conflict Resolution

Flutter's gesture arena handles conflicts. We hint the arena via:
- `HorizontalDragGestureRecognizer` accepts only after 12 px of horizontal drag dominates vertical (`dx.abs() > dy.abs() * 1.5`).
- `LongPressGestureRecognizer` uses default 500 ms.
- `DoubleTapGestureRecognizer` uses default 300 ms.
- `ThreeFingerSwipeDownRecognizer` claims only when 3 pointers active for >= 60 ms.

Inside galleries (image carousels), the gallery's own `PageView` wins horizontal pans; bubble swipe-reply only triggers on the message envelope, not on media itself.

## 6. NFRs

| Property                                         | Target                                    |
|--------------------------------------------------|-------------------------------------------|
| Gesture recognition latency                      | < 16 ms (one frame)                        |
| Swipe-reply animation                            | 200 ms cubic ease, 60 fps                 |
| False-positive rate (e.g., scroll triggers reply)| < 0.5%                                     |
| False-negative rate (intended swipe missed)      | < 2%                                       |
| Battery overhead                                 | negligible (no continuous timers)          |
| Reduce-Motion compliance                         | replace slide with crossfade < 120 ms      |

## 7. Observability

Telemetry events:
- `gesture.swipe_reply` { source: bubble|notif, succeeded }
- `gesture.long_press` { menu_path }
- `gesture.double_tap_react` { emoji }
- `gesture.undo_send` { latency_to_undo_ms }
- `gesture.disabled` { gesture_id }
- `gesture.config_changed` { key, value }

Counters in dev: false-positive rate via heuristic ("user swiped, then reverted within 1 s").

## 8. Accessibility

- All gestures expose semantic actions: `Semantics(onTap..., onLongPress..., customSemanticsActions:{...})`.
- VoiceOver / TalkBack rotor includes "Reply", "React", "Open menu" actions on each message.
- Switch Control: each message announces its actions in order; gestures themselves bypass Switch Control naturally.
- Reduce Motion: animations replaced with 120 ms opacity crossfade.
- Larger Touch Targets (iOS): expands hit area 8 dp around bubble for swipe gestures.

## 9. Failure Modes

| Failure                                | Behavior                                              |
|----------------------------------------|-------------------------------------------------------|
| Network down on react                  | Optimistic UI; queue retry                            |
| Network down on undo                   | Local rollback succeeds; backend syncs on reconnect; if peer already received, surface "couldn't undo for everyone" |
| Gesture pref corrupt                   | Reset to defaults                                     |
| Recognizer arena loses (system gesture wins) | No-op; user retries                              |
| Rapid double-fire of double-tap        | Idempotent: server dedupes by client id within 5 s    |

## 10. Migration

`146_create_gesture_preferences.up.sql` adds an optional preferences table for cross-device sync (v2). v1 reads/writes only locally; the migration ships now to avoid a second migration churn.

## 11. Test Hooks

A debug overlay (`GESTURE_DEBUG=true`) draws hit-test outlines and shows recognizer state per pointer. Used for QA and flutter-driver tests.
