# Controller Support — PRD

> **One-line:** Full Xbox/PS5/generic controller navigation of Flicko on desktop and Android TV with focus engine + on-screen hints.
> **Effort:** L
> **Priority:** P1

## 1. Problem
Gamers on couch / TV setups can't navigate Flicko without keyboard+mouse. Discord ignores this entirely. Capturing this audience is uncontested.

## 2. Users
- Desktop gamers using big-picture mode.
- Android TV users.
- Steam Deck users.

JTBDs:
1. Drive entire UI with controller.
2. Reach voice channels in <5 button presses.
3. Type with on-screen keyboard if needed.

## 3. Goals
- 100% of primary flows reachable via controller.
- ≤6 button presses to enter any voice channel.
- D-pad/stick parity with Steam Big Picture.

Non-goals: Custom control remapping per-game (v2).

## 4. Scope
- [ ] Focus engine on every screen
- [ ] Action overlay (A/B/X/Y hints)
- [ ] Virtual keyboard for text input
- [ ] Steam Deck preset
- [ ] Vibration feedback (optional)

## 5. Metrics
| Metric | Target |
|--------|--------|
| Steam Deck DAU adoption | >5% in 90d |
| Avg presses to voice | ≤6 |
| Crash on disconnect | 0 |

## 6. Risks
- Flutter focus engine quirks. Mitigation: custom `FocusTraversalPolicy`.
- Many controllers, many quirks. Mitigation: SDL2 mapping db.

## 7. Competitive
| Product | Take | Gap |
|---------|------|-----|
| Steam Big Picture | Best ref | We adopt their idiom |
| Discord | None | Greenfield |
