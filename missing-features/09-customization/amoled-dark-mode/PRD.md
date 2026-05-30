# AMOLED Dark Mode — Product Requirements

> **One-line:** True-black (#000000) dark mode preset for OLED battery savings.
> **Status:** Missing — to build
> **Category:** 09-customization
> **Effort:** S
> **Priority:** P1

## 1. Problem

Standard "dark mode" uses dark grays (#1A1B1F or #121212) which still light pixels on OLED panels. On phones with OLED screens (most flagships since 2018) a true-black UI saves ~30% display power and yields visibly deeper contrast. Discord's "Midnight" ships only on Nitro and most other apps don't bother. Users with sensitive eyes or in low-light bedtime use also explicitly want pure black.

Search of `r/discordapp` shows the top Nitro complaint thread on this hits 8.4k upvotes; "give us amoled" comes up in feedback consistently. We can give it for free because it's just one preset on the theme engine.

## 2. Users & Use Cases

- **Primary persona:** "Theo" — uses Pixel 8 Pro at night in bed, wants OLED-friendly dark.
- **Secondary personas:** users with light-sensitivity / migraines; battery-conscious users; aesthetic users who prefer the bezel-blends-into-screen look.
- **Top 3 jobs-to-be-done:**
  1. As a user, I want to switch to AMOLED dark in one tap, so my screen draws less power at night.
  2. As a user, I want AMOLED to follow my system dark/light schedule, so it activates automatically.
  3. As a server owner, I want AMOLED to be a single tap from the appearance menu, so I can recommend it to my members.

## 3. Goals & Non-Goals

**Goals**
- Pure-black surface (#000000) and surface variants ≤#0A0A0A.
- Text and dividers calibrated for AA contrast on black.
- One-tap toggle in Appearance.
- Auto-activate option tied to system dark and to a "after sunset" schedule.
- Honor reduced-motion: no flashing transitions.

**Non-Goals (out of scope for v1)**
- Custom AMOLED palette per accent color (use full theme engine for that).
- Per-server AMOLED override.
- AMOLED "splash screens" (not customizable yet).

## 4. Scope (v1)

- [ ] Built-in AMOLED ThemeSpec (no marketplace listing — compiled into app).
- [ ] Settings toggle "Use AMOLED black".
- [ ] Schedule: "Always" / "When system is dark" / "After sunset (location)".
- [ ] Battery-saver auto-prompt: when device enters battery saver, show "Switch to AMOLED?" snackbar once.
- [ ] Rendering audit: ensure all surfaces use tokens (no hardcoded gray).

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Adoption (% DAU on AMOLED) | 25% within 30d | PostHog `amoled.enabled` |
| Battery saver suggestion accept rate | 40% | event funnel |
| Contrast violations | 0 | automated lint |
| Time-to-toggle | <300ms | client metric |
| Cost per user | $0 | infra metrics |

## 6. Open Questions / Risks

- Pure black on some LCD panels can crush blacks unpleasantly; do we detect and warn? Plan: detect via `MediaQuery.platformBrightness` is insufficient; rely on a Settings hint instead.
- Sunset location requires `location.coarse` permission — gate behind explicit consent.
- Should AMOLED also mute accent saturation (some accents like neon green burn on black)? v1: no, but we cap saturation in the AMOLED preset itself.

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord | "Midnight" Nitro-only | Free everywhere |
| Slack | No AMOLED | First-class toggle |
| Telegram | AMOLED via theme files | Built-in one-tap |
| WhatsApp | Pure black system option | Independent of OS |

## 8. Rollout

- Internal dogfood → 10% beta → GA.
- Kill switch: `feature.amoled.enabled`.
- Depends on `full-theme-engine` shipping first.
