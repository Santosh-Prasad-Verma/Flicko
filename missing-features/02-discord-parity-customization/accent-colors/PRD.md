# Accent Colors — Product Requirements

> **One-line:** Let users pick a personal accent color that tints their UI surfaces app-wide.
> **Status:** Missing — to build
> **Category:** 02-discord-parity-customization
> **Effort:** S
> **Priority:** P1

## 1. Problem

Discord shipped Profile Themes (paid Nitro) and Accent Color (free) in 2020. Members who join Flicko from Discord routinely ask "where do I change my color?" Our only personalization today is the four base themes (`dark`, `light`, `amoled`, `plus`) selected in `mobile/lib/features/settings/presentation/appearance_settings_screen.dart`. Mentions, role pills, the FAB, and the active-tab bar all use a single brand purple, so the entire app reads as identical for every user.

Evidence:
- 41 Discord posts referenced in onboarding-survey free text (Q1 2026, n=312) ask for "my own color".
- Support tickets tagged `appearance` are 18% of all volume; "color" is the most-frequent noun.
- Internal dogfood: 9/12 testers manually changed their Material You wallpaper hoping it would tint Flicko.

The fix is small, has zero infra cost, and removes a parity-gap objection that comes up in nearly every Reddit comparison thread.

## 2. Users & Use Cases

- **Primary persona:** Maya, 22, design student. Has a coordinated palette across her phone wallpaper, Spotify, and Notion. Wants Flicko to fit.
- **Secondary personas:** server staff who want their @mention to stand out from `@everyone` pings; ND users who use color as a memory aid for which app they're in.

Top 3 jobs-to-be-done:
1. As a user, I want to pick one accent color, so that mentions and CTAs match my taste.
2. As a moderator, I want my replies to be visually distinct in long threads, so that members can scan for staff answers.
3. As a colorblind user, I want a curated palette tested for contrast, so that I'm not stuck with a default that fails AA.

## 3. Goals & Non-Goals

**Goals**
- Single accent value persisted per user, applied to: mention chips, send button, primary CTA, focused input border, active-tab indicator, FAB, slider thumb.
- Curated palette of 16 colors (8 vivid + 8 muted), all WCAG AA against both dark and light surfaces.
- Custom hex input gated behind Flicko Plus (already a SKU); free tier sees the 16 swatches only.
- Live preview before save.

**Non-Goals (out of scope for v1)**
- Per-server accent override (covered later by 09-customization).
- Gradient or animated accents (Plus-tier later).
- Color extraction from avatar (revisit after Material You rolls out everywhere).
- Theming the chat background, sidebar, or message bubbles — accent is a tint, not a repaint.

## 4. Scope (v1)

- [x] Add `accent_color` column to `user_settings` (hex string, default `#7C5CFF`).
- [x] `GET/PATCH /api/v1/users/me/settings` already exists; extend payload with `accent_color`.
- [x] Flutter: `AccentColorNotifier` provider reads from settings, exposes `Color` to `ThemeData`.
- [x] New screen: `AccentColorScreen` linked from `appearance_settings_screen.dart`.
- [x] 16 swatch grid + custom-hex sheet (Plus only).
- [x] Live-preview banner showing a fake mention + CTA.
- [x] Persist locally first (optimistic), sync to backend, reconcile on conflict.

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Adoption (% DAU who set non-default) | 35% within 30d | PostHog event `accent_color.changed` |
| Retention | +1.5 pp W4 vs control | A/B holdout, 5% |
| Quality (contrast violations) | 0 | automated `flutter_a11y` test in CI |
| Custom-hex Plus conversion | 4% of Plus trials cite this in exit survey | post-cancel form |
| Cost per user | $0.00 | no new infra |
| Settings sync error rate | <0.1% | Sentry breadcrumb |

## 6. Open Questions / Risks

- Does Material You override our accent on Android 12+? Decision: our accent wins inside Flicko surfaces; system-tinted notification icons keep dynamic color.
- iOS dynamic-type at 320% — does the focused-border 2px hairline still show? QA on iPhone SE first gen.
- Will server admins ask to *force* a server accent? Documented as 09-customization scope; reject for v1.

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord | 1 free accent + Nitro profile theme | Discord's accent only tints the *profile card*; ours tints functional UI |
| Slack | None at user level | Pure parity win |
| Telegram | Per-chat wallpapers, no accent | We do accent now, channel backgrounds in sibling spec |
| Revolt | Full custom CSS | They're niche; we ship guard-railed v1 then iterate |

## 8. Rollout

- Internal dogfood (12 staff) → 1% beta cohort → 10% → GA.
- Kill switch flag: `feature.accent_colors.enabled` (Doppler).
- Default OFF; rollout gated by `flicko_feature_flags` row, read at app boot.
- If disabled mid-session, app continues to use whatever color is cached locally; no crash path.

## 9. Dependencies

- `user_settings` table (already shipped, migration `040_user_settings.up.sql`).
- Settings handler `backend/internal/handlers/user_settings_handler.go`.
- Flicko Plus entitlement check via `premium_handler.go` for custom hex.
- Existing `themeDataProvider` in `mobile/lib/core/theme/theme_provider.dart` will be wrapped, not replaced.
