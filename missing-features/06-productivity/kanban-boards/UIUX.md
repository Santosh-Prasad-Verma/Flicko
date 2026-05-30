# Kanban Boards — UI/UX Design

## 1. Design Principles

- Phone-first: horizontal swipe between columns, swipe-on-card to change status
- Tablet/web: traditional drag-drop
- Card density compact (60pt) so a column shows 6+ cards on a phone
- Keep card decoration light: title, short_id, priority dot, due chip, assignee avatar(s)

## 2. Information Architecture

- Entry points:
  1. Server side rail "Boards"
  2. Channel header "Open in board" (filters board to that channel)
  3. Deep link `flicko://board/<id>`

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | Board List | Server's boards | empty, content, loading |
| 2 | Board View | Columns + cards | loading, content, error |
| 3 | Card Quick Sheet | Move/edit | content |
| 4 | Board Editor | Columns config | content, saving, error |

## 4. Wireframes (ASCII)

### Screen 2 — Board View (Phone, columns swipeable)

```
┌────────────────────────────────────────────────┐
│ ←  Q3 Roadmap                       [Filter ⌄] │
├────────────────────────────────────────────────┤
│   To do    ▶ In progress (4/5) ▶ Blocked       │
├────────────────────────────────────────────────┤
│  In progress (4/5) WIP        ⚠ at limit       │
│  ┌──────────────────────────────────────────┐  │
│  │ #142 ⚠ Triage Android crash              │  │
│  │ @priya · due Fri · 🐛 bug                │  │
│  ├──────────────────────────────────────────┤  │
│  │ #135 Refresh icon set                    │  │
│  │ @sam · due Mon · 🎨 design               │  │
│  ├──────────────────────────────────────────┤  │
│  │ #128 Migrate cron to scheduler           │  │
│  │ @alex · due Sat · 🛠 ops                 │  │
│  ├──────────────────────────────────────────┤  │
│  │ #119 Audit RLS                           │  │
│  │ @priya · due Wed · 🔒 sec                │  │
│  └──────────────────────────────────────────┘  │
│                                                │
│  ◀  swipe a card right -> move next status     │
│  ◀  swipe a card left  -> previous status      │
│                                                │
│                                          [+]   │
└────────────────────────────────────────────────┘
```

### Tablet / web view (drag-drop)

```
┌──────────────────────────────────────────────────────────────────┐
│ ← Q3 Roadmap                       [Filter ⌄] [+ Card]           │
├────────────┬────────────┬────────────┬────────────┬─────────────┤
│ To do (12) │ In Progress│ Blocked (1)│  Done (47) │ Cancelled (3)│
│            │ (4/5) WIP  │            │            │              │
│ ┌────────┐ │ ┌────────┐ │ ┌────────┐ │ ┌────────┐ │              │
│ │ #150   │ │ │ #142 ⚠ │ │ │ #110   │ │ │ #109 ✓ │ │              │
│ │ Sprint │ │ │ Triage │ │ │ Brand  │ │ │ Login  │ │              │
│ │ review │ │ │ crash  │ │ │ assets │ │ │ refacto│ │              │
│ └────────┘ │ └────────┘ │ └────────┘ │ └────────┘ │              │
│ ┌────────┐ │ ┌────────┐ │            │            │              │
│ │ #149   │ │ │ #135   │ │            │            │              │
│ │ Write  │ │ │ Icons  │ │            │            │              │
│ └────────┘ │ └────────┘ │            │            │              │
└────────────┴────────────┴────────────┴────────────┴─────────────┘
```

### Card Quick Sheet (phone, after swipe)

```
┌────────────────────────────────────────────────┐
│ Move #142  Triage Android crash         ✕      │
├────────────────────────────────────────────────┤
│ From: In progress                              │
│ To:                                            │
│  ◯ To do                                       │
│  ●  Blocked                                    │
│  ◯ Done                                        │
│  ◯ Cancelled                                   │
│                                                │
│ Note (optional)                                │
│ [ Why is it blocked? ]                         │
├────────────────────────────────────────────────┤
│                              [Cancel]  [Move]  │
└────────────────────────────────────────────────┘
```

### Board Editor

```
┌────────────────────────────────────────────────┐
│ ✕ Edit board                            Save   │
├────────────────────────────────────────────────┤
│ Name [ Q3 Roadmap                       ]      │
│ Cover [ ●●●●● color picker ]                  │
│                                                │
│ Columns                                        │
│  ≡  To do          maps -> todo        WIP [-] │
│  ≡  In progress    maps -> in_progress WIP [5] │
│  ≡  Blocked        maps -> blocked     WIP [3] │
│  ≡  Done           maps -> done        WIP [-] │
│  ≡  Cancelled      maps -> cancelled   WIP [-] │
│  [ + Add column ]                              │
│                                                │
│ [ Archive board ]                              │
└────────────────────────────────────────────────┘
```

## 5. Component Specs

### `BoardColumn`
- Props: `column`, `cards`, `wipLimit`, `onCardMove`
- States: under-limit, over-limit (amber border), collapsed
- Header sticky on scroll

### `KanbanCard`
- Compact (60pt), priority dot, title (1 line), short_id chip, due chip, assignees
- States: idle, dragging, swiping (translate), submitting (shimmer)

### `WipBanner`
- Inline at column top when over limit
- Color: warning token

## 6. Empty / Error / Loading

- Empty board: post-it illustration; "No cards yet"; CTA "+ Card"
- Empty column: ghost text "Drop cards here"
- Loading: shimmer columns
- Error: inline banner "Couldn't load board"

## 7. Copy

| Surface | Copy |
|---------|------|
| FAB | New card |
| Empty board | No cards yet |
| Empty column | Drop cards here |
| WIP banner | {column} is at {n}/{limit} |
| Move sheet | Move where? |
| Stuck nudge | "Anything blocking on #{n}?" |

Voice: action-oriented, short.

## 8. Motion

- Card move: slide+scale transition 220ms with shadow lift
- Column scroll: snap on phone
- Reduced motion: crossfade

## 9. Accessibility

- Cards announce id, title, status, due, assignees
- Move via keyboard arrows + Enter
- High-contrast mode pairs status colors with icons (•▲▶✓✕)
- Tap targets >=44pt

## 10. Responsive

- Phone: single column scroll, horizontal column nav
- Tablet: 2-3 columns visible
- Web: all columns side-by-side
- Breakpoints: 360 / 600 / 840 / 1200

## 11. Theming

- Light, Dark, AMOLED
- Cover color picker uses 12 preset hues from theme
- Honors server accent for primary CTA
