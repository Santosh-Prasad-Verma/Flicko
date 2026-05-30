# AI Semantic Search — UIUX

## Screens
| # | Screen | Notes |
|---|--------|-------|
| 1 | Search results | Mode toggle: Smart / Keyword |
| 2 | Empty state | Zero-result prompt |
| 3 | Per-message opt-out | hide-from-search action |
| 4 | Settings | Server-level opt-in |

## Wireframes

### Search results
```
┌──────────────────────────────────┐
│ Search                          ⓧ │
│  ────────────────                │
│ "what we decided about pricing"  │
│  [Smart ●] [Keyword ○]   ▾ Filters│
├──────────────────────────────────┤
│ #pricing-thread · alice · 12 Apr  │
│  "Let's go with $9 monthly"       │
│  match: meaning                  │
├──────────────────────────────────┤
│ #standup · bob · 14 Apr           │
│  "we agreed on 9/mo and 90/yr"    │
│  match: meaning + keyword         │
├──────────────────────────────────┤
│ ... 8 more                        │
└──────────────────────────────────┘
```

### Empty
```
┌──────────────────────────────────┐
│ No matches                        │
│ Try simpler words or fewer        │
│ filters.                          │
└──────────────────────────────────┘
```

## Components
- `<SearchModeToggle>` Smart / Keyword.
- `<MatchBadge>` "meaning", "keyword", "both".

## Empty/Error
- "Smart search is warming up" if embedder lag >5 min.

## Copy
| Surface | Copy |
|---------|------|
| Toggle Smart | Smart |
| Match badge | meaning · keyword |
| Empty | No matches |

## Motion
- Result list fade-in 150ms.
- Reduced-motion: instant.

## Accessibility
- Mode toggle is a 2-state radio (proper Semantics).
- Each result reads "channel, author, date, snippet".

## Theming
- Match badge uses neutral chip; not color-only.
