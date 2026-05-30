# Color-Blind Mode — UI/UX

## Principles
Don't shift hues randomly. Use Daltonization filters mathematically tuned for each deficiency, plus iconography/text reinforcement so meaning isn't color-only.

## Information Architecture
- Settings → Accessibility → Color-blind mode
- Toggle: Off | Protanopia | Deuteranopia | Tritanopia | Achromatopsia
- Sub-options: Strength (50% / 100%); Apply to media (off by default).

## Screens

### Settings screen
```
┌─────────────────────────────────────┐
│ Color-Blind Mode                    │
├─────────────────────────────────────┤
│ Mode:                               │
│   ◯ Off                             │
│   ◉ Deuteranopia (green-blind)      │
│   ◯ Protanopia (red-blind)          │
│   ◯ Tritanopia (blue-blind)         │
│   ◯ Achromatopsia (full)            │
│                                     │
│ Strength       ── ── ── ●── ──  100%│
│ Apply to media  [OFF ▢ ]            │
│                                     │
│ Preview ───────────────────────────│
│ ●● ●● ●● ●●  primary states         │
│ ✓ success  ! warning  × error       │
│ Charts use patterns + labels        │
└─────────────────────────────────────┘
```

### Inline reinforcement (everywhere)
- Buttons that rely on red/green pair gain icons (✓/×) or text ("on"/"off").
- Vote arrows show numeric delta, not just up/down.

## Components
- `<DaltonizedColor color="…"/>` widget that applies CIE-LAB→deficiency matrix at render.
- `<ColorBlindPreview/>` panel.

## Empty/Error/Loading
- N/A.

## Copy
| Surface | Copy |
|---------|------|
| Header | Color-blind mode |
| Strength | How strong the correction is |
| Media toggle | Apply correction to images/video too (uses more battery) |
| Preview header | What you'll see |

## Motion
- Mode change: crossfade 250ms across entire UI.
- Reduced-motion: instant.

## Accessibility
- All toggles have semantic labels.
- Setting persists immediately; banner "Saved" announces via live region.
- Doesn't override user's high-contrast setting.

## Responsive
- Same on phone/tablet/web.

## Theming
- Combines with light/dark/AMOLED — applied AFTER theme tokens.
