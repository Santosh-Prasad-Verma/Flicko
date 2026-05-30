# Reduced Motion Mode — Product Requirements

> **One-line:** Honor system reduce-motion pref + manual toggle; replace transitions with crossfades.
> **Status:** Missing — to build
> **Category:** 13-accessibility
> **Effort:** M
> **Priority:** P0
> **Slug:** `reduced-motion-mode`

## 1. Problem

WCAG 2.1 SC 2.3.3 (Animation from Interactions) and 2.2.2 (Pause, Stop, Hide) require that motion-induced disorientation be avoidable. Users with vestibular disorders, migraines, or motion sickness can experience nausea from parallax scrolling, large movement, and rapid transitions. Discord ignores the OS-level "Reduce Motion" pref entirely. Flicko currently does too — every page transition is a 300ms shared-axis slide, message reactions bounce, server boost ribbons sparkle, and the typing indicator dots wobble.

We must (a) detect `MediaQuery.of(context).disableAnimations`, (b) provide a manual override (so users can opt in even if the OS doesn't), and (c) replace movement-based transitions with crossfades or instant changes while preserving feedback (a snackbar still appears, just without sliding from the bottom).

## 2. Users & Use Cases

- **Primary persona:** Priya, vestibular migraine sufferer, has "Reduce Motion" on at the OS level and currently avoids using Discord.
- **Secondary personas:**
  - Users with concussion recovery
  - Pregnant users with sensitivity to motion
  - Battery-conscious users (less animation = less GPU)
  - Designers QA-ing motion behaviors
- **Top jobs-to-be-done:**
  1. As a user with a vestibular disorder, I want Flicko to honor my system "Reduce Motion" setting, so that I can use it without nausea.
  2. As a user without that system pref, I want a manual toggle, so that I can opt in voluntarily.
  3. As an admin, I want the welcome animation on first server-join to be skippable, so that I respect motion sensitivities of my members.

## 3. Goals & Non-Goals

**Goals**
- Auto-detect `MediaQuery.disableAnimations` and propagate via `MotionPolicyProvider`.
- Manual override toggle in Settings → Accessibility → Reduced motion.
- Replace slide/scale/parallax with 0–150ms cross-fade or instant.
- Disable decorative loops (sparkles, confetti, "wobble").
- Keep essential feedback (snackbar, toast still appear; just static).
- Document a `MotionPolicy` API for any future feature to consume.

**Non-Goals (out of scope for v1)**
- Removing user-uploaded animated GIFs/stickers (that's a separate "auto-pause GIFs" preference covered elsewhere).
- Audio reduction (separate feature).
- Removing all hover effects on web (small scale OK; we cap at 1.02× and ≤80ms).

## 4. Scope (v1)

- [ ] `MotionPolicyProvider` with `MotionLevel { full, reduced, instant }`
- [ ] Audit and replace all custom `AnimatedContainer`, `Hero`, `PageRouteBuilder` with motion-aware variants
- [ ] Settings page: Off / Auto (system) / On (force)
- [ ] Custom welcome animation on first server-join becomes a static checkmark when reduced motion active
- [ ] Auto-play/loop GIF stickers respect the policy (pause by default in reduced mode)
- [ ] Documented `MotionAware` mixin/widget for new code

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Adoption (users with reduced motion either via OS or manual toggle) | ≥4% of DAU | preference setting metric |
| Self-reported "Flicko makes me dizzy" survey responses | drop ≥80% within 60d | quarterly survey |
| Frame-time p95 in reduced mode | <8 ms (vs. ≤16 ms full) | client telemetry |
| Battery delta in reduced mode | -3% | benchmark |
| GIF auto-pause adoption | ≥80% of reduced-mode users | telemetry |

## 6. Open Questions / Risks

- Some animations carry meaning (e.g. a message bubble jumping into view to highlight a mention); replacing with crossfade may lose the cue. We pair the crossfade with a temporary outline ring instead.
- The "first message tap" tutorial relies on a pulsing arrow; we need a static "Tap here" tooltip alternative.
- Marketing wants the boost-celebration animation. We replace with a static badge in reduced mode.
- Tests: ensure no regression in animation timing tests when policy is `full`.

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord | Ignores system pref | Honour `disableAnimations` automatically |
| Slack | Honours OS pref but lacks manual override | Offer manual override + per-app setting |
| iMessage | Native OS reduce-motion | Cross-platform parity |

## 8. Rollout

- Internal dogfood (especially designers) → 5% beta → GA.
- Kill switch flag: `feature.reduced_motion_mode.enabled` (default ON).
