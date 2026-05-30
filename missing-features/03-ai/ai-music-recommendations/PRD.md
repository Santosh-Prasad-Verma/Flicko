# AI Music Recommendations — PRD

> **One-line:** Vibe-aware music suggestions inside music-party using user taste vectors and an LLM picker.
> **Effort:** M · **Priority:** P2

## Problem
Music-party queues run dry. Users defer to whoever talks loudest about songs. AI fills queues with songs matching the room's recent listening patterns and stated mood.

## Users
- Music-party hosts and members in voice channels.

JTBDs:
1. Auto-fill queue when it dips below 3.
2. "Make it more chill" / "more hype" prompts.
3. Personal recs in DM/profile after a session.

## Goals
- Recs blend room + personal taste vectors.
- LLM picks specific tracks within Spotify catalog.
- Auto-queue threshold configurable.

## Scope
- [ ] Taste vectors per user
- [ ] Room context vector
- [ ] Auto-queue worker
- [ ] Mood prompt support
- [ ] Post-session "you might like" digest

## Metrics
- 70% of auto-queued tracks accepted (no skip within 30s).
- DAU using auto-queue ≥40%.
- Session length uplift +10%.

## Risks
- Echo chamber / boring picks. Mitigation: ε-greedy exploration.
- Provider catalog drift. Mitigation: graceful skip.

## Competitive
| Product | Take | Gap |
|---------|------|-----|
| Spotify Daily Mix | personal | shared room vibe |
| YouTube Music | personal | shared |
| Discord music bots | random/queries | AI vibe-aware |
