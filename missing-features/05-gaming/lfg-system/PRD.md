# LFG System — Product Requirements

> **One-line:** Looking-for-group boards per game with rank/region/mic/mode filters and one-tap voice channel auto-fill.
> **Status:** Missing — to build
> **Category:** 05-gaming
> **Effort:** L
> **Priority:** P0

## 1. Problem

Discord has no native LFG. Gamers spam `#lfg` text channels, copy-paste posts to r/Valorant_LFG, or use third-party tools (LFGM, GamerLink). Posts go stale in seconds, no structured filters, and finding a Diamond support main in NA-East with mic at 11pm is friction-heavy.

Flicko's audience is Discord's gaming refugees. The 2025 r/discordapp poll showed 71% of gaming-server admins manually delete >50 stale LFG posts/day. Forum threads on r/VALORANT and r/Apex regularly ask "is there a Discord with real LFG matchmaking?". This is the core differentiator.

## 2. Users & Use Cases

- **Primary persona:** Competitive ranked-grinder, 16-26, plays Valorant/LoL/Apex/CS2 nightly, on Discord 4+ hours/day.
- **Secondary personas:** Casual party-game host (Among Us, Fortnite squads), MMO raid leader (FFXIV, WoW), tournament organizer.
- **Top 3 jobs-to-be-done:**
  1. As a ranked player, I want to post a slot for my missing role so I can fill within 5 minutes.
  2. As a server mod, I want stale posts to auto-archive so the board stays useful.
  3. As a returning player, I want to filter by my rank tier so I don't get flamed for being silver.

## 3. Goals & Non-Goals

**Goals**
- One-tap "Looking for X" post creation per game with structured fields (rank, region, mode, mic-required, slots).
- Filterable board feed with realtime updates via Centrifugo.
- Auto-create voice channel on accept; auto-fill once slots full; auto-delete on idle 5min.
- Per-game schema (Valorant uses agents+rank, MMO uses class+ilvl).
- Cross-server discovery (opt-in) to surface posts beyond a single server.

**Non-Goals (out of scope for v1)**
- Skill-rating engine beyond per-game rank field.
- Anti-toxicity scoring (handled by ai-moderation feature).
- Tournament brackets (separate spec).
- In-game integrations beyond rank fetch from game-stats-integration.

## 4. Scope (v1)

- [x] LFG post CRUD with per-game JSON-Schema validated payloads
- [x] Board UI with chips for rank/region/mode/mic
- [x] Realtime feed via Centrifugo channel `lfg:server:<id>`
- [x] Voice-channel auto-fill workflow (post slot → user accepts → joined)
- [x] Auto-archive cron (>30min idle, >2h old, full)
- [x] Cross-server discovery (server opts in to public hub)
- [x] Game catalog seed: Valorant, LoL, CS2, Apex, Fortnite, Overwatch 2, Rocket League, FFXIV, WoW, Destiny 2

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Posts created per gaming-server DAU | >0.4/day | PostHog `lfg_post_created` |
| Time-to-fill (median) | <4 min | timer from post→full |
| Match success (joined voice >5min) | >65% | session duration |
| Stale-post rate | <5% (auto-archived before fill) | cron stats |
| Cross-server fills | >15% of total | source flag |

## 6. Open Questions / Risks

- Rank-faking mitigation: link via game-stats-integration when available, badge confirmed accounts.
- Cross-server abuse: rate-limit post creation to 3/hr per user per game.
- Region detection: IP-based with manual override; PII handling per GDPR.
- Voice-channel sprawl: hard cap at 50 active LFG channels per server.

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord | Plain text channel only | No structured filters, no realtime updates |
| LFGM (3rd party Discord bot) | `/lfg` slash with limited fields | Bot rate limits, no native UI, no auto-voice |
| GamerLink (mobile app) | Standalone app with LFG focus | No chat persistence, separate identity |
| r/VALORANT_LFG | Reddit thread per region | No realtime, post-stale within minutes |
| Riot Pre-Made (in-game) | Shows party slots in client | Only after launching game; no cross-friend |

## 8. Rollout

- Internal dogfood (Flicko gaming server, 30 users) → 1% beta on 10 partner gaming servers → 10% → GA.
- Kill switch flag: `feature.lfg.enabled` (Doppler).
- Feature flag also at server-level: server admins must enable LFG to expose the board.
- Beta success criteria: median time-to-fill <6min, no P1 abuse incidents in 14 days.
