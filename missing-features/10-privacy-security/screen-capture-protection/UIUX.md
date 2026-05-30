# Screen Capture Protection — UI/UX Design

## 1. Design Principles

- The badge is honest: "Screen capture protected" only when the device actually has the protection active. No fake confidence.
- Make the limitation explicit: a one-time tooltip on first encounter explaining what is and is not blocked.
- Recording-detected events are calm, not panic-inducing. We surface them clearly without shaming the recorder.

## 2. Information Architecture

Where this feature lives:
- Entry points (3): channel header badge; DM settings; mod panel "Channel security."
- Parent navigation: messaging.

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | Channel header (protected) | Badge + info | content |
| 2 | DM consent prompt | Ask other party | requested, consented, declined |
| 3 | iOS recording scrim | Black overlay during record | active |
| 4 | Recording-detected banner | "Alex started recording" | content |
| 5 | First-time tooltip | Explain limits | once |

## 4. Wireframes (ASCII)

### Channel header (protected)
```
┌────────────────────────────────────┐
│  ← #strategy   🛡 Capture-protected│
└────────────────────────────────────┘
```

### iOS recording scrim
```
┌────────────────────────────────────┐
│                                    │
│         ⬛  ⬛  ⬛                   │
│         (full black)               │
│                                    │
│   Screen recording detected.       │
│   Content hidden until you stop.   │
│                                    │
└────────────────────────────────────┘
```

### Recording-detected banner (other side)
```
┌────────────────────────────────────┐
│  ⓘ Alex is recording the screen.   │
└────────────────────────────────────┘
```

## 5. Component Specs

### `ProtectedScope`
- Widget that wraps any subtree carrying sensitive content.
- On mount: enable FLAG_SECURE (Android) or attach iOS observer.
- On unmount: detach.
- Props: `child`, `enabled`.

### `RecordingScrim`
- Full-screen black overlay shown while iOS reports recording active.
- Fades out 200ms when recording stops.

### `ProtectionBadge`
- Shield icon + text "Capture-protected." Tap opens info sheet explaining limits.

## 6. Empty / Error / Loading

- **Plugin error:** "Couldn't enable screen-capture protection. Try restarting Flicko." Block protected content until resolved.
- **Web platform:** "This channel is capture-protected. Open Flicko on mobile to view."

## 7. Copy

| Surface | Copy |
|---------|------|
| Badge | Capture-protected |
| Info sheet | Flicko stops Android screenshots and detects iOS screen recordings here. A phone camera could still photograph this screen. |
| Recording scrim | Screen recording detected. Content hidden until you stop. |
| Other-side banner | {name} is recording the screen. |
| DM consent prompt | {name} wants to enable capture protection for this DM. |

Voice: factual, calm, clear about limits.

## 8. Motion

- Badge: static.
- Scrim: 100ms fade-in, 200ms fade-out.
- Banner: slide-down 200ms.

## 9. Accessibility

- Scrim respects screen-reader users — `Semantics.label: "Screen recording detected, content hidden"`.
- Badge announces state.
- Color independent: shield icon + text.

## 10. Responsive

- Phone-only effective; web shows the limitation banner.
- Tablet: same as phone.

## 11. Theming

- Badge uses neutral muted color tokens. Not green (would suggest "fully secure").
