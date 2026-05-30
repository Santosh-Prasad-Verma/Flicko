# RTL Support — Product Requirements

> **One-line:** First-class right-to-left layouts for Arabic, Hebrew, Persian, Urdu speakers.
> **Status:** Missing — to build
> **Category:** 14-localization
> **Effort:** M
> **Priority:** P0
> **Slug:** `rtl-support`

## 1. Problem

About 600M people read in right-to-left scripts (Arabic, Hebrew, Persian, Urdu, plus N'Ko, Dhivehi, etc.). When `multi-language-50` ships translations for `ar`, `he`, `fa`, `ur`, the *strings* will look right but the *layout* will still be left-to-right — meaning every UI affordance (back arrow, drawer hamburger, swipe-to-reply, text alignment, list dividers, even the unread-badge position) will feel alien. Discord shipped Arabic in 2022 and immediately got 200+ angry forum threads because layout was not mirrored. We will not repeat that mistake.

Real evidence:
- 6 GitHub issues already filed asking specifically for "RTL", "Arabic mirroring", "support for Persian".
- Plausible shows a 9% click-through rate on any flag emoji from MENA visitors — suggesting strong interest if we ship.
- Voice channels in particular need icon mirroring (mute, push-to-talk, leave) — these communicate state nonverbally.

We need full RTL: layout direction flip, icon mirroring (only directional ones — never globes, lock icons, or play arrows for *audio*; play does flip for *video timelines*), bidi-aware text, and number/date formatting that respects user expectations (Arabic users often prefer Western digits; Persian users typically prefer native digits).

## 2. Users & Use Cases

- **Primary persona:** "Mohammed in Cairo" — Arabic-first, expects every screen to feel native.
- **Secondary personas:** Hebrew speakers (Israel), Persian speakers (Iran/diaspora), Urdu speakers (Pakistan/India). Also LTR users on a single message that contains a quoted RTL string (bidi correctness).
- **Top jobs-to-be-done:**
  1. As an Arabic user, I want the whole app mirrored, so that the back arrow points right and tabs read right-to-left.
  2. As a user reading mixed text (English + Arabic in one message), I want correct bidi resolution, so that punctuation lands in the right place.
  3. As a developer, I want a single `Directionality` flip + lint rules to catch hardcoded `EdgeInsetsDirectional`, so that RTL doesn't regress.

## 3. Goals & Non-Goals

**Goals**
- Whole-app mirroring when locale is RTL — `Directionality(textDirection: TextDirection.rtl)` at root.
- Icon mirroring for the curated list of "directional" icons (back, forward, chevron, send, reply-arrow, undo/redo).
- Bidi-correct text rendering: numbers, punctuation, mixed strings handled by Flutter's built-in bidi engine + targeted overrides.
- All custom widgets (badges, drawer slide-in, swipe gestures) respect `TextDirection.of(context)`.
- Lint rule + golden tests prevent regressions.
- Per-message text-direction override (auto-detect via first strong character).

**Non-Goals (out of scope for v1)**
- Per-channel RTL toggle — direction follows user locale, not server config.
- RTL for code blocks — code is always LTR by convention.
- Bidirectional shaping for indic scripts — that is shaping, not RTL, handled by font.
- Native rendering on Windows/Linux desktop where Flutter's RTL is still rough.

## 4. Scope (v1)

- [ ] Root `Directionality` derived from `LocaleProvider`
- [ ] All `EdgeInsets` audited and replaced with `EdgeInsetsDirectional` where directional
- [ ] All `Alignment.centerLeft/Right` audited; replaced with `AlignmentDirectional.centerStart/End`
- [ ] `Icons.arrow_back` etc. swapped for `Icons.arrow_back_ios_new` *or* a `DirectionalIcon` wrapper that flips
- [ ] Custom drawer slides from the correct side
- [ ] Voice / Stage / Gaming hub controls mirrored
- [ ] Message swipe-to-reply: gesture flips
- [ ] Push-notification copy supports RTL
- [ ] Mail-gateway HTML templates: `dir="rtl"` attribute when locale is RTL
- [ ] Pseudo-RTL locale `xq-XR` for QA (mirror without translating)
- [ ] Lint: no raw `EdgeInsets.only(left:..., right:...)` in `lib/features/**`
- [ ] Golden tests: 5 critical screens × ar locale

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| RTL DAU | 10% within 60d | PostHog `locale.rtl=true` |
| RTL bug reports | <3/week post-GA | GitHub label `rtl` |
| Layout overflow on ar/he/fa/ur | 0 | golden test CI |
| Mirrored icons coverage | 100% directional icons | manual audit |
| Crash rate RTL vs LTR | within 0.1% | crashlytics |

## 6. Open Questions / Risks

- Numbers in Arabic: keep Western digits or use Arabic-Indic? Default = Western (matches WhatsApp); user override planned.
- Mixed-direction message bubbles: do we align the bubble by *thread direction* or by *message direction*? Recommend message direction for chat clarity.
- Some third-party widgets (a video player overlay) ignore Directionality. Mitigation: wrap in explicit `Directionality(textDirection: TextDirection.ltr)` for media controls.
- `flutter_svg` icons: many imported assets are not designed to mirror cleanly (e.g. logo with arabesque). We'll keep a do-not-mirror allowlist.
- Performance: Flutter's RTL has zero runtime cost — confirmed.

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord | RTL since 2022, but icons not mirrored consistently | Strict directional-icon audit |
| Slack | Solid RTL on web, mobile lags | Match the better experience |
| WhatsApp | Excellent RTL bidi | Reference implementation we model |
| Telegram | RTL with per-message dir detection | We adopt the same auto-detect |
| Element/Matrix | Decent RTL, some custom widgets miss | We avoid that pitfall |

## 8. Rollout

- Internal dogfood: force `ar` locale on 5 dev devices for 2 weeks.
- 1% beta with self-selected RTL users (recruit via r/learnArabic, Hebrew Reddit, etc.).
- 10% rollout among ar/he/fa/ur users.
- GA when zero P0/P1 RTL bugs in a 7-day window.
- Kill switch: `feature.rtl_support.enabled` (default ON once shipped); if off, RTL locales render LTR (still readable, just ugly).

## 9. Translator / Tester Notes

- We pre-flight every release with a `xq-XR` (pseudo-RTL) build that mirrors LTR English — surfaces layout-direction bugs without needing actual ar translations.
- Native QA recruited via Crowdin: we ask top 5 ar reviewers and top 3 he reviewers for a 30-min walkthrough each release.
- Include a "Report RTL bug" CTA in Settings → Language during the beta window — opens a prefilled GitHub issue with the screen route attached.
