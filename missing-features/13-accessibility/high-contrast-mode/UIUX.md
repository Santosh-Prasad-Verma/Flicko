# High Contrast Mode — UI/UX Design

## 1. Design Principles

- **Maximize legibility, preserve identity.** HC mode keeps Flicko's geometry — only colours and stroke weights change.
- **Tokens, not overrides.** All contrast changes live in the theme; no inline colour hacks.
- **No new icons.** Existing iconography is enlarged in stroke weight and given solid backgrounds.
- **Honour OS pref.** Auto mode flips with `MediaQuery.highContrast` so the user does not have to repeat themselves.

## 2. Information Architecture

Where this feature lives:
- Entry points: Settings → Accessibility → "High contrast"; first-launch onboarding step (when OS pref detected); status-bar quick toggle (if OS supports).
- Parent navigation: Settings tab.
- Deep links: `flicko://settings/accessibility/high-contrast`.

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | Accessibility → High contrast | Toggle and preview | content |
| 2 | Theme preview (live) | Show before/after on a sample chat | side-by-side, full-screen |
| 3 | Onboarding HC step | Detect OS HC and offer auto-on | initial, manual override |

## 4. Wireframes (ASCII)

### Screen 1 — High contrast settings

```
┌────────────────────────────────────────────┐
│ ← High contrast                            │
├────────────────────────────────────────────┤
│ Mode                                       │
│ ◯ Off                                      │
│ ◉ Auto (matches system)                    │
│ ◯ On — Light                               │
│ ◯ On — Dark                                │
│                                            │
│ Server accents                             │
│   [▣ Replace custom accents in HC mode  ]  │
│   Some servers brand themselves with       │
│   colours that don't reach AAA contrast.   │
│                                            │
│ Preview                                    │
│  ┌────────────────────────────────────┐    │
│  │ #general  ·  12 unread             │    │
│  │  Asha 09:14   Hi everyone          │    │
│  │  Ravi 09:15   Did you see the doc? │    │
│  │  [ Send ]                          │    │
│  └────────────────────────────────────┘    │
│  Tap to swap light/dark.                   │
└────────────────────────────────────────────┘
```

### Screen 2 — Side-by-side preview (tablet)

```
┌──────────────────────┬──────────────────────┐
│ Default              │ High contrast        │
│ [grayed sample chat] │ [HC sample chat]     │
│                      │                      │
│                      │                      │
└──────────────────────┴──────────────────────┘
```

### Screen 3 — Onboarding HC step

```
┌────────────────────────────────────────────┐
│ Welcome to Flicko                  4 / 5   │
├────────────────────────────────────────────┤
│  We noticed you have High Contrast on      │
│  for your device.                          │
│                                            │
│  Use Flicko's matching theme too?          │
│                                            │
│  [ Use HC theme ]   [ Standard ]           │
└────────────────────────────────────────────┘
```

## 5. Component Specs

### `<ContrastModePicker>`
- Props: `mode: HighContrastMode`, `onChanged`.
- Variants: radio list of 4 options.
- Labels include "matches system" annotation when OS HC is detected.

### `<ThemePreviewCard>`
- Props: `theme: ThemeData`, `accent: Color?`.
- Renders a chat-like sample using `Theme(data: ...)` to scope styles.
- Exposes a tap handler that swaps light/dark variants.

### `<AccentNeutralizer>`
- Pure utility; transforms a `Color` to nearest WCAG-safe equivalent in current HC palette.

## 6. Empty / Error / Loading

- **Empty:** screen always has at least four radio options.
- **Error:** preference write failure shows inline retry banner.
- **Loading:** preview card shows skeleton stripes for ~200 ms.

## 7. Copy

| Surface | Copy |
|---------|------|
| Title | "High contrast" |
| Mode label | "Mode" |
| Off | "Off" |
| Auto | "Auto — match my device" |
| On Light | "On — Light theme" |
| On Dark | "On — Dark theme" |
| Server accents toggle | "Replace custom accents" |
| Server accents help | "Some servers use colours that don't reach AAA contrast. Replace them with safer ones." |
| Preview hint | "Tap the preview to swap light and dark." |

Voice: factual, short. Avoid medical or pity language ("for the visually impaired"); say "high contrast" or "more readable colours".

## 8. Motion

- Theme switch: 100 ms cross-fade (0 ms when reduced-motion is on).
- Radio selection: 80 ms tick.
- Preview swap: 120 ms.

## 9. Accessibility (meta)

- The settings page itself complies with HC requirements at all times — including when HC is off — so that users currently in HC mode never see weak contrast on this screen.
- Radio group has `Semantics(role: SemanticsRole.radioGroup)`.
- Preview card is marked decorative when off-screen.
- Tap target ≥48dp.

## 10. Responsive

- Phone: stacked.
- Foldable open: settings on left, preview on right.
- Tablet: same as foldable.
- Web: side-by-side preview at all times above 1024px width.

## 11. Theming

This feature **defines** the high-contrast theming layer. It does not introduce server-accent options. When HC is active and `neutralize_server_accents` is on:
- `colorScheme.primary` is set to `focusOutlineHC` regardless of server accent.
- Avatar borders use `borderEmphasis`.
- Mention/role chips fall back to filled high-contrast pairs.

## 12. Visual Tokens (illustrative)

```
Surface     ▓▓▓▓▓▓▓▓▓▓ #FFFFFF (light) / #000000 (dark)
On surface  ░░░░░░░░░░ #000000 / #FFFFFF
Primary     ▒▒▒▒▒▒▒▒▒▒ #0033CC / #66B3FF
Border      ━━━━━━━━━━ #1A1A1A / #FFFFFF (2px)
Focus ring  ╔════════╗ #0033CC / #FFFFFF (3px)
Error       ××××××××× #B00020 / #FF6B6B
```
