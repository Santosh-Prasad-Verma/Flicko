# AI Emoji Suggester — UIUX

## Screens
| # | Screen | Notes |
|---|--------|-------|
| 1 | Composer chip row | inline above text input |
| 2 | Setting toggle | Settings → Chat → Emoji suggestions |

## Wireframes

### Composer
```
┌──────────────────────────────────┐
│ that meeting was insane          │
├──────────────────────────────────┤
│ [😂] [🤯] [😅]                    │
├──────────────────────────────────┤
│ ☺  Type a message…  📎 ↗         │
└──────────────────────────────────┘
```

### Settings toggle
```
┌──────────────────────────────────┐
│ Chat                              │
├──────────────────────────────────┤
│ Emoji suggestions    [ON ▣]       │
│   Suggest emojis as you type      │
└──────────────────────────────────┘
```

## Components
- `<EmojiSuggesterRow>` 36dp tall, max 3 chips.
- Tap appends emoji; long-press inserts at cursor.

## Empty / Error
- No suggestions: row hides entirely.
- Model load fail: row never appears; no banner.

## Copy
| Surface | Copy |
|---------|------|
| Setting | Emoji suggestions |
| Setting hint | We propose emojis as you type. Stays on-device. |

## Motion
- Suggestions cross-fade in/out 120ms.
- Reduced-motion: instant.

## Accessibility
- Each chip has Semantics label "emoji [name], double-tap to insert".
- Row excluded from screen-reader by default unless suggestions present.

## Theming
- Chip background = surface, border = outline; respects accent color.
