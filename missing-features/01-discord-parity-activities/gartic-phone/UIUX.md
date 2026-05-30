# Gartic Phone — UI/UX

## 1. Principles
Match Flicko dark/light theme. Reuse `mobile/lib/features/server_channels/voice/` activity launcher pattern. Keep canvas + caption inputs full-screen on phone; split-pane on tablet.

## 2. Information Architecture
- Entry: Voice channel → Activities button → "Gartic Phone" card
- Parent: Activity overlay (modal over voice tile)
- Deep link: `flicko://voice/<channel-id>/activity/gartic/<session-id>`

## 3. Screens
| # | Screen | States |
|---|--------|--------|
| 1 | Lobby | empty / waiting / configuring / launching |
| 2 | Prompt entry | typing / submitted / waiting for round |
| 3 | Drawing canvas | drawing / submitting / waiting |
| 4 | Caption screen | viewing image / typing / submitted |
| 5 | Reveal gallery | per-chain reveal / final summary |

## 4. Wireframes

### Lobby
```
┌─────────────────────────────────────┐
│ ← Gartic Phone           ⓘ Settings │
├─────────────────────────────────────┤
│  4 / 12 players                     │
│  ──────────────                     │
│  Round time: 60s    [v]             │
│  Drawing seconds: 45                │
│  Mode: Normal | Knock-off | Secret  │
│                                     │
│  ◉ alice  ◉ bob  ○ +invite          │
│                                     │
│  [ Ready ]   [ Start when 4+ ]      │
└─────────────────────────────────────┘
```

### Drawing canvas
```
┌─────────────────────────────────────┐
│ "A cat riding a unicycle"   ⏱ 0:38  │
├─────────────────────────────────────┤
│ ▓ Brush  ◯ ◯ ◉  Size: ── ──         │
│ Palette: ⬛🟥🟧🟨🟩🟦🟪⬜              │
├─────────────────────────────────────┤
│                                     │
│         [ canvas ]                  │
│                                     │
├─────────────────────────────────────┤
│  ↶ Undo   ↷ Redo   🗑 Clear   ✓ Done│
└─────────────────────────────────────┘
```

### Reveal
```
┌─────────────────────────────────────┐
│ Chain 1 of 4 — alice's prompt   ▶   │
├─────────────────────────────────────┤
│ alice: "A cat riding a unicycle"    │
│ bob: [drawing.png]                  │
│ carol: "lonely circus performer"    │
│ dan: [drawing.png]                  │
│ alice: "A man on a horse maybe?"    │
│                                     │
│ [ React 😂 ❤️ 🤣 ] [ Save GIF ]      │
└─────────────────────────────────────┘
```

## 5. Components
- `<GarticLobby>` — props: session, members, host. States: idle / starting.
- `<DrawingCanvas>` — Flutter `Signature` package; tracks PNG export at 720x720.
- `<CaptionInput>` — TextField with 200-char cap; submit on Enter.
- `<RevealCarousel>` — auto-advance every 4s; tap to pause; swipe to skip.

## 6. Empty / Error / Loading
- Empty lobby (1 player): "Invite friends to play. Min 4 players."
- Network drop while drawing: keep local canvas; show banner "Reconnecting…"; resubmit on recover.
- Timer expired with no submission: lock blank or last stroke; show "Time's up!"

## 7. Copy
| Surface | Copy |
|---------|------|
| Title | Gartic Phone |
| Lobby CTA | Start game |
| Prompt prompt | Type a sentence to draw |
| Caption prompt | What is this drawing? |
| Done CTA | Submit |
| Reveal title | Watch the chaos |

Voice: playful, second-person, no jargon.

## 8. Motion
- Lobby → first round: shared-axis Y, 350ms.
- Canvas submit: scale-out + checkmark, 200ms.
- Reveal advance: cross-fade 250ms with subtle parallax.
- Reduced-motion: replace transitions with crossfades only.

## 9. Accessibility
- Drawing canvas exposes Semantics label "Drawing area, double-tap to focus" with stroke-count live region.
- Color palette buttons announce hex on focus.
- Caption input has visible label (not placeholder-only).
- Contrast ≥4.5:1 on all UI; canvas itself excluded.
- Tab order: tools → canvas → done.

## 10. Responsive
- Phone: full-screen modal.
- Tablet: side-panel 320 dp for tools, canvas fills rest.
- Web: same as tablet, ≥1024 wide.

## 11. Theming
- Inherits server accent color for lobby chrome (post 09/accent-colors ship).
- Canvas default white in light, #181818 in dark; AMOLED variant clamps to #000.
