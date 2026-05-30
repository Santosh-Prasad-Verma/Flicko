# Gartic Phone — PRD

## 1-Line Summary
A round-based "telephone game" where players alternate drawing and captioning each round, then watch the absurd reveal gallery of how their original phrase mutated.

## Problem
Group games inside Flicko voice rooms today are limited. Gartic Phone is a beloved party game on the web, but it lives in a browser tab on someone's laptop while everyone else awkwardly screen-shares. It's mobile-first content trapped in a desktop UI, and there's no integrated chat/voice. We can host it natively inside a Flicko voice room with mobile-optimal touch drawing and tight integration to friends already in the room.

## Target Users
- Friend groups already in a voice room looking for a quick group game.
- Family video calls (cross-generational, low-skill bar).
- College squads on weekday nights.
- Streamers with their inner audience.

## Jobs To Be Done
1. **JTBD-1** — When we want a 15-minute group game with friends already in voice, I want to start it without anyone leaving the call or installing anything.
2. **JTBD-2** — When it's my turn to draw on my phone, I want a touch-friendly canvas with simple tools so I can sketch fast within the timer.
3. **JTBD-3** — When the rounds finish, I want to watch the reveal play back like a slideshow with reactions so the funniest moments land hard.

## Scope
**In scope (v1)**
- 4-12 players per session.
- Standard mode: alternating draw/caption rounds (n rounds = n players).
- Custom mode: host picks number of rounds (3, 5, 8) and timer (30 s, 60 s, 90 s).
- Drawing tools: brush size (3 widths), eraser, color picker (12 colors), undo, clear.
- Caption mode: 60 char limit, emoji allowed.
- Reveal gallery: animated slideshow with audience reactions.
- Save chain as image grid; export to camera roll.
- Voice channel chat continues throughout — game happens in foreground.

**Non-goals (v1)**
- AI suggestions or anti-NSFW classifier (manual report flow only).
- Voice-driven captions (record audio).
- Public matchmaking; only voice-room squads.
- Custom prompt packs marketplace (later).

## Success Metrics
| Metric | Target | Window |
|---|---|---|
| Session completion rate (all rounds finished) | > 70% | weekly |
| Median session length | 12-18 min | weekly |
| Reveal gallery view-through (% who watch full gallery) | > 75% | weekly |
| Sessions per voice-room WAU | > 0.6 | monthly |

## Competitive Snapshot
| Product | Cost | Mobile | Voice | Reveal | Gap |
|---|---|---|---|---|---|
| Gartic Phone web | free w/ ads | poor | none | yes | desktop-first |
| Skribbl.io | free | poor | none | yes | drawing only |
| Drawasaurus | freemium | mid | none | partial | no captions chain |
| Discord Sketch Heads | Nitro | yes | yes | partial | paywalled |
| **Flicko Gartic Phone** | **$0** | **first-class** | **integrated** | **slideshow + reactions** | **lives in voice room** |

## Risks & Mitigations
- **Inappropriate drawings** — report button + admin moderation queue. Adult content disclaimer at session start.
- **Long upload times on cellular** — drawings are vector strokes (small payload), not raster.
- **Synchronization** — round transitions broadcast via Centrifugo + LK; client buffers.
- **Player AFK during round** — auto-skip after timer; "missed turn" placeholder.

## Release Gate
- 90% completion rate in dogfood with 6 players.
- Reveal renders < 500 ms for 8-round chain.
- Round transitions consistent across all clients.
