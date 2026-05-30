# Disappearing Messages — UI/UX Design

## 1. Design Principles

- Reuse existing `MessageComposer` and `MessageBubble` from `features/messaging/`.
- Ephemeral state must be unmissable: clock icon on composer, animated countdown on bubble.
- Default-off: TTL is opt-in per message. We do not silently make messages disappear.
- Countdown reads as approximate time-left, not a fuse — we want trust, not anxiety.

## 2. Information Architecture

Where this feature lives:
- Entry points (3): clock icon in composer; bubble countdown chip; DM settings → "Disappearing messages."
- Parent navigation: messaging.
- Deep links: `flicko://dm/<id>/settings/disappearing`.

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | Composer with TTL pill | Compose ephemeral message | inactive, picking, set |
| 2 | TTL picker sheet | Choose TTL preset | content |
| 3 | Message bubble (ephemeral) | Show countdown | fresh, near-expiry, expired |
| 4 | DM settings → default TTL | Set per-DM default | off, set |

## 4. Wireframes (ASCII)

### Screen 1 — Composer with TTL pill

```
┌───────────────────────────────────────────┐
│  [+]  ⏱ 1h ▾  │ Type a message…          │
│                                  [send →] │
└───────────────────────────────────────────┘
```

When TTL is off, the pill is hollow `⏱ off`. When set, it is filled with the duration.

### Screen 2 — TTL picker sheet

```
┌───────────────────────────────────────────┐
│  Disappearing messages                    │
├───────────────────────────────────────────┤
│  ○  Off                                   │
│  ●  5 minutes                             │
│  ○  1 hour                                │
│  ○  1 day                                 │
│  ○  7 days                                │
├───────────────────────────────────────────┤
│  Sender and recipient see the countdown.  │
│  Server hard-deletes when time runs out.  │
│  Screenshots are not blocked.             │
└───────────────────────────────────────────┘
```

### Screen 3 — Message bubble (ephemeral)

```
   ┌─────────────────────────────────────┐
   │  code: 4827                         │
   │  ⏱ 4:32 left          14:01 ✓✓     │
   └─────────────────────────────────────┘
```

- Normal state: clock icon + remaining time, recolored at 30s left.
- Near expiry: subtle pulse 1Hz on the countdown chip.
- Expired (transient before realtime delete): bubble fades 200ms, replaced by a thin "(message expired)" line that itself fades 5s later.

## 5. Component Specs

### `TtlPickerSheet`
- Props: `current: MessageTtl`, `onChanged: (MessageTtl)`.
- States: idle, selecting.
- Token usage: `colorScheme.surface`, `textTheme.bodyMedium`.

### `EphemeralBadge`
- Props: `expiresAt: DateTime`.
- Renders clock icon + auto-updating remaining time (rebuilds every 1s while visible; throttled when off-screen).
- States: fresh (green tint), warning (<30s, amber, pulse), expiring (last 1s, red).

### `CountdownChip`
- Wraps `EphemeralBadge` for use in `MessageBubble` footer alongside read-receipt icon.

## 6. Empty / Error / Loading

- **Empty (DM settings, no default):** plain "Off" radio selected.
- **Error (send failed because TTL is invalid):** inline snackbar "Couldn't send. Try again."
- **Loading:** sending state shows sandglass icon briefly.

## 7. Copy

| Surface | Copy |
|---------|------|
| Pill (off) | Disappearing: off |
| Pill (set) | Disappearing: 1 hour |
| Sheet title | Disappearing messages |
| Sheet helper | Sender and recipient see the countdown. Server hard-deletes when time runs out. Screenshots are not blocked. |
| Expired-bubble | (message expired) |
| DM settings tile | Disappearing messages — Default for this chat |

Voice: clear, calm, factual. Avoid melodrama like "self-destruct."

## 8. Motion

- Pill state change: 150ms color tween on background fill.
- Countdown chip: tick once per second (no animation each tick — just text change). Last 30s pulse 1Hz.
- Expired-fade: 200ms opacity 1→0; replacement line fades in 200ms; both fade out together at 5s.
- Reduced-motion: disable pulse and shrink fade to instant.

## 9. Accessibility

- Pill has Semantics label "Disappearing messages, currently 1 hour. Tap to change."
- Countdown chip uses `Semantics(liveRegion: true, label: "${minutes} minutes left")` so screen readers announce updates without spam (announce only on minute boundaries).
- Color is never the only signal — chip text changes too ("4:32 left" → "30s left" → "expiring").
- Tap targets ≥44pt.

## 10. Responsive

- Phone: bottom sheet picker.
- Tablet/web: floating popover anchored to the clock icon.
- Breakpoints: 360 / 600 / 840 / 1200.

## 11. Theming

- Light + Dark + AMOLED.
- Ephemeral chip uses `colorScheme.tertiaryContainer` so it reads as "informational, distinct from normal bubble."
- Server accent colors do not override — privacy state should look the same everywhere.
