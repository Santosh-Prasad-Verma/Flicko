# Auto-Delete Messages — UI/UX Design

## 1. Design Principles

- The badge in the channel header reads as ambient context, not a warning. "This channel auto-deletes after 24h" should land like a friendly notice.
- Mod settings sheet is straightforward: pick a duration, decide what's exempt, save.
- Members get a one-time tooltip the first time they enter a channel with auto-delete on.

## 2. Information Architecture

Where this feature lives:
- Entry points (3): channel header badge; channel settings (mod-only); composer hint.
- Parent navigation: channel.

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | Channel header (with badge) | Show TTL state | content |
| 2 | Mod settings sheet | Configure TTL | content |
| 3 | First-time tooltip | Inform members | once |
| 4 | Composer hint | Reminder while typing | content |

## 4. Wireframes (ASCII)

### Channel header
```
┌────────────────────────────────────┐
│  ← #general    🕒 deletes after 7d │
└────────────────────────────────────┘
```

### Mod settings sheet
```
┌────────────────────────────────────┐
│  Auto-delete messages              │
├────────────────────────────────────┤
│  ○ Off                             │
│  ○ 1 hour                          │
│  ○ 6 hours                         │
│  ● 24 hours                        │
│  ○ 7 days                          │
│  ○ 30 days                         │
├────────────────────────────────────┤
│  Exemptions                        │
│   ☑ Pinned messages                │
│   ☑ System messages                │
├────────────────────────────────────┤
│        [ Cancel ]   [ Save ]       │
└────────────────────────────────────┘
```

### First-time tooltip
```
┌────────────────────────────────────┐
│  ⓘ This channel auto-deletes       │
│    messages older than 24 hours.   │
│    Pinned posts stay.              │
│                                    │
│              [ Got it ]            │
└────────────────────────────────────┘
```

### Composer hint
```
┌───────────────────────────────────────────┐
│  ⏱ deletes in 24h                         │
│  [+]  │ Type a message…                   │
│                                  [send →] │
└───────────────────────────────────────────┘
```

## 5. Component Specs

### `AutoDeleteBadge`
- Props: `ttlSeconds`.
- Renders clock icon + concise duration text.
- Tap opens info sheet with full description.

### `AutoDeleteSettingsSheet`
- Mod-only. Radio for preset TTL + exemption checkboxes.
- "Save" persists; emits realtime config-changed event.

### `ComposerAutoDeleteHint`
- Small inline pill above the message input, no interaction.

## 6. Empty / Error / Loading

- **Off state:** no badge.
- **Loading (mod sheet):** skeleton.
- **Error (save fails):** snackbar with retry.

## 7. Copy

| Surface | Copy |
|---------|------|
| Badge | deletes after {duration} |
| Sheet title | Auto-delete messages |
| Sheet helper | Older messages will be removed automatically. |
| Tooltip | This channel auto-deletes messages older than {duration}. Pinned posts stay. |
| Composer hint | deletes in {duration} |

Voice: matter-of-fact, friendly. Avoid alarm.

## 8. Motion

- Badge: static.
- Sheet: slide-up 300ms.
- Tooltip: fade-in 200ms.
- Reduced-motion: instant.

## 9. Accessibility

- Badge has Semantics label "This channel auto-deletes messages older than {duration}."
- Tap targets ≥44pt.
- Color independent: clock icon + text.

## 10. Responsive

- Phone: full-width sheet.
- Tablet/web: 480px modal.

## 11. Theming

- Standard tokens; badge uses `colorScheme.surfaceVariant` so it sits unobtrusively in the header.
