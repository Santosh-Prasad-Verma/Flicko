# Watch Together — PRD

## 1-Line Summary
Synchronized video co-watching inside a Flicko voice room, where one host controls play/pause/seek and every participant sees the same frame within 250 ms.

## Problem
Friends in a Flicko voice channel currently have to count down "3, 2, 1, play" on YouTube and pray nobody buffered. Drift accumulates within minutes; reactions land on the wrong scene; people drop out for popcorn and lose their place. Discord's Watch Together activity solves this for paid Nitro users; we need a zero-cost equivalent that works for any room of up to 12 people.

## Target Users
- Long-distance friend groups doing weekly movie nights.
- Study groups going through lecture videos together.
- Family members watching cricket highlights or wedding reels across cities.
- Streamers reacting to a clip with their inner-circle audience.

## Jobs To Be Done
1. **JTBD-1** — When I drop a YouTube link in voice chat, I want everyone to be watching the same second so we can react together without coordinating manually.
2. **JTBD-2** — When my Wi-Fi hiccups and I fall behind, I want the system to silently catch me up so I don't have to ask "where are we?".
3. **JTBD-3** — When the host has to leave for ten minutes, I want playback to pause for everyone and resume from the same frame so nobody gets spoiled.

## Scope
**In scope (v1)**
- YouTube and Vimeo public links via embed.
- Direct MP4/HLS links from Appwrite Storage (room recordings, fan edits).
- Single host with handoff; up to 12 viewers per session.
- Play, pause, seek, playback rate (0.5x to 2x).
- Reactions overlay (emoji bursts) tied to current timestamp.
- Drift correction every 5 s with a 500 ms tolerance.
- Persistence so a refresh resumes within 2 s.

**Non-goals (v1)**
- DRM-protected content (Netflix, Prime). Out of scope forever — legally hostile.
- Picture-in-picture multi-stream.
- Subtitles upload by users (later — likely v2 with WebVTT).
- More than 12 simultaneous viewers (Azure ACS free tier ceiling).
- Server-side transcoding.

## Success Metrics
| Metric | Target | Measurement window |
|---|---|---|
| Median sync drift across 12-person session | < 250 ms | rolling 5 min |
| Session completion rate (host plays > 80% of duration) | > 55% | weekly |
| Sessions per WAU in voice channels | > 1.4 | monthly |
| p99 control-event latency (host click to viewer apply) | < 200 ms | daily |

## Competitive Snapshot
| Product | Cost | Sources | Max viewers | Sync method | Notable gap |
|---|---|---|---|---|---|
| Discord Watch Together | Nitro $9.99/mo | YouTube only | 50 | Embedded YT iframe API | Paid, no MP4 |
| Scener | Free w/ ads | Netflix, HBO | 10 | Browser extension | Requires desktop |
| Teleparty | Free | Netflix, Disney+ | 50 | Extension | No mobile |
| Kosmi | Free | YouTube, custom | 10 | WebRTC + manual sync | Buggy mobile |
| **Flicko Watch Together** | **$0** | **YouTube, Vimeo, MP4/HLS, Appwrite** | **12** | **voice data channel** | **Mobile-first** |

## Risks & Mitigations
- **YouTube ToS** — only public videos, embed-only, no scraping. Display creator credit.
- **Bandwidth** — recommend < 720p adaptive HLS; warn on cellular.
- **Host disconnect** — automatic election to oldest active participant within 3 s.
- **Copyright** — user-uploaded content goes through Appwrite with a takedown flag.

## Release Gate
- 95% of internal staff dogfood sessions complete without manual sync.
- Drift p95 below 350 ms in a five-person, four-continent test.
- Rollback flag (`activities.watch_together.enabled`) confirmed working.
