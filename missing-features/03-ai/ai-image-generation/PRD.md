# AI Image Generation — PRD

> **One-line:** `/imagine` slash command generates images via Stable Diffusion (Pollinations.ai free) and posts them in chat.
> **Effort:** M · **Priority:** P1

## Problem
Communities use Midjourney via Discord but pay-walled. A free, in-house image generation slash command keeps the fun in Flicko and removes paywalls.

## Users
- Casual users wanting in-chat images.
- Server admins running art channels.

JTBDs:
1. Type `/imagine cat astronaut` and get an image in chat.
2. Re-roll, upscale, or remix.
3. Set per-channel quality and style presets.

## Goals
- Free tier: 5 generations/day per user.
- Plus tier: 50/day.
- 4 aspect ratios; 4 style presets.
- ≤15s p50 generation.

Non-goals: Custom model training, NSFW (blocked).

## Scope
- [ ] `/imagine prompt:` slash command
- [ ] Re-roll, variations
- [ ] Style presets (anime, photo, paint, line)
- [ ] NSFW + face filter
- [ ] Server admin disable
- [ ] Quota dashboard

## Metrics
- Adoption: 10% of DAU use within 30d.
- Cost / image: $0 (Pollinations free).
- Refusal rate: <2%.

## Risks
- Pollinations rate-limit at scale. Mitigation: self-hosted SDXL fallback.
- NSFW abuse. Mitigation: classifier blocks; auto-strike on repeat.
- Copyright. Mitigation: prompt filter for celebs/IP.

## Competitive
| Product | Take | Gap |
|---------|------|-----|
| MidJourney via DC | Paid | Free, in-platform |
| ChatGPT/DALL-E | $20/mo | Free |
| Stable Horde | Volunteer | Reliable + native |
