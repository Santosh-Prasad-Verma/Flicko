# Reduced Motion Mode — UI/UX Design

## 1. Design Principles

- **Honor the OS first.** If the user already opted in at the system level, we follow without asking.
- **Replace, don't remove.** Movement is replaced by crossfade or static highlight; feedback stays.
- **No regression of meaning.** If movement signaled something (a new message arriving, a mention pulse), we keep the signal — just static.
- **Respect attention budget.** The reduced-motion settings page itself uses no decorative motion.

## 2. Information Architecture

Where this feature lives:
- Entry points: Settings → Accessibility → "Reduced motion"; first-launch nudge if OS pref detected.
- Parent navigation: Settings tab.
- Deep links: `flicko://settings/accessibility/reduced-motion`.

## 3. Screen Inventory

| # | Screen / Surface | Purpose | States |
|---|------------------|---------|--------|
| 1 | Reduced motion settings | Mode picker, GIF toggle, preview | content |
| 2 | Onboarding nudge | Detect OS pref, offer auto-on | shown once |
| 3 | Motion preview | Sample animation in chosen mode | content |

## 4. Wireframes (ASCII)

### Surface 1 — Reduced motion settings

```
┌──────────────────────────────────────────────────┐
│ ← Reduced motion                                 │
├──────────────────────────────────────────────────┤
│ Mode                                             │
│ ◯ Off                                            │
│ ◉ Auto (matches system)                          │
│ ◯ On — Reduce most motion                        │
│ ◯ On — Remove all motion                         │
│                                                  │
│ GIFs and animated stickers                       │
│ [▣ Auto-pause when reduced motion is on]         │
│                                                  │
│ Preview                                          │
│  ┌────────────────────────────┐                  │
│  │ [animated sample / static] │ [Tap to replay]  │
│  └────────────────────────────┘                  │
└──────────────────────────────────────────────────┘
```

### Surface 2 — Onboarding nudge

```
┌──────────────────────────────────────────────────┐
│ Less motion                                      │
├──────────────────────────────────────────────────┤
│  We noticed you have "Reduce Motion" on for      │
│  your device. Use it in Flicko too?              │
│                                                  │
│  [ Yes, less motion ]   [ Standard ]             │
└──────────────────────────────────────────────────┘
```

### Surface 3 — Motion preview

```
Full motion:
┌──────────┐
│  ●   →   │   slide animation, 300ms
└──────────┘

Reduced:
┌──────────┐
│ [.] [▒]  │   crossfade, 150ms
└──────────┘

Instant:
┌──────────┐
│ [▒]      │   no transition
└──────────┘
```

## 5. Component Specs

### `<MotionModePicker>`
- Props: `mode: MotionLevel`, `onChanged`.
- Variants: 4 radio options.

### `<MotionPreviewCard>`
- Props: `level: MotionLevel`.
- Renders a sample tween: a chip moving from left to right (full); fading (reduced); appearing (instant).

### `<StaticCelebration>`
- Props: `icon`, `label`.
- Replaces confetti / sparkle at celebration moments under reduced motion.

### `<MotionAwarePageRoute>`
- Drop-in for `PageRouteBuilder`.
- Reads `MotionPolicy`; swaps slide for fade for instant.

## 6. Empty / Error / Loading

- Settings page never empty.
- Preview pane: skeleton placeholder for ≤120 ms while policy loads.

## 7. Copy

| Surface | Copy |
|---------|------|
| Title | "Reduced motion" |
| Off | "Off" |
| Auto | "Auto — match my device" |
| On reduce | "On — Reduce most motion" |
| On remove | "On — Remove all motion" |
| GIF toggle | "Auto-pause GIFs and animated stickers" |
| Preview replay | "Tap to replay" |
| Onboarding ask | "Use it in Flicko too?" |
| Onboarding accept | "Yes, less motion" |
| Onboarding decline | "Standard" |

Voice: simple, neutral. Avoid clinical or pity language.

## 8. Motion (yes, this page itself)

- Settings page transitions use the user's chosen mode.
- Radio tap: 80 ms tick (or instant in instant mode).
- Preview animation: 300 ms full / 150 ms reduced / 0 ms instant.

## 9. Accessibility (meta)

- Sliders absent (deliberate — only discrete options).
- Radio group has `Semantics(role: SemanticsRole.radioGroup)`.
- Preview is marked decorative when not in focus.

## 10. Responsive

- Phone: single column.
- Tablet/web: settings + preview side by side.

## 11. Theming

- All variants work under light, dark, AMOLED, HC, color-blind themes.
- Boost celebration "static" variant uses `colorScheme.tertiary` as a flat ribbon.

## 12. What Changes Visibly

| Surface | Full | Reduced | Instant |
|---------|------|---------|---------|
| Page transition | Slide 300ms | Crossfade 150ms | Snap |
| Snackbar | Slide-up | Fade-in | Snap |
| Typing dots | Wobble loop | Static "..." | Static "..." |
| Reaction add | Bounce | Fade-in | Snap |
| GIF attachment | Loop | First frame | First frame |
| Boost celebration | Confetti | Static badge | Static badge |
| Mention highlight | Pulse | Outline ring | Outline ring |
| Voice join | Wave avatar | Static check | Static check |
