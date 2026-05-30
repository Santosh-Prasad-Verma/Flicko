# LFG System — UI/UX Design

## 1. Design Principles

- Match Flicko's existing dark/light tokens (`mobile/lib/core/theme/`).
- Reuse `mobile/lib/features/shared/presentation/widgets/` (FilterChip, PrimaryButton, AvatarGroup, EmptyState).
- Motion: Material Motion easings; respect `MediaQuery.disableAnimations`.
- Accessibility: every chip and button has a Semantics label; min 44pt tap target.
- Density: information-dense like Discord; cards collapse to two-line summary on phone.

## 2. Information Architecture

Where this feature lives:
- Entry points: gaming hub tab → "LFG" pill, server channel "Find Group" button, global search results.
- Parent navigation: Gaming Hub.
- Deep links: `flicko://lfg/server/<server_id>`, `flicko://lfg/post/<post_id>`, `flicko://lfg/hub/<game_id>`.

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | LFG Board | Browse posts in server | empty, loading, content, filtered, error |
| 2 | LFG Compose Sheet | Create a post | step 1 game, step 2 filters, step 3 confirm |
| 3 | LFG Post Detail | Inspect post + take a slot | open, full, closed, joining |
| 4 | LFG Hub (cross-server) | Browse posts by game across Flicko | content, filtered, empty |
| 5 | Server LFG Settings | Admin toggles | default, saving, saved |

## 4. Wireframes (ASCII)

### Screen 1 — LFG Board (server)

```
┌────────────────────────────────────────────┐
│ ← Looking for Group           ⋯  + Post   │
├────────────────────────────────────────────┤
│ [VALORANT] [LoL] [Apex] [+]                │
│ Filters: [Diamond+] [NA-East] [Mic ✓]      │
├────────────────────────────────────────────┤
│ ┌──────────────────────────────────────┐  │
│ │ @riku  · 2m · VALORANT comp           │  │
│ │ Need duo for ranked, sage/kj          │  │
│ │ Diamond–Immortal · NA-East · Mic ✓    │  │
│ │ ●●●○ 3/4 ─────────── [Join ▶]        │  │
│ └──────────────────────────────────────┘  │
│ ┌──────────────────────────────────────┐  │
│ │ @kai · 5m · CS2 premier               │  │
│ │ Looking for IGL, 18k+                 │  │
│ └──────────────────────────────────────┘  │
└────────────────────────────────────────────┘
```

### Screen 2 — Compose Sheet (step 2)

```
┌────────────────────────────────────────────┐
│ × New LFG post — VALORANT                  │
├────────────────────────────────────────────┤
│ Title                                      │
│ [Need duo for ranked              ]        │
│                                            │
│ Mode    [ Competitive  ▾ ]                 │
│ Rank    [ Diamond1 ─── Immortal3 ]         │
│ Region  [ NA-East ▾ ]                      │
│ Mic     [ ✓ Required ]                     │
│ Slots   [ 4 ─●──── ]                       │
│ Expires [ in 2 hours ▾ ]                   │
│ Cross-server discovery [ off ]             │
├────────────────────────────────────────────┤
│ Cancel                          [ Post ▶ ] │
└────────────────────────────────────────────┘
```

### Screen 3 — Post Detail

```
┌────────────────────────────────────────────┐
│ ← VALORANT comp                          ⋯ │
├────────────────────────────────────────────┤
│ @riku · 4m ago · expires in 1h 56m        │
│ "Need duo for ranked, sage/kj"             │
│ Diamond–Immortal · NA-East · Mic ✓         │
│                                            │
│ Slots                                      │
│ ┌─────────┬─────────┬─────────┬─────────┐ │
│ │ @riku   │ @kai    │ open    │ open    │ │
│ │  duelist│  flex   │ support │ sentinel│ │
│ └─────────┴─────────┴─────────┴─────────┘ │
│                                            │
│              [ Take support slot ▶ ]       │
└────────────────────────────────────────────┘
```

## 5. Component Specs

### `LfgPostCard`
- Props: `LfgPost post`, `VoidCallback onJoin`, `bool dense`
- States: idle / hover / pressed / disabled (full) / leaving (animating out)
- Token usage: `colorScheme.surfaceContainer`, `textTheme.titleSmall`, accent stripe = game color

### `LfgFilterChipRow`
- Persists last-used filters in shared preferences scoped to `(server_id, game_id)`.
- Multi-select for region; single-select for rank range slider.

### `LfgSlotGrid`
- Adaptive: 1×N row up to 4 slots, 2×N grid for 5–8, 4×N for 9–16.
- Empty slots show role label and "Take" affordance; filled slots show avatar + name.

## 6. Empty / Error / Loading

- **Empty (board):** illustration of headset on bench, "No groups looking yet. Be the first." with primary CTA "Post".
- **Empty (hub):** "Quiet across Flicko right now. Try posting in your server."
- **Error:** inline banner with retry; never block the whole screen.
- **Loading:** 3 skeleton cards matching final card layout, shimmer 800ms cycle.

## 7. Copy

| Surface | Copy |
|---------|------|
| Title | Looking for Group |
| Compose CTA | Post |
| Empty board | No groups looking yet. Be the first. |
| Slot full toast | Group's full. Voice channel ready. |
| Error fallback | Couldn't reach the board. Tap to retry. |
| Cross-server toggle | Show in cross-server hub |

Voice: friendly, concise, second-person. No jargon, no forced gamer slang.

## 8. Motion

- Page transitions: shared-axis Y, 300ms.
- New post slides in from top, 220ms ease-out, with subtle highlight that fades over 1s.
- Slot fill: scale-in avatar + soft confetti burst (≤300ms, skipped under reduced-motion).
- Skeleton → content: crossfade 180ms.

## 9. Accessibility

- Screen reader: announce post creation and slot fills via live region ("New group posted: VALORANT competitive, 3 of 4 filled").
- Color contrast: ≥4.5:1 for body, ≥3:1 for chip text.
- Keyboard: Tab order through filter chips → post list → join button. Enter activates join; Escape closes compose sheet.
- Reduced motion: replace slide+confetti with crossfade.
- Voice control: each chip has a unique label; "post" and "join" are reserved keywords.

## 10. Responsive

- Phone (≤600): single column cards, compose as bottom sheet.
- Foldable (600–840): two-column when unfolded.
- Tablet (840–1200): two columns, compose as side panel.
- Web/Desktop (≥1200): three columns, compose modal centered, keyboard shortcut `N` for new.

## 11. Theming

- Light, Dark, AMOLED.
- Game-specific accent color overrides server accent on cards (Valorant red, LoL gold, etc.) but stays within accessibility-safe palette.
