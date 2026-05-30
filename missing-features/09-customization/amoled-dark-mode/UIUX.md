# AMOLED Dark Mode — UI/UX Design

## 1. Design Principles

- Pure black is the surface — never gray.
- Saturate accents downward by ~10% so they don't burn.
- 1px hairlines for separators using `colorScheme.outlineVariant` at alpha 0.3 — never solid gray dividers.
- Reduced motion: instant transitions, no fades.
- Avoid white text on bare black where possible — use `onSurface` at 0.92 alpha for body, 1.0 for emphasis.

## 2. Information Architecture

Where this lives:
- **Entry points:** Settings → Appearance → AMOLED; battery saver snackbar; long-press dark mode toggle.
- **Parent navigation:** under Appearance settings.
- **Deep links:** `flicko://settings/appearance/amoled`.

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | Appearance Settings (AMOLED section) | Toggle + schedule | content |
| 2 | AMOLED preview tile | Mini chat snippet under AMOLED | content |
| 3 | Battery saver snackbar | One-time suggestion | idle, dismissed, accepted |

## 4. Wireframes (ASCII)

### Screen 1 — Appearance settings, AMOLED section

```
+--------------------------------------------+
| <  Appearance                              |
+--------------------------------------------+
| Theme                                      |
|  [ Tokyo Night                       v ]   |
|                                            |
| Mode                                       |
|  ( ) Light                                 |
|  ( ) Dark                                  |
|  ( ) System                                |
|                                            |
| AMOLED black                               |
|  [ x ]  When dark mode is on, use pure     |
|         black. Saves OLED battery.         |
|                                            |
|  When to use AMOLED                        |
|   ( ) Always                               |
|   (o) When system is dark                  |
|   ( ) After sunset (uses location)         |
|                                            |
|  +------------------------------------+    |
|  | preview                            |    |
|  | [black surface] alyssa: hi         |    |
|  | [black surface] mira: hey          |    |
|  +------------------------------------+    |
+--------------------------------------------+
```

### Screen 3 — Battery saver snackbar

```
+--------------------------------------------+
|                                            |
| .................                          |
|                                            |
| +----------------------------------------+ |
| |  Battery saver is on. Switch to AMOLED?| |
| |  Saves up to 30% on OLED screens.      | |
| |                                        | |
| |    ( Not now )      ( Switch on )      | |
| +----------------------------------------+ |
+--------------------------------------------+
```

### Compare wireframe — surface contrast

```
Standard dark               AMOLED
+-------------+             +-------------+
| #121212     |             | #000000     |
|  +-------+  |             |  +-------+  |
|  | #1F1F |  |             |  | #050505| |
|  +-------+  |             |  +-------+  |
+-------------+             +-------------+
```

## 5. Component Specs

### `AmoledSettingsSection`
- Props: `enabled`, `mode`, `onChanged`.
- States: idle / loading-location-permission.
- Token usage: `colorScheme.surface`, `colorScheme.onSurface`.

### `AmoledPreviewTile`
- Wraps a `Theme(...)` subtree forced to AMOLED, draws 3 mock messages.
- Read-only.

### `BatterySaverSnackbar`
- Trigger: `Battery.onBatterySaverChanged.listen` once per device per 30d.
- Tap "Switch on" → set mode=always, dismisses.

## 6. Empty / Error / Loading

- **Loading sunset coords:** chip "Detecting location" replaced with city name once known; never blocks UI.
- **Permission denied for location:** revert to "When system is dark" with toast "Location permission needed for sunset mode".

## 7. Copy

| Surface | Copy |
|---------|------|
| Toggle title | AMOLED black |
| Toggle subtitle | Pure black saves battery on OLED screens. |
| Schedule label | When to use AMOLED |
| Snackbar title | Battery saver is on |
| Snackbar body | Switch to AMOLED to save up to 30% on OLED. |
| Snackbar accept | Switch on |

Voice: practical, second-person.

## 8. Motion

- Toggle on: surfaces crossfade 120ms.
- Toggle off: same.
- Reduced motion: instant.

## 9. Accessibility

- Contrast: every text/surface pair on AMOLED tested ≥4.5:1.
- Hairlines: avoid pure 1px lines on black for visually-impaired; use 1.5px or low-alpha fill.
- Screen reader: toggle reads "AMOLED black, on" / "off".
- Reduced motion respected.

## 10. Responsive

- Phone, foldable, tablet, web — same toggle.
- On web, AMOLED applies only when OS is dark, since browsers may render differently.

## 11. Theming

AMOLED is a *preset* on top of the engine; users can still apply any community theme then enable AMOLED, which forces background tokens to black while preserving accent. Conflicts resolved by: AMOLED wins for `surface`/`background`, user theme wins for `primary`/`tertiary`/`accents`.
