# AI Music Recommendations — UIUX

## Screens
| # | Screen | Notes |
|---|--------|-------|
| 1 | Music-party queue (extension) | "Auto-queue is on" badge |
| 2 | Vibe prompt sheet | "Make it more chill" |
| 3 | Track rationale tooltip | why this song |
| 4 | Personal "you might like" digest | weekly DM |

## Wireframes

### Auto-queue badge
```
┌──────────────────────────────────┐
│ Now playing                       │
│ Daft Punk — Around the World      │
│ ────────────────                  │
│ Queue · auto-fill ON   [⚙]        │
│  1 SZA — Snooze                   │
│  2 Tame Impala — Borderline       │
│  3 [auto] Phoenix — 1901 ✦        │
│  4 [auto] MGMT — Time to Pretend ✦│
│  5 [auto] Justice — D.A.N.C.E ✦   │
│                                   │
│ [+] Add track  [✦] Vibe…          │
└──────────────────────────────────┘
```

### Vibe sheet
```
┌──────────────────────────────────┐
│ Set the vibe                      │
├──────────────────────────────────┤
│ Try: chill, hype, sad, funk       │
│ ____________________________      │
│ [ Apply ]                         │
└──────────────────────────────────┘
```

### Track rationale tooltip
```
┌────────────────────────────────┐
│ Why this song?                  │
│ Matches the room's recent tempo │
│ (118 bpm) and three of you have │
│ played this artist before.      │
└────────────────────────────────┘
```

## Components
- `<AutoQueueBadge>`, `<VibeSheet>`, `<RationaleTooltip>`.

## Empty/Error
- Spotify token missing: prompt link account.
- Provider down: "Auto-queue paused" toast.

## Copy
| Surface | Copy |
|---------|------|
| Badge | Auto-fill ON |
| Vibe placeholder | Type a mood — chill, hype, etc. |
| Empty | Connect Spotify to enable |

## Motion
- New auto-queued track slides in.
- Reduced-motion: instant.

## Accessibility
- "Auto" badge announced before track title.
- Rationale fully readable (not icon-only).

## Theming
- Sparkle icon respects accent color.
