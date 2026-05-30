# AI Meeting Notes — UIUX

## Screens
| # | Screen | Notes |
|---|--------|-------|
| 1 | In-call recording indicator | shown for all participants |
| 2 | Notes preview message embed | posted in channel |
| 3 | Full notes view | tabs: Summary, Action items, Transcript |
| 4 | Action item → task convert | quick add |
| 5 | Channel setting | enable, retention |

## Wireframes

### Notes preview embed
```
┌──────────────────────────────────┐
│ 📝 Meeting notes · 28 min · 4 ppl │
├──────────────────────────────────┤
│ Summary                           │
│ • Discussed Q3 OKRs               │
│ • Aligned on hiring plan          │
│                                   │
│ Action items                      │
│ ☐ @alice draft hiring deck (Fri)  │
│ ☐ @bob book offsite venue         │
│                                   │
│ [ View full ]                     │
└──────────────────────────────────┘
```

### Full notes
```
┌──────────────────────────────────┐
│ Meeting · #standup · 28 min       │
├──────────────────────────────────┤
│ Summary | Action items | Transcript│
├──────────────────────────────────┤
│ [content per tab]                 │
└──────────────────────────────────┘
```

## Components
- `<RecordingBanner>` red dot + "Notes are being recorded".
- `<ActionItemRow>` with checkbox + assignee + due chip.

## Empty/Error
- Failed: "Couldn't generate notes. Transcript is available." with link.

## Copy
| Surface | Copy |
|---------|------|
| Recording banner | Notes are being recorded |
| Off banner | Notes are off in this channel |
| Embed title | Meeting notes |

## Motion
- Embed scroll fades.
- Reduced-motion: instant.

## Accessibility
- Recording banner is announced to screen reader on session start.
- Action item rows readable as a single semantic node.

## Theming
- Action items use accent color for due dates.
