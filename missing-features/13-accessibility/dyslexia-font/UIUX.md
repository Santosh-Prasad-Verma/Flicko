# Dyslexia Font — UI/UX Design

## 1. Design Principles

- **Neutral copy.** "Reader font", not "Dyslexia font", in primary headings. The longer description names dyslexia for users who search for it.
- **Live preview drives confidence.** Users see the change instantly on a sample paragraph before committing.
- **Reversible.** A "Restore default" button is always present.
- **Non-disruptive.** Code blocks and system numerals stay monospaced; emoji are unchanged.
- Match Flicko's existing dark/light tokens; never roll a custom palette here.

## 2. Information Architecture

Where this feature lives:
- Entry points: Settings → Accessibility → "Reader font"; help-bot suggestion when user toggles `dyslexia_self_id` in onboarding; in-chat font long-press shortcut (power user).
- Parent navigation: Settings tab.
- Deep links: `flicko://settings/accessibility/reader-font`.

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | Reader font settings | Pick font, adjust spacing, see preview | content |
| 2 | Sample preview pane | Live preview within settings | content |
| 3 | Font credits dialog | OFL attribution for bundled fonts | content |
| 4 | Onboarding nudge | Optional: offer reader font on first launch | shown once |

## 4. Wireframes (ASCII)

### Screen 1 — Reader font settings

```
┌────────────────────────────────────────────┐
│ ← Reader font                              │
├────────────────────────────────────────────┤
│ Font                                       │
│ ◯ System default     Aardvark              │
│ ◉ OpenDyslexic       Aardvark              │
│ ◯ Atkinson Hyperleg. Aardvark              │
│                                            │
│ Line height                                │
│ 1.2 ─────●──── 2.0   (current 1.6)         │
│                                            │
│ Letter spacing                             │
│ 0   ──●──────── 0.08 (current 0.02em)      │
│                                            │
│ Preview                                    │
│ ┌────────────────────────────────────────┐ │
│ │ The quick brown fox jumps over the     │ │
│ │ lazy dog. Code keeps its own font:     │ │
│ │ `console.log('hi');`                   │ │
│ └────────────────────────────────────────┘ │
│                                            │
│ [ Restore defaults ]   [ Font credits ]    │
└────────────────────────────────────────────┘
```

### Screen 2 — Onboarding nudge

```
┌────────────────────────────────────────────┐
│ Reading comfort                            │
├────────────────────────────────────────────┤
│ Find sans-serif fonts hard to read?        │
│ Flicko has two reader fonts you can try.   │
│                                            │
│ [ Try OpenDyslexic ]                       │
│ [ Try Atkinson ]                           │
│ [ Skip ]                                   │
└────────────────────────────────────────────┘
```

### Screen 3 — Font credits dialog

```
┌────────────────────────────────────────────┐
│ Font credits                          ╳    │
├────────────────────────────────────────────┤
│ • OpenDyslexic (OFL 1.1)                   │
│   opendyslexic.org                         │
│ • Atkinson Hyperlegible (OFL 1.1)          │
│   brailleinstitute.org/freefont            │
│                                            │
│ View licences →                            │
└────────────────────────────────────────────┘
```

## 5. Component Specs

### `<ReaderFontPicker>`
- Props: `family: ReaderFontFamily`, `onChanged`.
- Variants: radio list with sample word "Aardvark" rendered in that family.
- `Semantics(role: SemanticsRole.radioGroup, label: 'Font family')`.

### `<SpacingSlider>`
- Props: `label`, `min`, `max`, `step`, `value`, `onChanged`.
- Step: 0.05 for line height, 0.005 for letter spacing.
- Tick marks at presets ("Close", "Comfortable", "Wide").
- Slider has `Semantics(value: '0.04em', label: 'Letter spacing')`.

### `<ReaderFontPreview>`
- Props: `prefs`.
- Renders a chat-style sample including a code block to demonstrate preserved monospace.
- Updates with 100ms cross-fade on change (instant under reduced motion).

## 6. Empty / Error / Loading

- Settings page is never empty.
- If a font asset fails to load, inline banner: "Couldn't load this font. We've reverted to system default."
- Loading: brief skeleton over the preview pane (≤120 ms) when prefs are still hydrating.

## 7. Copy

| Surface | Copy |
|---------|------|
| Title | "Reader font" |
| Subhead | "Designed to be easier on the eyes — especially for readers with dyslexia." |
| System default | "System default" |
| OpenDyslexic | "OpenDyslexic" |
| Atkinson | "Atkinson Hyperlegible" |
| Line height | "Line height" |
| Letter spacing | "Letter spacing" |
| Restore | "Restore defaults" |
| Sample paragraph | "The quick brown fox jumps over the lazy dog." |

Voice: welcoming, factual. Mentions dyslexia in subhead but does not gatekeep the feature behind that label.

## 8. Motion

- Slider value updates in real-time; preview reflows with a 100 ms cross-fade.
- Reduced motion: instant.

## 9. Accessibility (meta — settings page itself)

- Sliders expose value to screen readers.
- "Restore defaults" has high-contrast outline.
- Touch target ≥48dp.
- Radios announce position ("1 of 3").

## 10. Responsive

- Phone: single column, preview docked at bottom.
- Foldable / tablet: settings on left, larger preview pane on right.
- Web: keyboard-driven with arrow-key adjustments on sliders.

## 11. Theming

- Reader font choice is independent from theme choice.
- All three font options work under light, dark, AMOLED, and high-contrast themes.
- Server accent colours unaffected.

## 12. First-run Education

When a user opens this page for the first time, a one-shot callout explains:

> "These settings affect the chat and most UI text. Code blocks always stay in a coding font."

Dismissable; never reappears.
