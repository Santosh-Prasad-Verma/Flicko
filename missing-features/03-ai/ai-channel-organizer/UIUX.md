# AI Channel Organizer — UIUX

## Screens
| # | Screen | States |
|---|--------|--------|
| 1 | Run trigger card (server settings) | idle / running |
| 2 | Suggestions diff view | per row apply |
| 3 | Apply confirmation | with summary |
| 4 | Audit history | recent runs |

## Wireframes

### Trigger card
```
┌──────────────────────────────────┐
│ Channel organizer (AI)            │
│ Get a proposed reorg in <30s.     │
│ Last run: never                   │
│ [ Run ]                           │
└──────────────────────────────────┘
```

### Suggestions diff
```
┌──────────────────────────────────┐
│ Run #42 · 23s · 14 suggestions    │
├──────────────────────────────────┤
│ ☑ Archive #spring-2024-old        │
│   reason: 0 msgs in 60d           │
│ ☑ Rename #ann to #announcements   │
│ ☐ Merge #help and #questions      │
│ ☑ Move #bots → ▾ Bots category    │
│ ...                               │
│                                   │
│ [ Apply 8 selected ]              │
└──────────────────────────────────┘
```

## Components
- `<SuggestionRow>` shows action, reason, target.
- `<ApplyDialog>` with "this cannot be undone fast" warning.

## Empty / Error
- Empty: "No suggestions — your server already looks clean."
- Error: "AI is busy. Try again." with retry.

## Copy
| Surface | Copy |
|---------|------|
| CTA | Run organizer |
| Apply | Apply selected |
| Notice | Suggestions only — nothing changes until you apply |

## Motion
- Suggestions stream-in as they generate.
- Reduced-motion: list appears all at once.

## Accessibility
- Screen reader announces each suggestion succinctly.
- Apply button summarizes count.

## Theming
- Diff color uses semantic add/remove, color-blind safe.
