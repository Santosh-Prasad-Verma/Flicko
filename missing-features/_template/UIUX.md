# [Feature Name] — UI/UX Design

## 1. Design Principles

- Match Flicko's existing dark/light theme tokens (see `mobile/lib/core/theme/`)
- Prefer existing components from `mobile/lib/features/shared/presentation/widgets/`
- Motion: Material Motion easings; respect `reduced-motion` flag
- Accessibility: every interactive element has Semantics label and >=44pt tap target

## 2. Information Architecture

Where this feature lives:
- Entry points (3 max): __, __, __
- Parent navigation: __
- Deep links: `flicko://<path>`

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | __ | __ | empty, loading, content, error |
| 2 | __ | __ | __ |

## 4. Wireframes (ASCII)

### Screen 1 — __

```
┌────────────────────────────────────┐
│ ← Title                  ⋯         │
├────────────────────────────────────┤
│                                    │
│  [content area]                    │
│                                    │
│                                    │
├────────────────────────────────────┤
│                          ●  CTA    │
└────────────────────────────────────┘
```

### Screen 2 — __

```
[diagram]
```

## 5. Component Specs

### `<Component>`
- Props: __
- States: idle/hover/pressed/disabled
- Token usage: `colorScheme.primary`, `textTheme.titleMedium`

## 6. Empty / Error / Loading

- **Empty:** illustration + 1-line message + primary CTA
- **Error:** inline banner; never block whole screen
- **Loading:** skeleton shimmer matching final layout

## 7. Copy

| Surface | Copy |
|---------|------|
| Title | __ |
| CTA | __ |
| Empty state | __ |
| Error fallback | __ |

Voice: friendly, concise, second-person. No jargon.

## 8. Motion

- Page transitions: shared-axis Y, 300ms
- Inline state changes: fade-in 150ms
- Long actions: progress indicator after 400ms

## 9. Accessibility

- Screen reader: announce state changes via live region
- Color contrast: ≥4.5:1 text, ≥3:1 large text
- Keyboard: full tab order; Enter/Space activate primaries
- Reduced motion: replace movement with crossfade

## 10. Responsive

- Phone, foldable, tablet, web
- Breakpoints: 360 / 600 / 840 / 1200

## 11. Theming

- Light + Dark + AMOLED variants
- Honor server accent color (when feature [09-customization/accent-colors] ships)
