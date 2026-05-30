# Stream Analytics — UI/UX

## Screens
| # | Screen | Notes |
|---|--------|-------|
| 1 | Live overlay | Floating concurrent counter on streamer's own view |
| 2 | Post-stream summary | Auto-shown ~60s after stream ends |
| 3 | Dashboard | Historical list + drill-down |
| 4 | Drill-down | Drop-off chart, chat heatmap, donations |

## Wireframes

### Live overlay
```
┌─────────────────┐
│ 🟢 142 watching │
│ ▲ peak 168       │
└─────────────────┘
```

### Post-stream summary
```
┌─────────────────────────────────────┐
│ Stream complete — 1h 23m            │
├─────────────────────────────────────┤
│  Peak viewers       168             │
│  Unique viewers     412             │
│  Avg watch          12m 4s          │
│  Chat msgs          2,341           │
│  Donations          $47.50          │
│                                     │
│  [Drop-off curve sparkline]         │
│                                     │
│  [ Open dashboard ]                 │
└─────────────────────────────────────┘
```

### Dashboard
```
┌─────────────────────────────────────┐
│ Streams ▼ Last 30 days        ⤓ CSV │
├─────────────────────────────────────┤
│ Apr 28  GTA marathon   168 peak     │
│ Apr 25  Q&A             89 peak     │
│ Apr 20  Cozy chat       42 peak     │
│ ...                                 │
└─────────────────────────────────────┘
```

## Components
- `<LiveCounter>` ws-bound to stream-stats channel.
- `<DropOffChart>` line chart, viewer % vs time.
- `<ChatHeatmap>` minute-level intensity.

## Empty/Error/Loading
- Empty: "Stream more to see analytics."
- Stale aggregates: badge "computed N min ago".
- Low sample (n<10): hide percentiles, show count only.

## Copy
| Surface | Copy |
|---------|------|
| Live counter | "watching now" |
| CSV button | Export CSV |
| Empty | Stream more to see analytics |

## Motion
Counter changes pulse subtly (no jitter).
Reduced motion: instant updates.

## Accessibility
Charts ship with table-mode toggle; readable by screen reader.
Counter announces only on >5% change to avoid spam.

## Responsive
Phone: stacked cards. Tablet/web: 2-column grid.

## Theming
Charts use accent color; respect color-blind mode.
