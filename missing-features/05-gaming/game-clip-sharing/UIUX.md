# Game Clip Sharing — UIUX

## Screens
| # | Screen | Notes |
|---|--------|-------|
| 1 | Capture HUD | Hotkey toast / tray icon |
| 2 | Trim & post | Mini editor |
| 3 | Channel clip wall | Grid + filter |
| 4 | Clip player | HLS, captions optional |

## Wireframes

### Capture toast
```
┌──────────────────────────────┐
│ 🎬 Last 60s captured          │
│ [ Trim & post ]   [ Discard ] │
└──────────────────────────────┘
```

### Trim editor
```
┌──────────────────────────────────┐
│ [video preview]                   │
│ ──● ─────────────── ●──            │
│  in:0:12       out:0:48           │
│ Caption: ____________________     │
│ Game: League of Legends   ▾       │
│ [ Cancel ]            [ Post ]    │
└──────────────────────────────────┘
```

### Clip wall
```
┌──────────────────────────────────┐
│ #clips                            │
│ ▾ All games  ▾ This week          │
├──────────────────────────────────┤
│ [▶][▶][▶]                         │
│ [▶][▶][▶]                         │
└──────────────────────────────────┘
```

## Components
- `<TrimSlider>` two-thumb range.
- `<ClipCard>` thumbnail + reactions overlay.

## Empty/Error
- Empty channel: "Be the first to share a clip."
- Failed upload: keep trim state in Hive, retry button.

## Copy
| Surface | Copy |
|---------|------|
| Capture toast | Last 60s captured |
| Post CTA | Post |

## Motion
- Capture toast slides in 200ms.
- Reduced-motion: instant.

## Accessibility
- Trim sliders have keyboard nudge ±100ms.
- Player controls fully keyboard accessible.

## Responsive
- Wall is 3-col on phone, 4 tablet, 5 desktop.

## Theming
- Player chrome respects accent color.
