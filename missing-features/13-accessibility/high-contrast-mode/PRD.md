# High Contrast Mode — Product Requirements

> **One-line:** Dedicated high-contrast theme variant meeting WCAG AAA where possible.
> **Status:** Missing — to build
> **Category:** 13-accessibility
> **Effort:** M
> **Priority:** P0
> **Slug:** `high-contrast-mode`

## 1. Problem

WCAG 2.1 SC 1.4.3 requires text contrast of 4.5:1 (AA) and 7:1 (AAA). Discord's default themes hover around 4.6:1 for body text on dark and frequently dip below 3:1 for muted timestamps, channel hints, role tags, and icon-only buttons. There is no first-party high-contrast theme; users either run the OS-level high-contrast filter (which inverts everything indiscriminately and breaks the brand) or install the now-defunct "Discord Plus Plus" theme via the unsupported BetterDiscord client.

Concrete pain points:
- Low-vision users cannot reliably see unread indicators (4px dot at low contrast)
- Members with cataracts/macular degeneration report inability to distinguish private-channel lock icons
- Outdoor sunlight readability is poor on mobile
- The "online" green badge on profile pictures is invisible to many users

Flicko already has light, dark, and AMOLED themes. Adding a fourth "High Contrast" pair (light/dark) costs us very little and unlocks AAA-grade reading for vulnerable users.

## 2. Users & Use Cases

- **Primary persona:** Renee, 67, low vision (20/200 corrected), uses iPad outdoors. Currently leaves Flicko because she cannot see channel headers in sunlight.
- **Secondary personas:**
  - Users with light sensitivity who pair high-contrast with dark mode
  - Outdoor/mobile workers (delivery, field engineers) reading chats in sunlight
  - Designers QAing for accessibility
- **Top jobs-to-be-done:**
  1. As a low-vision user, I want a theme that meets WCAG AAA contrast for body text, so that I can read messages without straining.
  2. As a user in bright sunlight, I want a high-contrast option I can flip on without disabling Flicko's brand visuals, so that I can read chats outside.
  3. As an admin, I want server accent colours to be replaced with safe alternatives in high-contrast mode, so that custom colours don't undermine accessibility.

## 3. Goals & Non-Goals

**Goals**
- Ship a `HighContrastTheme` (light + dark) where:
  - Body text contrast ≥7:1 (AAA)
  - Large text and UI components ≥4.5:1
  - Focus rings 3:1 minimum against any neighbour
- Auto-toggle when OS high-contrast pref detected (`MediaQuery.highContrast`).
- Per-user override toggle in Settings → Accessibility.
- Server custom-accent neutralisation: fall back to a safe accent in HC mode.
- Audit existing tokens; document any unmet AAA cases.

**Non-Goals (out of scope for v1)**
- True monochrome mode (covered by future feature)
- Text-stroke / outline rendering
- Replacing user avatars (out of theme scope)
- Per-component contrast overrides

## 4. Scope (v1)

- [ ] New theme files `mobile/lib/core/theme/high_contrast_theme.dart` (light + dark)
- [ ] New `ColorScheme` extensions: `borderEmphasis`, `surfaceTintHC`, `focusOutlineHC`
- [ ] `theme_provider.dart` updated to expose `ThemeMode.highContrast(light/dark)`
- [ ] OS detection via `MediaQuery.highContrastOf(context)`
- [ ] Settings toggle: Off / Auto (system) / On Light / On Dark
- [ ] Sample contrast measurement in CI (golden colour math test)
- [ ] Server custom-accent override path: `colorScheme.primary` clamped to safe palette in HC mode
- [ ] Decorative gradients replaced with flat fills

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| HC mode adoption | ≥3% of DAU within 60d | preference setting metric |
| Self-reported reading difficulty (in-app survey) | drop ≥30% among HC users | Survicate quarterly |
| Contrast audit results | 0 AA failures, ≤5 AAA misses | CI colour math test |
| Time spent reading per session in HC mode | +12% vs. baseline | session analytics |

## 6. Open Questions / Risks

- How aggressive should we be in neutralising server accent colours? Some communities pride themselves on branded servers.
- Tokens used in image assets (e.g. illustrations) cannot be reliably swapped — keep on a denylist?
- AMOLED + HC dark may produce very stark visuals that fatigue eyes; test with consultants.
- Designers will need to update Figma library to match new tokens.

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord | No first-party HC theme | Built-in high contrast pair |
| Slack | Compact HC variant exists, partial | Token-level contrast > 7:1 |
| MS Teams | OS-driven HC; some custom UI breaks | Native HC theme that respects brand |
| Element | Manual themes via CSS | Polished, pre-made theme |

## 8. Rollout

- Internal dogfood with low-vision testers (3-week pilot) → 2% beta → 25% → GA.
- Kill switch flag: `feature.high_contrast_mode.enabled` (default ON; flag exists to disable in case of token regressions).
- Companion: a "preview my theme" page in Settings.
