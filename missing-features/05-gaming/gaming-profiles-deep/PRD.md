# Gaming Profiles Deep — PRD

> **One-line:** Rich gaming profile with linked accounts, recent games, achievements, clips, and shareable friend codes.
> **Effort:** M
> **Priority:** P1

## Problem
Default Flicko profile has no gaming context. Players paste Steam/PSN IDs in their bio and switch apps to verify. A native gaming-profile section is the connective tissue between game-stats, achievements, clips, and friend systems.

## Users
- Players, esports rosters, content creators.

JTBDs:
1. Show off ranks, recent matches, and achievements at a glance.
2. Get a single shareable URL for my gaming identity.
3. Find friends to play with via friend codes.

## Goals
- Tab on profile aggregating all gaming features.
- Public URL `flicko.app/@user/gaming` (with privacy toggle).
- Shareable card export (PNG).

## Scope
- [ ] Stats summary
- [ ] Achievements shelf
- [ ] Recent games (auto from Steam/Riot/etc.)
- [ ] Clip highlights
- [ ] Friend codes grid
- [ ] Privacy controls

## Metrics
- 50% of stats-linked users complete the gaming profile.
- Public-profile traffic uplift (acq metric).

## Risks
- Profile becomes cluttered. Mitigation: opt-in per section.
- Friend-code abuse. Mitigation: verify ownership where possible.

## Competitive
| Product | Take | Gap |
|---------|------|-----|
| Steam profile | Steam-only | Multi-provider |
| Discord About | Static | Dynamic |
