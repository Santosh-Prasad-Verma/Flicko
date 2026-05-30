# Custom Fonts (Basic) — UI/UX Design

## 1. Design Principles

- The picker IS the preview — every card shows its own typeface in use.
- Default is Inter; reset is one tap from anywhere.
- Honor system Bold Text and Dynamic Type — never override system text-scale.
- Reuse `mobile/lib/features/shared/presentation/widgets/` chrome.
- Material Motion easings; respect `MediaQuery.disableAnimations`.

## 2. Information Architecture

Where this feature lives:
- Entry point 1: Settings → Appearance → "Font" row (chevron + current family name in that family).
- Entry point 2: Onboarding step "Pick your reading font" (skippable).
- Entry point 3: Settings → Accessibility → "Reading font" (links to same screen, deep-link with `recommend=dyslexia` to surface dyslexia-friendly families first).
- Deep link: `flicko://settings/appearance/font`.

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | FontPickerScreen | Pick + preview a font | content, loading, saving, error |
| 2 | LiveChatPreview | Embedded sample chat block | static |
| 3 | OnboardingFontStep | First-run picker | content, skipped |
| 4 | AppearanceSettingsRow | Entry surface | content |

## 4. Wireframes (ASCII)

### Screen 1 — FontPickerScreen

```
┌────────────────────────────────────────────────┐
│ ←  Font                                  Save  │
├────────────────────────────────────────────────┤
│                                                │
│  Live preview                                  │
│  ┌──────────────────────────────────────────┐  │
│  │ @maya  hey, did you see the new patch?   │  │
│  │ @liam  ranked at 9 out of 10 today       │  │
│  │ ```dart                                   │  │
│  │ final ok = true;     // mono stays mono  │  │
│  │ ```                                       │  │
│  └──────────────────────────────────────────┘  │
│                                                │
│  Sans                                          │
│  ┌──────────────────────────────────────────┐  │
│  │ ◉ Inter            (default)              │  │  font: Inter
│  │   Sample: The quick brown fox             │  │
│  └──────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────┐  │
│  │ ○ Roboto                                  │  │  font: Roboto
│  │   Sample: The quick brown fox             │  │
│  └──────────────────────────────────────────┘  │
│                                                │
│  Accessible                                    │
│  ┌──────────────────────────────────────────┐  │
│  │ ○ OpenDyslexic   ♿                       │  │  font: OpenDyslexic
│  │   Sample: The quick brown fox             │  │
│  └──────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────┐  │
│  │ ○ Atkinson Hyperlegible  ♿               │  │  font: Atkinson
│  │   Sample: The quick brown fox             │  │
│  └──────────────────────────────────────────┘  │
│                                                │
│  Mono · Serif · Display                        │
│  ┌──────────────────────────────────────────┐  │
│  │ ○ JetBrains Mono                          │  │
│  │   Sample: const ok = true;                │  │
│  └──────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────┐  │
│  │ ○ Lora                                    │  │
│  │   Sample: The quick brown fox             │  │
│  └──────────────────────────────────────────┘  │
│  ┌──────────────────────────────────────────┐  │
│  │ ○ Comfortaa                               │  │
│  │   Sample: The quick brown fox             │  │
│  └──────────────────────────────────────────┘  │
│                                                │
│  Reset to Inter                                │
└────────────────────────────────────────────────┘
```

Selected card has a 2px accent border and the radio is filled.

### Screen 2 — Onboarding step

```
┌────────────────────────────────────────────┐
│                                            │
│      Pick your reading font.                │
│      You can change this anytime.           │
│                                            │
│  ┌──────────────────────────────────────┐  │
│  │ ◉ Inter (default)                     │  │
│  └──────────────────────────────────────┘  │
│  ┌──────────────────────────────────────┐  │
│  │ ○ OpenDyslexic   ♿                   │  │
│  └──────────────────────────────────────┘  │
│  ┌──────────────────────────────────────┐  │
│  │ ○ Atkinson       ♿                   │  │
│  └──────────────────────────────────────┘  │
│                                            │
│  See more in Settings → Appearance.        │
│                                            │
│  [  Skip  ]            [  Continue  ]      │
└────────────────────────────────────────────┘
```

### Screen 3 — AppearanceSettingsRow

```
┌────────────────────────────────────────────┐
│ Font                       Inter        ›  │
└────────────────────────────────────────────┘
```

The "Inter" label is rendered in the user's currently-selected font.

## 5. Component Specs

### `FontCard`
- Props: `FontEntry entry`, `bool selected`, `VoidCallback onTap`.
- Renders the family name and a sample line in that family's `Regular` weight.
- A11y badge `♿` shown for OpenDyslexic + Atkinson Hyperlegible.
- States: idle / focused / selected / disabled.
- Tap target: full card, ≥56pt height.

### `LiveChatPreview`
- Renders a 2-message chat snippet plus a fenced code block.
- Code block uses JetBrains Mono regardless of selection (anti-confusion principle).
- Re-renders synchronously when the user picks a card (no save needed for preview).

### `FontFamilySection`
- Header tile (label) + a column of FontCards.
- Sections: Sans, Accessible, Mono · Serif · Display.

## 6. Empty / Error / Loading

- **Empty:** N/A — catalog is `const`, always populated.
- **Error (network):** inline banner above list: "Couldn't save — we'll try again." with `Retry` action. Local selection remains applied.
- **Loading:** skeleton list for ≤200 ms while reading from `SharedPreferences`.
- **Unknown server value:** show Inter as selected and a one-time toast "Your previous font isn't available — we picked Inter."

## 7. Copy

| Surface | Copy |
|---------|------|
| Screen title | Font |
| Save button | Save |
| Live preview header | Live preview |
| Sans section | Sans |
| Accessible section | Accessible |
| Mono/serif/display section | Mono · Serif · Display |
| Default tag | (default) |
| Sample sentence | The quick brown fox jumps over the lazy dog |
| Reset CTA | Reset to Inter |
| Network error | Couldn't save — we'll try again. |
| Onboarding title | Pick your reading font. |
| Onboarding body | You can change this anytime. |
| Onboarding link | See more in Settings → Appearance. |
| Unknown-value toast | Your previous font isn't available — we picked Inter. |
| Subset coverage warning | This font's coverage may be limited for {language}. Some characters fall back to a system font. |

Voice: friendly, concise, second-person.

## 8. Motion

- Card select: scale 1.0 → 1.01 with the radio fill animating in 200ms.
- Live preview: cross-fade 150ms when selected font changes.
- Reduced motion: replace scale + crossfade with instant change.

## 9. Accessibility

- Each card Semantics: `"{Display Name}, sample shown. {selected/not selected}. {Dyslexia friendly if applicable}."`
- Cards arranged so accessibility-friendly options are placed in their own labelled section, not buried alphabetically.
- Color contrast: card text ≥4.5:1 in all 4 themes.
- Honors `MediaQuery.boldText`: when on, sample lines render in `Bold` weight automatically.
- Honors `MediaQuery.textScaleFactor`: layout flexes vertically; cards never clip.
- Keyboard: tab order top-to-bottom; Enter/Space selects.
- Screen reader announces font change via live region.

## 10. Responsive

- Phone (≤600dp): full-width cards.
- Tablet (≥840dp): 2-column grid; live preview docked right.
- Web: same as tablet.

## 11. Theming

- All fonts tested across Light, Dark, AMOLED, Plus theme variants.
- Sample lines in the picker always render at the user's current text-scale to make selection truthful.
- Accent color (when 09-customization ships) tints the selected card border and the live preview's mention chip.
