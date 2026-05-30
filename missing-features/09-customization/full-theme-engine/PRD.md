# Full Theme Engine — Product Requirements

> **One-line:** Community-made themes via sandboxed JSON tokens, free for everyone.
> **Status:** Missing — to build
> **Category:** 09-customization
> **Effort:** XL
> **Priority:** P1

## 1. Problem

Discord locks rich theming behind Nitro and BetterDiscord plugins are a security nightmare (arbitrary JS/CSS, account bans). Slack only allows sidebar tints. Power users want deep visual customization without leaving their account vulnerable to credential-stealing themes or having to compile a fork. Forum threads `r/discordapp` and BetterDiscord issue tracker show roughly 14k upvotes across the top 5 "let me theme my client" requests in the last 18 months. Server admins also want a server-default look that newcomers see on join — currently impossible without third-party clients.

Flicko's wedge: a token-only theme engine. Users edit a structured JSON spec (colors, radii, spacing, motion) — no CSS, no JS, no script tags. The renderer maps tokens to Material 3 ColorScheme + custom extensions at runtime. The marketplace is curated and the schema is enforced server-side; a malicious theme can do exactly nothing dangerous because it has no execution surface.

## 2. Users & Use Cases

- **Primary persona:** "Mira" — 23, design-conscious power user with 4 themed phones, runs an aesthetic-focused server. Wants a Tokyo-night palette across all surfaces.
- **Secondary personas:** Server owners branding their community; accessibility users needing high-contrast variants; community theme creators farming reputation.
- **Top 3 jobs-to-be-done:**
  1. As a user, I want to apply a community theme in two taps, so that my Flicko looks the way I want without manual color picking.
  2. As a server owner, I want to set a default theme for my server, so that new members see the brand the moment they land.
  3. As a creator, I want to publish a theme to the store, so that other people can use my work and I get attribution.

## 3. Goals & Non-Goals

**Goals**
- Token-only spec covers ≥95% of visual surface (colors, radii, spacing, motion, typography weight scale).
- Apply/preview themes with zero app restart and <16ms layout reflow.
- Marketplace with vetting flag; bad themes get pulled in <60s.
- Free for all users — no Nitro tier, no per-theme paywall.
- Theme files are deterministic and diffable (canonical JSON, sorted keys).

**Non-Goals (out of scope for v1)**
- Arbitrary CSS injection.
- Custom shaders, particle effects, animated backgrounds.
- Per-channel themes (server-wide only).
- Theme inheritance / mixins (flat spec only).
- Earning real money from themes (creators get clout, not cash, in v1).

## 4. Scope (v1)

- [ ] Token spec v1: 64 color tokens, 8 radius tokens, 8 spacing tokens, 6 motion tokens, 5 type-weight tokens.
- [ ] Theme renderer in `mobile/lib/core/theme/theme_engine.dart` extending `ThemeData`.
- [ ] Server-side validation: JSON Schema + colorimetric checks (contrast ratios, no pure-magenta-on-magenta).
- [ ] Marketplace screen: search, browse, preview, install.
- [ ] Per-user override: pick any theme, applies app-wide.
- [ ] Per-server default: owner picks a server-bound theme; members see it inside that server (toggle to disable).
- [ ] Reporting flow: flag theme, admin queue, takedown in <60s.
- [ ] Curator badge for vetted themes.

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Adoption (% DAU using non-default theme) | 18% within 30d | PostHog `theme.applied` event |
| Marketplace listings | 500 within 60d | DB count of `themes.status='published'` |
| Time-to-apply | <800ms p95 | Client metric `theme.apply.duration` |
| Bad-theme takedown SLA | <60s p99 | admin queue dashboard |
| Cost per user | $0 | infra metrics |

## 6. Open Questions / Risks

- How do we resolve a server-default vs user-override collision? Default rule v1: user override wins everywhere except in a server that explicitly enforces its theme (server setting `force_theme=true`, opt-in). Need legal sign-off on enforcement.
- Do we expose dark/light pair under a single theme id, or as two listings? Plan: pair (one id, two slots).
- Color-blind variants: auto-generate or hand-author? v1 hand-author; v2 auto.
- Marketplace ranking algorithm — start with installs+freshness, defer ML to v2.

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord | Nitro-only color profiles, sidebar tint | Free, deeper, marketplace |
| Slack | Sidebar 8 tints | Token-only full theme |
| BetterDiscord | Arbitrary CSS plugins | Sandboxed, safe by construction |
| Telegram | Theme files, decent marketplace | Token-richer + per-server overlay |

## 8. Rollout

- Internal dogfood (10 themes hand-authored) → 1% beta → 10% → GA.
- Kill switch flag: `feature.full_theme_engine.enabled`.
- Marketplace gated separately by `feature.theme_marketplace.enabled` so we can ship the engine first.
