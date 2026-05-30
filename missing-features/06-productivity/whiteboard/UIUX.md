# Whiteboard — UI/UX Design

## 1. Design Principles

- WebView matches app theme via CSS variables piped on load
- Voice channel side drawer slides in from right; phone uses bottom sheet expanding to fullscreen
- Tldraw default tools mapped to native bottom toolbar on phone
- Cursor labels carry name + tool ("priya - sticky")

## 2. Information Architecture

- Entry points:
  1. Voice channel side rail "Whiteboard"
  2. Channel header "+ Whiteboard"
  3. Deep link `flicko://wb/<id>`

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | List | Channel whiteboards | empty, content |
| 2 | Canvas | Editor | connecting, synced, reconnecting, read-only |
| 3 | Voice Drawer | Side panel mode | expanded, collapsed |
| 4 | Export Sheet | PNG export | rendering, ready, error |

## 4. Wireframes (ASCII)

### Canvas (full screen, phone)

```
┌──────────────────────────────────────────────┐
│ ←  Sprint Planning           ( P )( S ) ⋮   │
├──────────────────────────────────────────────┤
│                                              │
│        ┌─────┐                               │
│        │ idea│                               │
│        └──┬──┘                               │
│           │                                  │
│        ┌──▼──┐         ┌──────┐              │
│        │ goal│ ──────▶ │ task │              │
│        └─────┘         └──────┘              │
│                                              │
│        ✎ priya scribbling                    │
│                                              │
├──────────────────────────────────────────────┤
│  [⌖] [✎] [□] [○] [→] [Aa] [📌] [↶] [↷] [⛶]  │
└──────────────────────────────────────────────┘
```

### Voice channel drawer (tablet)

```
┌──────────────────────────────────────────────┐
│ Voice: Lounge        4 listeners   [WB]      │
├────────────────────────────┬─────────────────┤
│  ( P )(S)(A)(K)            │ Sprint Planning │
│  speaking: priya           │  [drawer with   │
│                            │   tldraw canvas]│
│  [Mute] [Leave] [Push]     │                 │
└────────────────────────────┴─────────────────┘
```

### Export Sheet

```
┌────────────────────────────────────┐
│ Export PNG                     ✕   │
├────────────────────────────────────┤
│ Size      [ Auto ▾ ]               │
│ Background [ ◉ light  ◯ dark  ◯ transparent ]│
│ Region    [ ●  Whole canvas        │
│            ◯ Visible only ]       │
│                                    │
│       [ Cancel ]   [ Export ]      │
└────────────────────────────────────┘
```

## 5. Component Specs

### `ToolDock`
- Native phone toolbar mirrors tldraw tools
- States: idle, active (selected tool)

### `PresenceCursors`
- Color from deterministic palette
- Label fades after 2s idle

## 6. Empty / Error / Loading

- Empty list: doodle illustration; "No whiteboards yet"
- Loading canvas: skeleton with toolbar greyed; "Connecting…"
- Read-only: lock icon

## 7. Copy

| Surface | Copy |
|---------|------|
| New CTA | New whiteboard |
| Empty state | No whiteboards yet |
| Connecting | Connecting… |
| Read-only | View only |
| Export ready toast | PNG ready. Tap to share. |

## 8. Motion

- Drawer slide 250ms
- Cursor labels fade after idle (200ms)

## 9. Accessibility

- WebView injects ARIA for canvas region
- Native toolbar buttons have Semantics labels
- Color-only differentiation paired with icons

## 10. Responsive

- Phone: full screen canvas; tools bottom dock
- Tablet/web: side drawer mode optional; toolbar at top

## 11. Theming

- Light, Dark, AMOLED via CSS vars piped
- Background paper color configurable
