# Esports Integration — PRD

> **One-line:** Live esports scores, schedules, and event feeds embedded in dedicated channels powered by PandaScore (free 1k req/mo).
> **Effort:** M
> **Priority:** P2

## Problem
Esports communities follow scores via external sites/Discord bots. Native integration keeps the conversation in-server with rich live cards.

## Users
- Esports community admins.
- Fans who follow specific teams/games.

JTBDs:
1. Pin a live match card to a channel.
2. Subscribe to a team's matches; auto-post when live.
3. Get a weekly schedule digest.

## Goals
- 6 games at launch: LoL, CS, Dota2, Valorant, R6, Overwatch.
- Live score updates within 60s of provider.
- Match cards link to streams.

## Scope
- [ ] PandaScore poller
- [ ] Match card message embed
- [ ] Subscription per channel/team
- [ ] Schedule digest

## Metrics
- 30% of gaming-tagged servers add ≥1 subscription within 30d.
- <60s latency from PandaScore to channel.
- ≤900 calls/day to keep within free quota.

## Risks
- Free quota exhaustion → scrape fallback per league.
- Provider deprecates endpoint → adapter layer.

## Competitive
| Product | Take | Gap |
|---------|------|-----|
| Discord bot Liquipedia | Volunteer-run, brittle | Native, supported |
| Telegram score channels | Push only | Interactive |
