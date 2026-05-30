# Full Theme Engine — UI/UX Design

## 1. Design Principles

- The theme engine designs *itself* — its UI must look right under every theme it can produce. Use only token-bound colors; never hardcode hex.
- Preview-first. Users always see the change before they commit.
- Reversible: applying a theme is one tap, reverting is one tap.
- Surface tokens consistently — every chip, button, surface obeys the same rules so a swap is global.
- Reduced motion: theme transitions crossfade instead of slide.

## 2. Information Architecture

Where this lives:
- **Entry points:** Settings → Appearance → Themes; long-press any avatar/server → "Match server theme"; deep link `flicko://themes/<id>`.
- **Parent navigation:** under Appearance settings.
- **Deep links:**
  - `flicko://themes` — marketplace home
  - `flicko://themes/<id>` — detail page
  - `flicko://themes/applied` — current applied

## 3. Screen Inventory

| # | Screen | Purpose | States |
|---|--------|---------|--------|
| 1 | Marketplace | Browse, search, filter community themes | empty, loading, content, error, offline |
| 2 | Theme Detail | Preview spec, apply, report | loading, content, error |
| 3 | Theme Preview | Live mock chat + sidebar under candidate theme | loading, content |
| 4 | Applied Theme | Current applied + clear | content |
| 5 | Server Theme Settings | Owner sets server default | content, error, no-permission |
| 6 | Report Sheet | Flag a theme | idle, submitting, done |

## 4. Wireframes (ASCII)

### Screen 1 — Marketplace

```
+--------------------------------------------+
| <  Themes                              ?   |
+--------------------------------------------+
| [ Search themes...                       ] |
| [Popular] [New] [Vetted] [Light] [Dark]    |
+--------------------------------------------+
| +-----------+  +-----------+  +----------+ |
| | Tokyo     |  | Sage      |  | Mocha   v| |
| | Night     |  | Gardens   |  | Cream    | |
| | by @mira  |  | by @noah  |  | by @ari  | |
| | 12k        |  | 4.8k     |  | 22k      | |
| +-----------+  +-----------+  +----------+ |
| +-----------+  +-----------+  +----------+ |
| | Solarized |  | Pastel    |  | OLED    v| |
| | Storm     |  | Pop       |  | Black    | |
| +-----------+  +-----------+  +----------+ |
+--------------------------------------------+
```

### Screen 2 — Theme Detail

```
+--------------------------------------------+
| <                                          |
|        +------------------------+          |
|        |  [animated preview]    |          |
|        +------------------------+          |
|                                            |
|  Tokyo Night                              v|
|  by @mira  *  12,048 installs              |
|                                            |
|  A muted blue-violet theme inspired by     |
|  the Tokyo Night editor scheme.            |
|                                            |
|  Tokens included: 64 colors, motion, type  |
|                                            |
+--------------------------------------------+
|        ( Preview )      ( Apply )          |
+--------------------------------------------+
|        Report this theme                    |
+--------------------------------------------+
```

### Screen 3 — Live Preview Sandbox

```
+--------------------------------------------+
| <  Preview: Tokyo Night                    |
+--------------------------------------------+
| #--general-----------------------+         |
| | mira: hey what's the plan?     |         |
| | noah: pizza?                   |         |
| | mira typing                    |         |
| | [text input.................] >|         |
| +-------------------------------+          |
|                                            |
|  swatches: [primary][surface][onSurface]   |
|  radii:    [4][8][12][20]                  |
|  density:  [compact][cozy][comfy]          |
+--------------------------------------------+
|  ( Apply now )         ( Try another )     |
+--------------------------------------------+
```

### Screen 5 — Server Theme Settings

```
+--------------------------------------------+
| <  Server Appearance                       |
+--------------------------------------------+
| Default theme for new members              |
|  [ Tokyo Night                       v ]   |
|                                            |
| Enforce on all members                     |
|  [   ] off  [ x ] on                       |
|  When on, members see this theme inside    |
|  the server even if they have a personal   |
|  override. They can opt out per-server.    |
|                                            |
+--------------------------------------------+
|        ( Save )                            |
+--------------------------------------------+
```

## 5. Component Specs

### `ThemeCard`
- Props: `theme: ThemeSummary`, `onTap`, `onLongPress`.
- States: idle / hover / pressed / disabled / loading.
- Token usage: `colorScheme.surfaceContainer`, `colorScheme.outline`, `textTheme.titleSmall`.

### `TokenSwatchRow`
- Renders ordered chips for the 8 most visible color tokens of the candidate spec.

### `LivePreviewMockChat`
- Hardcoded sample messages, drawn under the candidate spec only — never affects real chat.

### `ApplyButton`
- Disabled while validating; shows progress after 400ms.

## 6. Empty / Error / Loading

- **Empty marketplace:** illustration of a paint palette, "No themes here yet — be the first to publish" CTA "Create theme".
- **Error:** inline banner "Couldn't reach the theme store" + retry.
- **Loading:** skeleton grid of 6 cards with shimmer.
- **Offline:** read-only browse from cache.

## 7. Copy

| Surface | Copy |
|---------|------|
| Title (marketplace) | Themes |
| Apply CTA | Apply theme |
| Empty state | Pick a vibe — community themes, all free. |
| Error fallback | Theme didn't apply. Try again. |
| Apply confirmation | Looks good on you. |
| Server-enforced toast | Theme set by server |

Voice: friendly, second-person, never "fancy".

## 8. Motion

- Theme swap: crossfade 120ms across all surfaces; no slide, no flash.
- Card press: scale 0.97 with 80ms spring.
- Marketplace scroll: standard physics, no parallax.
- Reduced motion: replace crossfade with instant swap.

## 9. Accessibility

- Live region announces "Theme applied: Tokyo Night".
- Server-side validation rejects themes with text-on-surface contrast <4.5:1, with override only by `flicko_admin` for "creative" themes flagged with explicit warning.
- Tap targets ≥44pt; cards 88pt tall on phone.
- Reduced motion respected.
- Screen reader: each card reads "Theme name, by author, installs count".

## 10. Responsive

- Phone: 2-col grid.
- Foldable open: 3-col.
- Tablet: 4-col with side filters.
- Web: 5-col, sticky filters left.

## 11. Theming

The theme picker draws under the *currently applied* theme, not the candidate, so users always know what is real vs preview. Preview uses an isolated `Theme(...)` subtree so changes never leak.
