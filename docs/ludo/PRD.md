# Ludo - Product Requirements Document

**Status:** Draft v1
**Owner:** Flicko Gaming
**Last updated:** 2026-05-29

## 1. Problem

Flicko's gaming hub needs a flagship social board game. Ludo is the most-played casual board game on Indian mobile (per Sensor Tower 2025), with low cognitive load, 4-player support out of the box, and natural 30-second turn cycles that fit voice/chat overlays.

## 2. Target users

- **Casual social gamers** (primary) - Flicko users who already gather in voice channels and want a turn-based game to play together while chatting.
- **Solo time-fillers** (secondary) - users opening the app for 5-10 minute sessions; need fast bot matches.
- **Competitive grinders** (tertiary) - want ranked ladders, ELO, and leaderboards.

## 3. Goals & non-goals

**In scope (v1):**
- 4 modes: Online Random, VS Computer, Pass & Play, Invite Friends
- Team mode (2v2) for online matches
- Real-time multiplayer over Centrifugo with authoritative dice/move on the backend
- Bot AI with one difficulty (heuristic: capture > finish > safe spot > furthest)
- ELO-based leaderboard, top 50, refreshed on demand
- Audio: 13 SFX + looping lobby music, mute toggle
- Animations: dice tumble (Lottie), token movement (200ms/cell), capture, fireworks, trophy
- Deep-link join via `/ludo/play?gameId=<id>`

**Out of scope (v1):**
- Daily missions / streaks / battle pass
- In-game chat and emote reactions (handled by Flicko's existing voice/text channels)
- Tournaments and brackets
- Custom board themes and dice skins
- Spectator mode
- Multi-difficulty bots (Easy/Medium/Hard)
- Replay system

## 4. Success metrics

| Metric | Target (90 days) |
|---|---|
| Daily Ludo openers / Daily gaming-hub openers | >= 35% |
| Median game duration | 8-12 min |
| Online-mode match completion rate | >= 70% |
| Bot-mode session length p50 | >= 6 min |
| Leaderboard view rate (users with 5+ games) | >= 50% |
| Crash-free sessions | >= 99.5% |

## 5. User stories

- As a Flicko user in a voice call, I tap **Play Online** > **Team Match (2v2)** and get auto-matched with my voice-channel members on the same team within 30 seconds.
- As a casual user, I open the app, tap **Vs Computer**, choose 3 bots, and start playing in under 5 seconds with no network round-trips.
- As a competitive user, I open the leaderboard, see I'm rank #42 with ELO 1612, and aim for the top 25.
- As a friend organizer, I tap **Invite Friends**, the app generates a shareable link, my 3 friends open it, and we drop straight into a board.

## 6. Constraints

- **Network:** must remain playable on 3G; budget per turn = 1 RTT for dice + 1 RTT for move.
- **Battery:** Lottie animations cap at 60fps for hero scenes (matchmaking, win), 30fps for in-game.
- **Storage:** all assets under 5 MB total (current: ~1.6 MB Lottie + ~9 MB audio - audio is a known overage to fix).

## 7. Risks

| Risk | Likelihood | Impact | Mitigation |
|---|---|---|---|
| Audio bundle too large (~9 MB sfx) | High | Medium | Compress to OPUS @ 64 kbps, target <2 MB. |
| Server-authoritative roll latency frustrates users | Medium | High | Optimistic local roll with rollback if server disagrees; show ping indicator. |
| Bot too easy / too hard | Medium | Medium | A/B test heuristic weights post-launch. |
| Pile-art PNGs are 8 MB total | High | Medium | Switch to SVG. |

## 8. Release plan

- **v1.0 (current):** Local + Bot mode, full UI, leaderboard wired but no online sync.
- **v1.1 (+2 weeks):** Centrifugo subscribe + authoritative dice/move, online random matches.
- **v1.2 (+4 weeks):** Friends invite link with deep-link join, team mode.
- **v1.3 (+8 weeks):** Difficulty tiers, audio compression, asset optimization.
