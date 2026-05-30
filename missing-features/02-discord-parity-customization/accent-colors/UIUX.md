# Accent Colors — UI/UX Design

## 1. Design Principles

- Match Flicko's existing dark/light tokens in `mobile/lib/core/theme/app_theme.dart`.
- Reuse `FlickoCard`, `FlickoListTile`, and `PrimaryButton` from `mobile/lib/features/shared/presentation/widgets/`.
- Motion: Material 3 emphasized easing, 250ms; respect `MediaQuery.disableAnimations`.
- Accessibility: every swatch has a Semantics label `"Accent color {name}, contrast ratio {x}:1 against background"`. Swatch tap target is 56pt.
- Never lock the user out of changing color back; "Reset to default" is always one tap away.

## 2. Information Architecture

Where this feature lives:
- Entry point 1: Settings → Appearance → "Accent color" row (chevron + current swatch).
- Entry point 2: First-run onboarding step "Make it yours" (skippable).
- Entry point 3: Long-press your own avatar in any chat → "Change accent" quick action.
- Parent navigation: Appearance settings.
- Deep link: `flicko://settings/appearance/accent`.

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | AccentColorScreen | Pick from palette + preview | loading, content, saving, error |
| 2 | CustomHexSheet | Plus-only modal for arbitrary hex | idle, validating, valid, invalid, paywall |
| 3 | OnboardingAccentStep | First-run picker | content, skipped |
| 4 | AppearanceSettingsRow | Entry surface; shows current swatch | content only |

## 4. Wireframes (ASCII)

### Screen 1 — AccentColorScreen

```
┌────────────────────────────────────────────┐
│ ←  Accent color                       Save │
├────────────────────────────────────────────┤
│                                            │
│  ┌──────────────────────────────────────┐  │
│  │  @maya  hey, quick question on the   │  │ <- live preview
│  │         design — 3 mentions          │  │    uses selected
│  │                                      │  │    color
│  │              [  Send  ]  ●           │  │
│  └──────────────────────────────────────┘  │
│                                            │
│  Vivid                                     │
│  ◯  ◯  ◯  ◯  ◯  ◯  ◯  ◯                    │
│  P1 P2 P3 P4 P5 P6 P7 P8                   │
│                                            │
│  Muted                                     │
│  ◯  ◯  ◯  ◯  ◯  ◯  ◯  ◯                    │
│  M1 M2 M3 M4 M5 M6 M7 M8                   │
│                                            │
│  ┌──────────────────────────────────────┐  │
│  │ ✦ Custom hex     Plus only      ›    │  │
│  └──────────────────────────────────────┘  │
│                                            │
│  Reset to Flicko purple                    │
└────────────────────────────────────────────┘
```

Selected swatch shows a 2px ring of `colorScheme.onSurface` and a checkmark.

### Screen 2 — CustomHexSheet

```
┌────────────────────────────────────────────┐
│              Custom accent                 │
├────────────────────────────────────────────┤
│                                            │
│   ┌────────────────┐                       │
│   │  #              │  [ Apply ]           │
│   └────────────────┘                       │
│                                            │
│   ●  Live preview tile                     │
│                                            │
│   ⚠ Contrast: 3.1:1 — too low for AA      │
│      Try a brighter shade.                 │
│                                            │
└────────────────────────────────────────────┘
```

### Screen 3 — Onboarding step

```
┌────────────────────────────────────────────┐
│                                            │
│       Make Flicko yours.                   │
│       Pick a color you'll see often.       │
│                                            │
│   ◯ ◯ ◯ ◯ ◯ ◯ ◯ ◯                          │
│   ◯ ◯ ◯ ◯ ◯ ◯ ◯ ◯                          │
│                                            │
│   You can change this anytime in Settings. │
│                                            │
│   [  Skip  ]            [  Continue  ]     │
└────────────────────────────────────────────┘
```

### Screen 4 — AppearanceSettingsRow

```
┌────────────────────────────────────────────┐
│ Accent color                       ●  ›    │
└────────────────────────────────────────────┘
```

The dot is a 16pt filled circle in the user's current color.

## 5. Component Specs

### `SwatchTile`
- Props: `Color color`, `String name`, `bool selected`, `double contrastRatio`, `VoidCallback onTap`.
- States: idle / focused / selected / disabled (paywall).
- Token usage: `colorScheme.onSurface` for ring, `textTheme.labelSmall` for tooltip.
- Size: 56x56pt circle, 12pt gap in grid (4 columns on phone, 8 on tablet).

### `LivePreview`
- Renders a fake message with `@username` mention chip and a primary CTA, both tinted with the in-flight selection.
- Updates synchronously on swatch tap (no debounce).

### `CustomHexField`
- Material 3 `TextField` with monospaced hex input.
- Real-time validation; errors shown beneath, not as a snackbar.

## 6. Empty / Error / Loading

- **Empty:** N/A — palette is always populated from a `const` list.
- **Error (network):** inline banner above grid: "Couldn't save — we'll try again." with `Retry` action. Selection remains visually applied.
- **Loading:** skeleton swatch grid for 200ms max while reading from `SharedPreferences`; then real grid.
- **Paywall:** if user taps Custom hex without Plus, sheet shows muted palette + a `[Get Plus]` CTA that deep-links to the existing premium upsell.

## 7. Copy

| Surface | Copy |
|---------|------|
| Screen title | Accent color |
| Save button | Save |
| Live preview header | Preview |
| Vivid section | Vivid |
| Muted section | Muted |
| Custom hex CTA | Custom hex — Plus only |
| Reset button | Reset to Flicko purple |
| Onboarding title | Make Flicko yours. |
| Onboarding body | Pick a color you'll see often. |
| Network error | Couldn't save — we'll try again. |
| Contrast error | This color is too light against your theme. Try a brighter or darker shade. |
| Paywall body | Custom hex is part of Flicko Plus. Free users have 16 great choices. |

Voice: friendly, concise, second-person. No jargon.

## 8. Motion

- Swatch select: scale 1.0 → 1.06 → 1.0 over 200ms with ring fade-in.
- Live preview: cross-fade 150ms when color changes.
- Save button: morphs to a check icon on success (300ms), then back after 1.2s.
- Reduced motion: replace scale with crossfade only.

## 9. Accessibility

- Every swatch announces name + contrast ratio via Semantics label.
- Selected state announced as `selected: true`.
- Color-blind users: each swatch has a hidden 2-letter code overlay (`P1`...`M8`) shown when `MediaQuery.boldText` is true OR via long-press tooltip.
- Color contrast: every palette swatch ≥ 4.5:1 in BOTH dark and light themes (verified by unit test `accent_palette_contrast_test.dart`).
- Keyboard / d-pad: tab order is row-major; Space activates.
- Reduced motion: replace movement with crossfade.

## 10. Responsive

- Phone (≤600dp): 4 columns × 4 rows.
- Foldable (600–840dp): 6 columns × 3 rows.
- Tablet/web (≥840dp): 8 columns × 2 rows + preview side-by-side.

## 11. Theming

- Light + Dark + AMOLED + Plus theme variants — accent overlays each.
- AMOLED: forces background `#000000`; we additionally darken muted palette entries by 8% lightness so they don't hum on OLED.
- If a store theme (`activeStoreThemeProvider`) is equipped, it wins for surface colors but the user's accent still overrides primary/secondary.
