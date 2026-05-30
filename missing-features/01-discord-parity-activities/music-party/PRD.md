# Music Party — PRD

## 1-Line Summary
A collaborative listening room where members queue tracks, take turns as DJ, and hear the same song at the same beat — powered by Spotify Web Playback for licensed audio, with zero infra cost.

## Problem
Hanging out in a Flicko voice room and "let me play this song" devolves into someone holding their phone to their mic. Spotify Group Sessions are buggy, locked to Premium, and don't surface to a friend group's social context. Discord doesn't ship a real music activity. We want a shared queue, a rotating DJ, and the music actually licensed.

## Target Users
- Friend groups studying together who want a shared playlist humming in the background.
- Roommates who can't agree on what to play.
- Long-distance couples who do "song trade Fridays".
- Gaming squads warming up before matches.

## Jobs To Be Done
1. **JTBD-1** — When my friend plays a banger, I want to add the next track without interrupting them so the vibe keeps going.
2. **JTBD-2** — When I find a song I'm obsessed with, I want everyone in the room to hear it from the first second on the same beat so we can react in unison.
3. **JTBD-3** — When I'm hosting and need a break, I want the DJ slot to rotate to the next person automatically so the music doesn't stop.

## Scope
**In scope (v1)**
- Spotify Web Playback SDK for users with Premium (host requirement).
- Free-tier listeners get a 30-second preview synced via SDK preview URL.
- Shared queue with reorder by DJ, add by anyone.
- DJ rotation modes: manual, round-robin, listener-vote.
- Up to 25 listeners per session.
- Reactions per track (vibe, skip-vote).
- Now-playing card with album art, artist, scrub bar.

**Non-goals (v1)**
- Apple Music or YouTube Music (no public sync API on mobile).
- Uploading user audio (rights nightmare).
- Lyrics overlay (handled by Karaoke activity).
- Voice-modulated DJ effects.

## Success Metrics
| Metric | Target | Window |
|---|---|---|
| Median tracks per session | > 6 | weekly |
| DJ rotation usage (sessions where 2+ DJs play) | > 35% | weekly |
| Sync drift across listeners (p95) | < 400 ms | rolling 5 min |
| Add-to-queue conversion (sessions where a non-DJ adds a track) | > 50% | weekly |

## Competitive Snapshot
| Product | Cost | Catalog | Max listeners | Sync method | Gap |
|---|---|---|---|---|---|
| Spotify Group Session | Premium $9.99 | Spotify | 8 | First-party | Premium-only, brittle |
| JQBX | Free w/ ads | Spotify | 50 | Polling | Mobile is afterthought |
| Turntable.fm reboot | Free | Soundcloud | 200 | Web | Browser only |
| Discord Spotify Sync | Nitro | Spotify | unlimited | Listen-along | Pairs only |
| **Flicko Music Party** | **$0** | **Spotify (full) + previews (free)** | **25** | **LK + SDK position-sync** | **Mobile-first + DJ rotation** |

## Risks & Mitigations
- **Spotify Premium gating** — surface clearly; non-premium hears 30 s preview synced; CTA to "Vibe with full track via Spotify".
- **Catalog rights** — only Spotify-served audio; we do not host audio.
- **Rate limits** — Spotify Web API allows ~180 req/min/user; queue ops chunked.
- **Sync drift** — anchor on track URI + position_ms every 4 s.

## Release Gate
- 90% of dogfood sessions reach 4+ tracks without crash.
- Sync drift p95 < 500 ms with 10 listeners.
- Free-tier preview path verified across iOS and Android.
