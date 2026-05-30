# Color Blind Mode — Product Requirements

> **One-line:** Daltonization filter and safer palettes for protan/deutan/tritan presets.
> **Status:** Missing — to build
> **Category:** 13-accessibility
> **Effort:** M
> **Priority:** P1
> **Slug:** `color-blind-mode`

## 1. Problem

Around 8% of men and 0.5% of women globally have some form of color vision deficiency (CVD). Discord's heavy use of red/green for online status, mention badges, role tags, and voice "speaking" indicators creates ambiguity for these users. WCAG SC 1.4.1 (Use of Color) prohibits relying on color alone to convey information.

Two complementary approaches help:
1. **Replace ambiguous palettes.** Choose colour pairs that remain distinguishable across the three main CVD types.
2. **Daltonization filter.** Apply an OS-style colour-shift to non-replaceable visuals (avatars, server icons, embedded images).

Flicko can deliver both. Together with `high-contrast-mode` and `captions-voice-video` (per-speaker palette), we materially improve the legibility of the entire app for CVD users.

## 2. Users & Use Cases

- **Primary persona:** Marko, deuteranope (most common form), can't reliably tell online from offline status.
- **Secondary personas:**
  - Protanopes who confuse red mention badges with grey unread badges
  - Tritanopes who can't distinguish certain server roles
  - Designers QAing colour usage
- **Top jobs-to-be-done:**
  1. As a deuteranope, I want red/green status indicators replaced with safer alternatives, so that I can tell who's online.
  2. As a CVD user with custom server avatars, I want a daltonization filter, so that I can distinguish images that weren't designed for me.
  3. As a moderator, I want to know my server's role colours pass CVD checks, so that my members aren't excluded.

## 3. Goals & Non-Goals

**Goals**
- Three CVD presets: Protanopia, Deuteranopia, Tritanopia.
- Per-preset palette overrides for app tokens (status, mentions, roles, voice indicators).
- App-wide daltonization filter via `ColorFilter.matrix`.
- Optional "icon shape supplement" — pair colour with shape so colour is never the only cue.
- Server admin "CVD score" report on role colours.

**Non-Goals (out of scope for v1)**
- Achromatopsia (full grayscale) — covered by HC mode at v2.
- Per-channel palette overrides.
- Changing user-uploaded image colours (we filter at render, not modify pixel data on upload).

## 4. Scope (v1)

- [ ] Settings: Off / Auto (system) / Protanopia / Deuteranopia / Tritanopia.
- [ ] System pref detection (iOS Display Accommodations, Android Color Correction).
- [ ] Daltonization matrices applied via `ColorFiltered` at app root.
- [ ] Token replacement for status, mentions, roles, voice "speaking" ring.
- [ ] Optional: shape supplement (●, ▲, ■, ◆) on status indicators.
- [ ] Server admin role-colour CVD checker.

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Adoption among self-id'd CVD users | ≥40% | preference + survey |
| Status-indicator misread reports | drop ≥80% in 60d | NPS / qualitative |
| Server admin CVD-fix rate (after warning) | ≥35% | telemetry |
| Frame-time delta with filter on | <2 ms p99 | client traces |

## 6. Open Questions / Risks

- Daltonization filter changes how everything looks; some users prefer "palette-only" without the filter.
- Colour-naming UI text ("the red badge") needs review.
- Custom emoji and stickers are unaffected.
- Boost glow gradient may look wrong; replace with flat fill in CVD mode.

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord | None first-party | First-party + admin checker |
| Slack | None | We bring presets |
| Microsoft Teams | OS-driven only | Per-app fine control |
| Apple iOS | OS-level filter | We integrate inside the app |

## 8. Rollout

- Internal dogfood with self-id'd CVD users → 5% beta → GA.
- Kill switch flag: `feature.color_blind_mode.enabled` (default ON).
