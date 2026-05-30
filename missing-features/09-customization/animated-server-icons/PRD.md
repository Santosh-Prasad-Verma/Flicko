# Animated Server Icons — Product Requirements

> **One-line:** Animated GIF or Lottie server icons, free for everyone.
> **Status:** Missing — to build
> **Category:** 09-customization
> **Effort:** M
> **Priority:** P1

## 1. Problem

Discord locks animated server icons behind a Server Boost paywall (level 1 gives animated icon, requires 2 boosts). Slack, Teams: not supported at all. Animated icons are a low-effort, high-personality customization that the community signal-loves: forum threads consistently ask for it free, and Boost-tier-2 cancellations frequently cite "I just wanted the animated icon".

Flicko's wedge: ship it free for every server with sane file caps (≤512KB), supporting both GIF and Lottie. Lottie is preferred for crisp scaling and tiny payloads (most icons fit in 20-80KB).

## 2. Users & Use Cases

- **Primary persona:** "Ramon" — runs a 2k-member gaming server, made a logo in After Effects with a wave animation. Wants it as the icon.
- **Secondary personas:** small communities expressing brand; meme servers.
- **Top 3 jobs-to-be-done:**
  1. As a server owner, I want to upload an animated icon, so that my server feels alive in the sidebar.
  2. As a member, I want the icon to animate without draining battery, so I'm not annoyed.
  3. As a moderator, I want to revert if a member uploads a flashing/seizure-inducing icon, so members are safe.

## 3. Goals & Non-Goals

**Goals**
- Upload .gif or .json (Lottie); validation and size cap enforced.
- Animate in sidebar at 60fps (Lottie), 24fps (GIF), with respect for `reduced-motion`.
- Free for every server.
- Battery-aware: pause animation when device is in low-power or off-screen.
- Moderation: photosensitive flash detection (rough heuristic) at upload.

**Non-Goals (out of scope for v1)**
- Animated user avatars (separate feature).
- WebM/MP4 icons.
- Per-channel animated icons.
- Icon transitions (e.g., Christmas → New Year auto-swap).

## 4. Scope (v1)

- [ ] Upload flow: pick .gif or .json, validate, store in Appwrite.
- [ ] Server icon record points to either a static fallback or an animated source.
- [ ] Sidebar widget renders Lottie via `lottie` package, GIF via `Image.network` with cached frames.
- [ ] Settings flag per device: "Animate server icons" (default on; off when reduced motion).
- [ ] Photosensitive content check on upload (frame delta heuristic for GIF; flash count for Lottie keyframes).
- [ ] Static fallback (.webp) is auto-derived from the first frame so old clients still work.

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Adoption (% servers with animated icon) | 12% within 30d | DB count `server_animated_icons.enabled=true` |
| Sidebar p99 frame budget | <16ms | client perf metric |
| Upload reject rate | <8% | upload events |
| Battery delta on low-power | <2% extra | device profiling |
| Cost per server (storage) | <$0.001/mo | infra metrics |

## 6. Open Questions / Risks

- Lottie supports expressions (JS-like). Do we strip them at upload? Yes — `lottie-validator` whitelists nodes; expressions rejected.
- GIF can be 50MB+ technically. Cap is 512KB after server-side recompression.
- Should animated kick in only on hover (web) and on visible (mobile)? Yes, both.
- Auto-pause on battery saver? Yes (handled by `animated_icon_provider.dart`).

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord | Boost-locked GIF | Free + Lottie support |
| Slack | Static only | Animated |
| Telegram | Animated channel logos via Lottie (Tgs) | Same idea, in chat-app context |
| WhatsApp | Static only | Animated |

## 8. Rollout

- Internal dogfood with 20 hand-picked Lottie icons → 10% beta → GA.
- Flag: `feature.animated_icons.enabled`.
- Photosensitive heuristic gates approval; admin can override on appeal.
