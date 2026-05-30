# AI Server Insights — UIUX

## Screens
| # | Screen | Notes |
|---|--------|-------|
| 1 | Report message embed | TL;DR + sections |
| 2 | Full report screen | Charts + prose |
| 3 | Suggestions list | Apply / dismiss |
| 4 | History | Past reports |

## Wireframes

### Embed
```
┌──────────────────────────────────┐
│ 📊 Weekly Insights · Apr 22-28    │
├──────────────────────────────────┤
│ TL;DR                             │
│ • Active members ▲ 18% to 412     │
│ • #pricing-thread saw 2.3× msgs   │
│ • #spring-2024-old has been quiet │
│   for 60d (consider archiving)    │
│                                   │
│ Top contributors                  │
│  alice 1,242 · bob 803 · carol 412│
│                                   │
│ [ Open full report ]              │
└──────────────────────────────────┘
```

### Suggestions
```
┌──────────────────────────────────┐
│ Suggestions (3)                   │
├──────────────────────────────────┤
│ Archive #spring-2024-old          │
│  reason: 0 msgs in 60d            │
│  [Apply] [Dismiss]                │
│ ─────────────                     │
│ Add channel topic to #help        │
│  reason: new joiners often ask    │
│  [Apply] [Dismiss]                │
└──────────────────────────────────┘
```

## Components
- `<InsightsEmbedCard>` always cites real numbers.
- `<SuggestionRow>` reuses organizer's component.

## Empty/Error
- Server too small: "Come back when you have 50+ active members."
- LLM fail: render facts-only template fallback.

## Copy
| Surface | Copy |
|---------|------|
| Title | Weekly Insights |
| TL;DR | TL;DR |
| Apply | Apply |

## Motion
- Embed shimmer while LLM completes.
- Reduced-motion: spinner.

## Accessibility
- Numbers always read with units.
- Suggestion rows fully keyboard accessible.

## Theming
- Charts respect color-blind palettes.
