# Animated Server Icons — UI/UX Design

## 1. Design Principles

- Animation is decoration — never required to understand the UI.
- Animations pause the moment they leave the viewport or the user is in low-power mode.
- Reduced motion = static, with no shimmer or crossfade either.
- Upload UI shows live preview before commit.
- Photosensitive warning is friendly, not lecturing.

## 2. Information Architecture

Where this lives:
- **Entry points:** Server Settings → Appearance → Server icon; long-press sidebar icon (owner) → "Edit icon".
- **Parent navigation:** Server settings.
- **Deep links:** `flicko://servers/<sid>/settings/appearance/icon`.

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | Server Appearance | Manage icon, banner, splash | content |
| 2 | Icon picker bottom sheet | Static / animated tabs | loading, content, error |
| 3 | Upload preview | Live loop, file info | content |
| 4 | Photosensitive warning dialog | Confirm risky upload | idle |
| 5 | Sidebar icon | Renders chosen format | static, animating, paused |

## 4. Wireframes (ASCII)

### Screen 1 — Server Appearance

```
+--------------------------------------------+
| <  Server Appearance                       |
+--------------------------------------------+
|        +---------+                         |
|        |  ICON   |  (loops)                |
|        +---------+                         |
|         Replace icon                       |
|                                            |
| Banner                                     |
|  [ existing banner image preview        ]  |
|                                            |
| Splash                                     |
|  [ + Add splash image                   ]  |
+--------------------------------------------+
```

### Screen 2 — Picker bottom sheet

```
+--------------------------------------------+
|        Edit server icon          x         |
+--------------------------------------------+
|  [ Static ] [ Animated  *  free ]          |
+--------------------------------------------+
| Pick a Lottie .json or .gif up to 512KB.   |
|                                            |
|   [ Choose from gallery ]                  |
|                                            |
|   Or pick a sample:                        |
|   [pulse] [orbit] [wave] [confetti]        |
|                                            |
+--------------------------------------------+
```

### Screen 3 — Upload preview

```
+--------------------------------------------+
| <  Preview                                 |
+--------------------------------------------+
|                                            |
|         +-----------+                      |
|         |   ICON    |  loops               |
|         +-----------+                      |
|                                            |
|  logo.json   84 KB   30fps   1.8s loop     |
|                                            |
|  Photosensitive scan: [ pass ]             |
|                                            |
+--------------------------------------------+
|        ( Cancel )       ( Use this )       |
+--------------------------------------------+
```

### Screen 4 — Photosensitive warning

```
+--------------------------------------------+
|       (!) This icon flashes a lot          |
+--------------------------------------------+
| It may affect viewers with photosensitive  |
| epilepsy. Members can disable animation,   |
| but consider a calmer icon.                |
|                                            |
|    ( Choose different )    ( Use anyway )  |
+--------------------------------------------+
```

### Screen 5 — Sidebar icon states

```
+----+   active           +----+   paused           +----+   reduced-motion
| @  |   loops 30fps      | @  |   first frame only | @  |   static.webp
+----+                    +----+                    +----+
```

## 5. Component Specs

### `AnimatedServerIcon`
- Props: `format`, `url`, `staticUrl`, `enabled`, `radius`.
- Pauses when:
  - widget invisible (VisibilityDetector below 0.1)
  - reduced motion on
  - battery saver on
  - user setting "Animate icons" off
- Always shows static fallback first paint to avoid jank.

### `IconPickerSheet`
- Tabs Static / Animated; Animated tab gated by `feature.animated_icons.enabled`.

## 6. Empty / Error / Loading

- **Empty:** initials avatar with edit pencil overlay.
- **Loading upload:** circular progress under icon ring.
- **Error: "We couldn't process this file. Try a smaller .gif or Lottie .json."**
- **Reduced motion:** no shimmer, instant static.

## 7. Copy

| Surface | Copy |
|---------|------|
| Picker title | Edit server icon |
| Animated tab | Animated · free |
| Upload size hint | Up to 512KB. Lottie or GIF. |
| Photosensitive warning title | This icon flashes a lot |
| Sample list label | Or pick a sample |
| Success toast | Icon updated |

## 8. Motion

- Sidebar icon respects natural Lottie/GIF loop.
- App-side overlays (selection ring, badges) use 200ms ease.
- Reduced motion: static, no crossfade either.

## 9. Accessibility

- Sidebar icon has Semantics label "<server name>, animated icon".
- "Animate icons" device setting — default ON; auto-OFF when reduced motion.
- Photosensitive flagged icons trigger a one-time per-device pre-roll prompt for the viewer: "This server's icon flashes; pause animations?" with quick toggle.
- Tap targets ≥44pt.

## 10. Responsive

- Phone sidebar: 56pt icon.
- Tablet/web: 72pt icon, animation still clean.
- Web tabs (DOM): pause when tab hidden.

## 11. Theming

Animated icons render on top of theme tokens; ring/border uses `colorScheme.outlineVariant`. AMOLED keeps icon as-is — no manipulation of the asset.
