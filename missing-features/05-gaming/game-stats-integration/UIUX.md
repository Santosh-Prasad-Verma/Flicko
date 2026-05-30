# Game Stats Integration — UIUX

## Screens
| # | Screen | Notes |
|---|--------|-------|
| 1 | Linked accounts | List + add |
| 2 | OAuth web view | Per provider |
| 3 | Profile stats card | Per game |
| 4 | Rank-role rules (admin) | Threshold rules |

## Wireframes

### Linked accounts
```
┌──────────────────────────────────┐
│ Linked accounts                   │
├──────────────────────────────────┤
│ Riot   alice#NA1     ✓  ⋯         │
│ Steam  alice         ✓  ⋯         │
│ Xbox   not linked    + Connect    │
│ PSN    not linked    + Connect    │
│ BNet   not linked    + Connect    │
└──────────────────────────────────┘
```

### Profile stats card
```
┌──────────────────────────────────┐
│ Valorant — alice#NA1              │
│ Rank   Diamond III                │
│ K/D    1.42  ▲                    │
│ Last 7 days  46 wins / 28 losses  │
│  ────  Show more ────             │
└──────────────────────────────────┘
```

### Rank-role rules
```
┌──────────────────────────────────┐
│ Rank → Role rules                 │
├──────────────────────────────────┤
│ Valorant ≥ Diamond → @valorant-d  │
│ LoL      ≥ Plat    → @lol-plat    │
│ + Add rule                        │
└──────────────────────────────────┘
```

## Components
- `<LinkAccountButton>` provider-aware.
- `<StatsCard>` shimmer until snapshot loads.

## Empty/Error
- "Link an account to show stats."
- "Stats unavailable, retry in N min" on rate-limit.

## Copy
| Surface | Copy |
|---------|------|
| Card title | <Game> stats |
| Connect CTA | Connect |
| Disconnect | Disconnect |

## Motion
- Card slide-in 200ms; reduced-motion replaces with crossfade.

## Accessibility
- Stats values labeled (e.g. "K/D ratio one point four two").
- OAuth view returns focus to settings page after success.

## Responsive
- Card spans full width on phone; 2-up on tablet.

## Theming
- Tier colors respect color-blind palette overrides.
