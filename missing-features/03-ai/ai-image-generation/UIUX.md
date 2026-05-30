# AI Image Generation — UIUX

## Screens
| # | Screen | Notes |
|---|--------|-------|
| 1 | Slash command UI | `/imagine` with prompt + style picker |
| 2 | Generated image embed | with re-roll/variations |
| 3 | Quota notice | "X of Y left today" |
| 4 | Settings (per-server) | enable, daily cap, allowed channels |

## Wireframes

### Slash command popover
```
┌──────────────────────────────────┐
│ /imagine cat astronaut            │
│  Style    ◯ photo ● anime ◯ paint │
│  Aspect   1:1  16:9  9:16  4:5    │
│                                   │
│  3 of 5 free generations left     │
│                                   │
│  [Generate]                       │
└──────────────────────────────────┘
```

### Image embed in chat
```
┌──────────────────────────────────┐
│  alice                            │
│  /imagine cat astronaut · anime   │
│ ┌──────────────────────────────┐  │
│ │      [generated image]       │  │
│ └──────────────────────────────┘  │
│  ↻ Re-roll    🪄 Variations    ⤓  │
└──────────────────────────────────┘
```

## Components
- `<ImagineSheet>` slash-command popover.
- `<ImageEmbedCard>` extends existing message embed.

## Empty/Error
- Quota hit: "Daily limit reached. Upgrade to Plus for 50/day or come back tomorrow."
- Block: "We can't generate that. Try a different prompt."
- Provider down: "Image generation is taking longer than usual…"

## Copy
| Surface | Copy |
|---------|------|
| Header | Imagine |
| Generate | Generate |
| Re-roll | Re-roll |
| Block | We can't generate that |

## Motion
- Generate: button shows progress fill 0→100.
- Reduced-motion: spinner only.

## Accessibility
- Generated image must have alt-text (the prompt itself + "AI image").
- Re-roll button labeled with state.

## Theming
- Embed respects accent color border.
