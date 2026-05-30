# Short Videos — UIUX

## Screens
| # | Screen | States |
|---|--------|--------|
| 1 | Feed (vertical) | playing / paused / loading / end |
| 2 | Recorder | idle / recording / preview / uploading |
| 3 | Detail | comments / share sheet |
| 4 | Profile gallery | grid / loading |
| 5 | Moderation queue (admin) | open / actioned |

## Wireframes

### Feed
```
┌──────────────────┐
│                  │
│                  │
│    [VIDEO 9:16]  │
│                  │
│ caption text @user│
│                  │
│            ❤ 1.2k│
│            💬 41 │
│            ↗ 12  │
│            🔖    │
│                  │
│ [server pill]    │
└──────────────────┘
   FYP | Following | Server ▾
```

### Recorder
```
┌──────────────────┐
│  [camera preview]│
│                  │
│                  │
│                  │
│                  │
│  ●●●●○○○ 0:42/60s│
│  [⏺]  [✦]  [⤓]  │
└──────────────────┘
```

### Profile gallery
```
┌──────────────────┐
│ alice  · 142 vids│
├──────────────────┤
│ [g][g][g]        │
│ [g][g][g]        │
│ [g][g][g]        │
└──────────────────┘
```

## Components
- `<ShortFeed>` PageView vertical, swipe-up loads next, prefetch 2 ahead.
- `<ShortPlayer>` autoplay-on-visible, pause off-visible.
- `<EngagementRail>` like/comment/share/save column on right.
- `<CaptionsToggle>` shows VTT.
- `<RecorderScreen>` uses `camera` + `image_picker` packages.

## Empty/Error
- Feed empty (no FYP yet): "Follow a few creators to start."
- Upload fail: "Couldn't upload. Tap to retry." Local draft kept.
- Captions still processing: subtle banner "Captions coming soon".

## Copy
| Surface | Copy |
|---------|------|
| Recorder hint | Hold to record, tap for hands-free |
| Feed empty | Follow creators to fill your feed |
| Upload progress | Uploading… you can leave this screen |

## Motion
- Vertical paginate snap, 60Hz minimum.
- Heart animation on double-tap.
- Reduced-motion: replace heart pop with static badge.

## Accessibility
- All videos have captions toggle.
- Engagement counts read individually.
- Pause button reachable via keyboard (Space).
- Auto-play disabled if `disableAnimations` true.

## Responsive
- Phone-first. Tablet shows 2 columns. Web shows feed centered with sidebar.

## Theming
- Player chrome respects accent color.
- Captions respect reduced-motion + color-blind palettes.
