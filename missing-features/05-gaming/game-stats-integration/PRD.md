# Game Stats Integration — PRD

> **One-line:** Connect Riot/Steam/Xbox/PSN/BattleNet via OAuth and surface rank/K-D/playtime in profiles and server widgets.
> **Effort:** L
> **Priority:** P1

## Problem
Players proudly display ranks today via bots and screenshots. Native, OAuth-verified stats kill faking and reduce friction.

## Users
- Competitive players linking accounts.
- Friends comparing stats.
- Server admins running tournaments.

JTBDs:
1. Verify my Valorant rank shows on my profile.
2. Compare K/D with a friend.
3. Auto-assign role on rank threshold.

## Goals
- 5 providers v1 (Riot, Steam, Xbox, PSN, BattleNet).
- Stats refreshed at most every 6h, on-demand within rate limit.
- Privacy-respecting (member opt-in per server display).

## Scope
- [ ] OAuth flows for each provider
- [ ] Stats fetcher worker
- [ ] Profile widgets per game
- [ ] Server-side role auto-grant on rank
- [ ] Disconnect / data wipe

## Metrics
- 30% of gaming-server members link ≥1 account in 30d.
- Stats fetch p99 <2s.
- 0% account hijack incidents.

## Risks
- Rate limit per provider. Mitigation: Redis token-bucket.
- Provider TOS shifts. Mitigation: per-provider adapter, kill-switch.
- Privacy. Mitigation: opt-in, hide values per-server.

## Competitive
| Product | Take | Gap |
|---------|------|-----|
| op.gg | LoL only | Multi-game |
| Tracker.gg | Web | In-app native |
