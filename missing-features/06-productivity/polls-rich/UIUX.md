# Rich Polls — UI/UX Design

## 1. Design Principles

- Compose mirrors forms-surveys: question blocks reorderable
- Channel widget keeps under 7 lines for compact view
- Ranked-choice UX uses long-press-and-drag; never confusing arrows
- Anon polls show a small mask icon prominently

## 2. Information Architecture

- Entry points:
  1. Compose -> Poll
  2. Channel header overflow -> "Polls in this channel"
  3. Server side rail "Polls"
- Deep link `flicko://poll/<id>`

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | Compose | Build poll | draft, validating, posting |
| 2 | Channel Widget | Vote inline | open, voted, closed |
| 3 | Results | Post-close detail | live, final |
| 4 | Polls Index | Server-wide list | empty, content |

## 4. Wireframes (ASCII)

### Composer

```
┌────────────────────────────────────────────────┐
│ ✕  New poll                            Post    │
├────────────────────────────────────────────────┤
│ Title       [ Pick our next event           ]  │
│  ☑ Anonymous  ☑ Show results live              │
│  Closes [ Fri Jun 12, 8:00 PM ▾ ]              │
│  Min account age [ 24h ▾ ]                    │
├────────────────────────────────────────────────┤
│ Questions                                      │
│ ┌────────────────────────────────────────────┐ │
│ │ ≡ Q1 · Single choice                       │ │
│ │ Pick one *                                 │ │
│ │  • Game night                              │ │
│ │  • Movie                                   │ │
│ │  • Trivia                  [+ option]      │ │
│ ├────────────────────────────────────────────┤ │
│ │ ≡ Q2 · Ranked choice                       │ │
│ │ Rank these days                            │ │
│ │  ≡ Tue                                     │ │
│ │  ≡ Wed                                     │ │
│ │  ≡ Thu                                     │ │
│ │  ≡ Fri                     [+ option]      │ │
│ ├────────────────────────────────────────────┤ │
│ │ ≡ Q3 · Scale 1-5                           │ │
│ │ How important is timing                    │ │
│ │  1 ─ 2 ─ 3 ─ 4 ─ 5                         │ │
│ └────────────────────────────────────────────┘ │
│ [ + Add question ]                             │
└────────────────────────────────────────────────┘
```

### Channel widget (open)

```
┌────────────────────────────────────────────────┐
│ 📊 Pick our next event           🎭 anon · 1d │
│  Q1 Pick one                                   │
│   ◯ Game night    (12)                         │
│   ◯ Movie         (8)                          │
│   ◯ Trivia        (3)                          │
│  Q2 Rank these days  [ Tap to rank ]           │
│  Q3 Importance       [ 1 2 3 4 5 ]             │
│                                                │
│  47 votes · closes in 4h    [ Vote / Edit ]    │
└────────────────────────────────────────────────┘
```

### Channel widget (voted)

```
┌────────────────────────────────────────────────┐
│ 📊 Pick our next event           🎭 anon       │
│  ─ Live results ──────────────                 │
│  Q1 Pick one                                   │
│   Game night █████████████ 50%                │
│   Movie      ████████      33%                │
│   Trivia     ████          17%                │
│  Q2 Ranked (after close)                       │
│  Q3 avg 4.1                                    │
│                              [ Edit my vote ]  │
└────────────────────────────────────────────────┘
```

### Results (post-close, IRV detail)

```
┌────────────────────────────────────────────────┐
│ ←  Pick our next event · Final                 │
├────────────────────────────────────────────────┤
│ Winner: Friday  ✦                              │
│                                                │
│ IRV rounds                                     │
│ Round 1                                        │
│  Fri ████████████ 18                          │
│  Thu █████████ 14                             │
│  Tue █████ 8                                  │
│  Wed ███ 4                                    │
│  -- eliminate Wed --                           │
│ Round 2                                        │
│  Fri ████████████ 19                          │
│  Thu ██████████ 15                            │
│  Tue █████ 10                                 │
│  -- eliminate Tue --                           │
│ Round 3                                        │
│  Fri ████████████████ 26                      │
│  Thu ███████████ 18                           │
│ ✦ Winner: Friday                               │
└────────────────────────────────────────────────┘
```

## 5. Component Specs

### `PollWidgetCompact`
- Renders inline in channel feed
- Shows up to 3 questions; "View all" if more

### `RankDragList`
- Long-press-and-drag rows
- Numbers update live

### `IRVRoundChart`
- Stacked bar; arrow connecting eliminated option

## 6. Empty / Error / Loading

- Empty in composer: question type selector
- Empty list: "No polls yet"
- Closed widget: "Ended {when}. See results."
- Error: "Couldn't submit your vote. Retry."

## 7. Copy

| Surface | Copy |
|---------|------|
| Compose CTA | Post poll |
| Vote CTA | Vote |
| Edit CTA | Edit my vote |
| Closed | Ended {when}. |
| Tie | Tie between {a} and {b}. |

## 8. Motion

- Bar grow 250ms on results update
- Drag handle lift haptic
- Reduced motion: instant

## 9. Accessibility

- Rank list keyboard: alt+up/down to reorder
- Screen reader announces "Option 1 of 4: Friday, currently ranked 1"
- Color paired with shape on results chart

## 10. Responsive

- Phone: vertical question stack
- Tablet/web: results panel beside list
- Breakpoints: 360 / 600 / 840 / 1200

## 11. Theming

- Light, Dark, AMOLED
- Honors server accent for primary CTA
