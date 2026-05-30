# Esports Integration — UIUX

## Screens
| # | Screen | Notes |
|---|--------|-------|
| 1 | Match card embed | Live / upcoming / finished states |
| 2 | Subscription manager | Per-channel |
| 3 | Schedule digest message | Weekly auto-post |

## Wireframes

### Live match card
```
┌─────────────────────────────────────┐
│ 🔴 LIVE · LCK Spring · Best of 5    │
│                                     │
│ T1   2 — 1   GenG                   │
│                                     │
│ 🎥 Watch on Twitch ▷                │
│ Updated 4s ago                      │
└─────────────────────────────────────┘
```

### Schedule
```
┌─────────────────────────────────────┐
│ Upcoming: League of Legends         │
├─────────────────────────────────────┤
│ Tomorrow 18:00  T1 vs DK            │
│ Sat 16:00       GenG vs DRX         │
│ Sun 19:00       BLG vs HLE          │
└─────────────────────────────────────┘
```

### Subscription manager
```
┌─────────────────────────────────────┐
│ #esports-news                       │
├─────────────────────────────────────┤
│ Subscriptions                       │
│ ☑ All Valorant matches              │
│ ☑ Team T1 (LoL)                     │
│ ☐ LCK schedule digest               │
│                                     │
│ + Add subscription                  │
└─────────────────────────────────────┘
```

## Components
- `<MatchCard>` updates via Centrifugo if live.
- `<ScheduleList>` renders weekly digest.

## Empty/Error
- "No upcoming matches this week."
- Provider down: card shows "Score paused" with last known.

## Copy
| Surface | Copy |
|---------|------|
| Live tag | LIVE |
| Card footer | Updated Ns ago |
| Add CTA | Add subscription |

## Motion
- Score change pulses briefly.
- Reduced-motion: no pulse.

## Accessibility
- Card readable as a single semantic block: "Live match, T1 vs GenG, 2 to 1, currently."

## Responsive
- Card width fluid.

## Theming
- Team logos respect color-blind safe palettes when next to score arrows.
