# Custom Fonts — UI/UX Design

## 1. Design Principles

- Preview first: settings show live sample text immediately.
- Don't overwhelm: split picks into Body / Headers / Monospace.
- Honor system font as a first-class option, not buried.
- Accessibility-first: surface OpenDyslexic and Atkinson Hyperlegible up top.
- No flash of unstyled text — fonts load before render.

## 2. Information Architecture

Where this lives:
- **Entry points:** Settings → Appearance → Fonts; Accessibility settings → "Use OpenDyslexic" shortcut.
- **Parent navigation:** Appearance settings.
- **Deep links:** `flicko://settings/appearance/fonts`.

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | Font settings | Pick body/header/mono fonts | content |
| 2 | Font preview tile | Inline live sample | content |
| 3 | (v2) Upload font | Pick + sandbox parse | idle, parsing, error |

## 4. Wireframes (ASCII)

### Screen 1 — Font settings

```
+--------------------------------------------+
| <  Fonts                                   |
+--------------------------------------------+
| Body                                       |
|  +-------------------------------+ v       |
|  | Inter                         |         |
|  +-------------------------------+         |
|  Sample: The quick brown fox jumps...      |
|                                            |
| Headers                                    |
|  +-------------------------------+ v       |
|  | Inter                         |         |
|  +-------------------------------+         |
|  Sample: # Channel name                    |
|                                            |
| Monospace                                  |
|  +-------------------------------+ v       |
|  | JetBrains Mono                |         |
|  +-------------------------------+         |
|  Sample: const x = 42;                     |
|                                            |
| Use system font                            |
|  [   ] off   [ x ] on (Android)            |
|                                            |
+--------------------------------------------+
|        ( Reset to defaults )               |
+--------------------------------------------+
```

### Screen 2 — Picker bottom sheet

```
+--------------------------------------------+
|  Pick a body font                  x       |
+--------------------------------------------+
| ( ) Inter                                  |
| ( ) Roboto                                 |
| ( ) Noto Sans                              |
| ( ) Noto Serif                             |
| (o) OpenDyslexic     [accessibility]       |
| ( ) Atkinson Hyperlegible [accessibility]  |
| ( ) JetBrains Mono                         |
+--------------------------------------------+
| (v2)                                       |
| ( ) Use a font I uploaded                  |
+--------------------------------------------+
```

### v2 — Upload font

```
+--------------------------------------------+
| <  Upload font                             |
+--------------------------------------------+
|  Drop a .ttf, .otf, or .woff2 here.        |
|  Up to 2MB.                                |
|                                            |
|  [ Choose file ]                           |
|                                            |
|  Status: parsing... | error | ready        |
+--------------------------------------------+
|        ( Use this font )                   |
+--------------------------------------------+
```

## 5. Component Specs

### `FontPickerTile`
- Props: `slot` (body/header/mono), `current`, `onChange`.
- Token usage: `colorScheme.surfaceContainer`, `textTheme.bodyMedium` rendered in chosen font.

### `FontSampleStrip`
- Live preview of selected font with one or two paragraphs of sample text and a code block.

### `SystemFontToggle`
- Visible only on Android. Disabled on iOS with helper text.

## 6. Empty / Error / Loading

- **Loading bundled font:** none — bundled, instant.
- **Error v2 upload:** "We couldn't read this font. Try .ttf or .otf."

## 7. Copy

| Surface | Copy |
|---------|------|
| Title | Fonts |
| Body picker label | Body |
| Headers picker label | Headers |
| Monospace picker label | Monospace |
| OpenDyslexic descriptor | Designed to reduce letter swapping |
| Reset CTA | Reset to defaults |
| Sample (body) | The quick brown fox jumps over the lazy dog. |

Voice: friendly, second-person.

## 8. Motion

- Font swap: crossfade 80ms (text only, not background).
- Picker open: slide up 240ms.
- Reduced motion: instant swap.

## 9. Accessibility

- OpenDyslexic and Atkinson Hyperlegible labeled with badge "accessibility".
- Min body size 14sp regardless of font.
- Screen reader announces font name on selection.
- Tap targets ≥44pt.

## 10. Responsive

- Phone: list view.
- Tablet/web: split with live preview occupying right pane.

## 11. Theming

Fonts are independent of color theme. AMOLED + OpenDyslexic must look right together (verified via golden tests).
