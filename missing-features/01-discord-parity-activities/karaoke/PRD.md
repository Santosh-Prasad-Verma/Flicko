# Karaoke Night — PRD

## 1-Line Summary
A live karaoke room inside Flicko where one singer's mic is captured, lyrics scroll in time, and a server-side worker scores their pitch in near-real-time so the squad can roast or applaud.

## Problem
Singing on a video call is awkward. Audio drifts, lyrics aren't synced, and there's no scoreboard to make it a game. Existing karaoke apps require expensive licensing or are locked to one device. Flicko already has a voice channel; the missing piece is synced lyrics, mic capture, and a fun scoring layer that nudges shy people to take the mic.

## Target Users
- Friend groups doing late-night karaoke jams over voice.
- Couples doing duets long-distance.
- Streamers who want a performative game with their audience.
- Birthday rooms where the celebrant gets a "song dedicated to them".

## Jobs To Be Done
1. **JTBD-1** — When my friend picks a song, I want lyrics to scroll on my screen in time so I can sing along even if I forget the words.
2. **JTBD-2** — When I take the mic, I want a score at the end so I know how I did and can compete with my friends.
3. **JTBD-3** — When we're rotating singers, I want a queue and a "next up" cue so the energy doesn't break between songs.

## Scope
**In scope (v1)**
- Curated karaoke catalog of ~200 royalty-free / public-domain backing tracks plus user-submitted MP3 with cleared rights toggled in upload.
- Synchronized LRC-style lyrics scroll across all listeners.
- Mic capture from active singer; relayed via existing voice channel (LiveKit audio).
- Server-side pitch scoring worker (Python + librosa) returns score within 6 s of song end.
- Singer queue with rotation + "skip" democracy.
- Score history per user; weekly leaderboard per voice room.

**Non-goals (v1)**
- Real-time per-line score overlay during the song (compute too heavy on free tier).
- Auto-tune / vocal effects.
- Cover-rights clearance for major-label catalog (use only PD/CC tracks for v1).
- Multi-singer harmonies (mono singer per song).

## Success Metrics
| Metric | Target | Window |
|---|---|---|
| Songs sung per session | > 4 | weekly |
| Singer queue takers per session (% of listeners) | > 40% | weekly |
| Score availability (song-end to score shown) p95 | < 8 s | daily |
| Lyric sync drift (p95) across listeners | < 250 ms | rolling |

## Competitive Snapshot
| Product | Cost | Catalog | Sync | Scoring | Gap |
|---|---|---|---|---|---|
| Smule | freemium $7.99/mo | major label | first-party | yes | mobile-only, paywalled |
| StarMaker | freemium | label | first-party | yes | algorithm gamed |
| YouTube karaoke | free | varies | unsynced | no | no scoring, no rotation |
| Watch2Gether sing-along | free | YouTube | embed | no | no mic, no scoring |
| **Flicko Karaoke** | **$0** | **PD/CC + user** | **LK + LRC sync** | **librosa worker** | **lives inside voice channel, social-first** |

## Risks & Mitigations
- **Music rights** — start with PD + CC catalog only. User uploads require self-attestation checkbox; takedown queue.
- **Pitch worker cost** — process audio at 16 kHz, mono, downsampled; one worker on free Fly.io VM handles serial requests, queue depth bounded.
- **Voice quality** — rely on LiveKit's existing AEC; provide "mic check" preview.
- **Social anxiety** — "stealth mode" lets shy singers sing with score hidden.

## Release Gate
- Catalog ≥ 100 songs with verified LRC.
- Score returned in < 10 s p99.
- Drift p95 < 350 ms.
- Rollback flag works.
