# Custom Fonts (Basic) — Product Requirements

> **One-line:** Users pick from a curated list of bundled fonts that apply across the entire app.
> **Status:** Missing — to build
> **Category:** 02-discord-parity-customization
> **Effort:** S
> **Priority:** P1

## 1. Problem

Discord shipped font choice on desktop (2023) but mobile users still can't change the typeface. Flicko ships only one font today (system default Roboto/SF). Two distinct user groups regularly request a font picker:

1. **Aesthetic-driven users** want personality — JetBrains Mono in their dev server, a serif for book clubs, a chunky display for hype.
2. **Accessibility-driven users** need OpenDyslexic, Atkinson Hyperlegible, or larger x-height fonts to read comfortably.

Today, the only workaround is to change the system font — which on iOS isn't possible, and on Android changes everything (notification shade, system UI), which most users won't do for one app.

Evidence:
- 31 GitHub Discussions thread titles include "OpenDyslexic" or "dyslexia font" across Discord/Slack/Teams clones in the last 18 months.
- Our `#a11y-feedback` Slack: 14 distinct users asked for a dyslexia-friendly option in 2026 alone.
- Internal poll: 62% of dogfood users who tried system-font swap on Android went back; "too disruptive."

Cost is the constraint. We will NOT host font CDN traffic or download fonts at runtime in v1 — every font ships in the app bundle. Cost = $0.

## 2. Users & Use Cases

- **Primary persona:** Sam, 17, college student with dyslexia. Wants OpenDyslexic everywhere.
- **Secondary personas:**
  - Devs who want a monospaced font everywhere (JetBrains Mono nerds).
  - Aesthetic-leaning teens who want their app to look like Notion / Apple Notes.
  - Bilingual users who want a font with stronger Latin + Devanagari coverage (Inter does well here).

Top 3 jobs-to-be-done:
1. As a dyslexic user, I want OpenDyslexic across all surfaces, so messages stop blurring together.
2. As a dev who lives in monospace, I want JetBrains Mono for chat too, so my code snippets and prose share aesthetic.
3. As a stylist, I want to switch font weight + family to match my mood, without leaving Flicko.

## 3. Goals & Non-Goals

**Goals**
- 7 curated fonts shipped in app bundle:
  - Inter (default).
  - Roboto (system fallback).
  - OpenDyslexic.
  - Atkinson Hyperlegible.
  - JetBrains Mono.
  - Lora (serif).
  - Comfortaa (display).
- One global font selection persists per user.
- Live preview screen with a sample chat block.
- Font choice synced to backend so it follows the user across devices.
- Variable-weight version where available; otherwise ship Regular + Medium + Bold.
- Settings entry under Appearance → Font.
- Honors `MediaQuery.boldText` (system Bold Text accessibility setting).

**Non-Goals (out of scope for v1)**
- User-uploaded TTFs.
- Per-channel or per-message font.
- Per-language font fallback chain (works fine via Flutter's font fallback).
- Remote font downloading via Google Fonts CDN.
- Variable axes (slnt, opsz) controls.
- Plus-tier exclusive fonts (revisit when we have a clear unlock).

## 4. Scope (v1)

- [x] Bundle 7 font families in `mobile/assets/fonts/`.
- [x] Add `font_family` column to `user_settings`.
- [x] `PATCH /users/me/settings` accepts `font_family`.
- [x] `FontFamilyNotifier` Riverpod provider.
- [x] `FontPickerScreen` with live preview, listed in Appearance.
- [x] App-wide propagation through `themeDataProvider`.
- [x] Whitelist enforcement (server-side rejects unknown values).
- [x] App size budget: total bundled fonts ≤ 4.0 MB compressed.

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Adoption (% DAU who set non-default) | ≥18% within 30d | PostHog `font.changed` |
| OpenDyslexic adoption among self-declared dyslexic users | ≥40% within 60d | accessibility settings cohort |
| Retention | +0.8 pp W4 vs control | A/B 5% holdout |
| App size delta | ≤4.0 MB | CI bundle-size gate |
| Cold-start regression | <30 ms p95 | Sentry perf |
| Cost per user | $0.00 | no infra |

## 6. Open Questions / Risks

- **App size:** 7 fonts × ~500 KB = 3.5 MB. We are under budget but tight; ship Regular + Bold only for non-default fonts.
- **Per-platform availability:** SF Pro on iOS, Roboto on Android — already handled via `Platform.isIOS` fallback chain. Document.
- **Code blocks already use a monospace font** — must not be overridden by JetBrains Mono *globally* in a way that breaks existing `code` style. Decision: code blocks use `JetBrainsMono` regardless; user choice only changes prose font. JetBrains Mono is bundled and used in both surfaces.
- **Subset coverage:** OpenDyslexic ships only Latin + Latin Extended. Show a banner if user's locale is non-Latin and selected font lacks coverage. Fallback chain catches the rest.

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord (desktop) | 4 fonts, mobile = none | Mobile-first parity + a11y options |
| Slack | None | Pure parity gain |
| Telegram | iOS only, system fonts | Cross-platform consistent set |
| Notion | Sans / Serif / Mono | Same idea, smaller surface |

## 8. Rollout

- Internal dogfood (12 staff) → 1% beta cohort → 10% → GA.
- Kill switch flag: `feature.custom_fonts_basic.enabled`.
- Default OFF; rollout gated by `flicko_feature_flags`.
- App-bundle size enforced in CI before tag.

## 9. Dependencies

- `user_settings` table (already shipped, extended in migration `128`).
- `themeDataProvider` in `mobile/lib/core/theme/theme_provider.dart`.
- Settings handler `backend/internal/handlers/user_settings_handler.go`.
- Existing `appearance_settings_screen.dart` for the entry row.
