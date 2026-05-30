# Dyslexia Font — Product Requirements

> **One-line:** Optional OpenDyslexic font + reader-friendly preset for chat and UI.
> **Status:** Missing — to build
> **Category:** 13-accessibility
> **Effort:** S
> **Priority:** P1
> **Slug:** `dyslexia-font`

## 1. Problem

10–15% of the population has some form of dyslexia. Studies (Rello et al. 2013, BDA 2022) show that fonts with weighted bottoms, larger inter-letter spacing, and disambiguated pairs (b/d, p/q) reduce reading errors and fatigue. Discord ships exactly one font option (Whitney/gg sans) and provides no per-user typography controls. The OS-level font replacement on Android is hit-or-miss because Discord overrides it.

OpenDyslexic (OFL-licensed) is the most-cited dyslexia-friendly font; Atkinson Hyperlegible (Braille Institute) is another. Flicko can ship both as opt-in options without paying any licensing fees.

The deeper problem is not the font alone — it is the surrounding "reader preset": line-height, letter-spacing, paragraph spacing, and emoji rendering all matter. We bundle the font with a thoughtful preset so it actually helps, rather than just looking different.

## 2. Users & Use Cases

- **Primary persona:** Sam, 22, dyslexic CS student, who reads slowly in default sans-serif fonts and currently uses a custom userscript to swap fonts on chat apps.
- **Secondary personas:**
  - Users with mild visual stress / Irlen syndrome
  - ESL readers who benefit from the disambiguated letterforms
  - Older users who prefer wider tracking
- **Top jobs-to-be-done:**
  1. As a dyslexic user, I want to switch Flicko's UI and chat to a dyslexia-friendly font, so that I can read messages with less fatigue.
  2. As a power user, I want to fine-tune line height and letter spacing, so that I can dial in my preferred reading comfort.
  3. As a server admin, I want to know my server's "About" markdown is preserved when readers turn on the preset, so that my decoration intent isn't lost.

## 3. Goals & Non-Goals

**Goals**
- Bundle OpenDyslexic 3 (regular + bold) and Atkinson Hyperlegible (regular + bold) under their original licences.
- Add a "Reader font" preset toggle that swaps the app's default font and applies a reader-friendly line height and letter spacing.
- Apply consistently to chat messages, channel headers, member list, settings — but NOT code blocks (kept monospaced).
- Persist preference per-user; sync across devices.

**Non-Goals (out of scope for v1)**
- Custom user-uploaded fonts (governance + safety scope)
- Per-channel font overrides
- Reading rulers / coloured overlays (separate feature in pipeline)
- Modifying user-rendered emoji or images

## 4. Scope (v1)

- [ ] Bundle OpenDyslexic and Atkinson Hyperlegible with OFL licence files
- [ ] Settings → Accessibility → "Reader font" page
- [ ] Three options: System default / OpenDyslexic / Atkinson Hyperlegible
- [ ] Optional sliders: line height (1.2 – 2.0), letter spacing (0 – 0.08em)
- [ ] Live preview pane
- [ ] Preserve monospaced sections (code blocks) regardless of font choice
- [ ] Respect on-device parental locks (don't change font for users under 13 unless guardian opts in — no-op until parental controls ship)

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Adoption (% DAU using non-default font) | ≥4% within 60d | preference setting metric |
| Reading task completion (in-house user test) | +15% reading speed for self-identified dyslexic users | external study |
| Toggle off rate within 24h of opting in | <30% | preference change tracking |
| Settings page satisfaction | ≥4.4/5 | in-app survey |

## 6. Open Questions / Risks

- Some users feel patronised by being offered a "dyslexia font". Copy must be neutral: "Reader font".
- Performance: bundling two extra font families adds ~600 KB to APK; offset by tree-shaking unused weights.
- Font fallback: emoji and CJK glyphs won't be in OpenDyslexic; we must specify a graceful `fontFamilyFallback` chain.
- Custom server typography (a future feature) must not override user preference.

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord | None first-party | First-party reader font with sliders |
| Slack | Compact font density only | Two reader fonts + sliders |
| Microsoft Edge | Has reading mode font | We bring it to chat |
| Beeline / OpenDyslexic browser ext | Browser-only | Native cross-platform |

## 8. Rollout

- Internal dogfood with self-identified dyslexic engineers → 5% beta with neutral copy → GA.
- Kill switch flag: `feature.dyslexia_font.enabled` (default ON).
- Companion: "Reading comfort" tip card on first launch of Settings → Accessibility.
