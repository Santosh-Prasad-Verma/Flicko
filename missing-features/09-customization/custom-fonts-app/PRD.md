# Custom Fonts (App-Wide) — Product Requirements

> **One-line:** Pick any system or curated font; applies app-wide.
> **Status:** Missing — to build
> **Category:** 09-customization
> **Effort:** M
> **Priority:** P2

## 1. Problem

Discord ships one font (Whitney/gg sans) and refuses requests for alternatives. Users with dyslexia (OpenDyslexic), users on niche scripts (Noto serif), and users who just prefer their phone's system typeface have to live with the default. Slack only lets you bump font size. The market signal: the GitHub issue "let me change the font" on the Discord client repo (now closed) pulled 2.3k thumbs-ups, and Better-Discord's font plugins have ~600k cumulative downloads.

Flicko's wedge: a curated bundle of accessibility-grade fonts ships with the app, and on phones with system-font customizations (Samsung One UI, OnePlus, Nothing OS, Pixel) we honor those. v2 lets users upload `.ttf` / `.otf` / `.woff2` with sandboxed parsing.

## 2. Users & Use Cases

- **Primary persona:** "Dani" — has dyslexia; uses OpenDyslexic everywhere they can.
- **Secondary personas:** non-Latin script users; aesthetic users; low-vision users wanting larger x-height.
- **Top 3 jobs-to-be-done:**
  1. As a user with dyslexia, I want OpenDyslexic across all chat surfaces, so reading is easier.
  2. As a user, I want my phone's system font, so the app feels native.
  3. As a power user (v2), I want to load a font I own, so I can match my creative aesthetic.

## 3. Goals & Non-Goals

**Goals**
- v1 curated bundle: Inter (default), Roboto, Noto Sans/Serif, OpenDyslexic, Atkinson Hyperlegible, JetBrains Mono (chat).
- v1 system font option on Android (`useSystemFont`).
- Per-style override: chat body, headers, monospace.
- Reduced-motion-safe font swap (no flash of unstyled text).
- v2 sandboxed user upload (.ttf/.otf/.woff2) with parser limits.

**Non-Goals (out of scope for v1)**
- Variable-axes UI (weight/optical size sliders).
- Per-server forced font.
- Per-message font.
- Webfont CDN streaming (we ship binaries in-app).

## 4. Scope (v1)

- [ ] Asset bundle in `mobile/assets/fonts/` for the 7 curated fonts.
- [ ] Provider `font_choice_provider.dart` reading + persisting to backend `font_choices`.
- [ ] Settings screen: pick body font, header font, monospace font; preview.
- [ ] Honor `useSystemFont` flag on Android (resolve via `package_info_plus` + platform channel).
- [ ] Live re-render across all visible screens.

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Adoption (% DAU non-default font) | 9% within 30d | PostHog `font.changed` |
| Accessibility users | 35% of OpenDyslexic users retain 4w | cohort |
| Cold start regression | <20ms | client perf |
| Crash rate from font swap | 0 | Sentry |
| Cost per user | $0 | infra metrics |

## 6. Open Questions / Risks

- App APK size grows by ~3MB total with curated fonts. Acceptable; we strip unused glyphs at build.
- iOS doesn't expose system font picker easily; use SF Pro and Helvetica options.
- v2 user uploads need parser hardening: stick with `dart:typed_data` and reject unparseable headers.
- Support hot-swap without restart? Yes — Flutter `TextStyle(fontFamily: ...)` is reactive.

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord | Single font | Curated bundle + system font |
| Slack | Size-only | Full font choice |
| Element/Matrix | Some font choice | Better curation + dyslexia option |
| Telegram | One built-in choice | Wider bundle |

## 8. Rollout

- Internal dogfood → 10% beta → GA.
- Flag: `feature.custom_fonts.enabled`.
- v2 upload behind separate `feature.custom_fonts.user_upload.enabled`.
