# AI Moderation — UIUX

## Screens
| # | Screen | Notes |
|---|--------|-------|
| 1 | User block dialog | Show reason + appeal CTA |
| 2 | Mod queue | List, filter, action |
| 3 | Threshold settings | per-category sliders |
| 4 | Audit log entry | classified message detail |

## Wireframes

### User block dialog
```
┌─────────────────────────────────┐
│ Message couldn't send            │
├─────────────────────────────────┤
│ Our system flagged this for      │
│ harassment.                      │
│                                  │
│ If this is a mistake, you can    │
│ appeal — a human will review.    │
│                                  │
│ [ Edit message ]   [ Appeal ]    │
└─────────────────────────────────┘
```

### Mod queue
```
┌─────────────────────────────────┐
│ Mod queue (12)            ▾ all  │
├─────────────────────────────────┤
│ "you absolute clown ..."         │
│  harassment 0.81  • 2m ago       │
│  by @jane in #general            │
│  [ Approve ]   [ Remove ]        │
│ ─────────────                    │
│ ...                              │
└─────────────────────────────────┘
```

### Threshold settings
```
┌─────────────────────────────────┐
│ AI moderation thresholds         │
├─────────────────────────────────┤
│ hate         block ████░░ 0.92   │
│              review  █████░ 0.65 │
│ harassment   block █████░ 0.95   │
│              review ████░░ 0.70  │
│ sexual       block ██████ 0.97   │
│              review █████░ 0.80  │
│ self-harm    block █████░ 0.85   │
│              review ████░░ 0.55  │
│ violence     block █████░ 0.93   │
│              review ████░░ 0.70  │
│                                  │
│ [ Save ]                         │
└─────────────────────────────────┘
```

## Components
- `<ModQueueRow>` accept/deny with keyboard shortcuts.
- `<ThresholdSlider>` dual-thumb.

## Empty/Error
- Queue empty: "Caught up. Nothing in queue."
- Classifier degraded: banner "AI moderation running in fallback mode."

## Copy
| Surface | Copy |
|---------|------|
| Block | Message couldn't send |
| Reason | flagged for <category> |
| Appeal | Appeal |

## Motion
- Queue rows fade out on action.
- Reduced-motion: instant.

## Accessibility
- All row actions accessible by keyboard.
- Screen reader announces category and severity numerically.

## Theming
- Severity uses color-blind-safe palette (not just red↔green).
