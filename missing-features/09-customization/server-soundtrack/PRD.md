# Server Soundtrack — Product Requirements

> **One-line:** Low-volume royalty-free ambience looping in the background of a server.
> **Status:** Missing — to build
> **Category:** 09-customization
> **Effort:** L
> **Priority:** P2

## 1. Problem

Discord servers feel quiet and impersonal beyond text and voice channels. Users describe wanting a "lobby vibe" that sets a tone — coffee-shop ambience for study servers, lo-fi for chill servers, dungeon-crawl drones for tabletop servers. Today users blast Spotify in a voice channel as a hacky proxy, which uses gobs of CPU and copyright-rough.

Flicko's wedge: a curated library of royalty-free ambient tracks that loop quietly in a server, audible while you browse text/posts, separate from voice calls, with one-tap mute and per-user volume. LiveKit handles the audio track ingest as a low-priority server-wide stream. Owners pick or upload to the curated set; v1 is curate-only with maybe 80 tracks across genres.

## 2. Users & Use Cases

- **Primary persona:** "Hana" — runs a lo-fi study server; wants chill ambient music looping quietly while members write together.
- **Secondary personas:** D&D group wanting forest sounds; gaming clans wanting competitive tension drones.
- **Top 3 jobs-to-be-done:**
  1. As a server owner, I want to set a soundtrack, so my server has a vibe from the moment members enter.
  2. As a member, I want to mute or adjust volume, so I'm in control.
  3. As a member, I want it to auto-pause during voice calls, so I'm not fighting the call audio.

## 3. Goals & Non-Goals

**Goals**
- Curated library: 80 tracks across 8 genres (lo-fi, jazz, ambient, cafe, forest, rain, fireplace, drone).
- Owner picks one as the server's default soundtrack.
- Members can mute, adjust volume per-server, or disable globally.
- Auto-pause on voice/stage join; auto-resume on leave.
- Auto-pause on background tab/app.

**Non-Goals (out of scope for v1)**
- User-uploaded tracks (copyright land-mines).
- Per-channel soundtracks.
- Time-of-day rotation.
- DJ-style queue with members voting.
- Streaming services like Spotify/Apple Music integration.

## 4. Scope (v1)

- [ ] Track library table seeded with 80 royalty-free clips.
- [ ] Owner setting: pick track + default volume (0-100, default 30).
- [ ] LiveKit room per server with single ambient track.
- [ ] Mobile player widget docked under server header; collapsible.
- [ ] Auto-pause logic on call join, app background, low-power mode.
- [ ] Member preferences: mute per server, global "no soundtracks", volume slider.

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Servers with soundtrack on | 8% within 30d | DB count `server_soundtracks.enabled=true` |
| Member retention with soundtrack | +5pp vs control | A/B cohort |
| Audio bitrate cost per server | <$0.02/mo | LiveKit bandwidth |
| Mute rate (per session) | <30% | client event |
| Cost per server | <$0.05/mo | LiveKit free tier coverage |

## 6. Open Questions / Risks

- Will background audio drain battery? Yes some — pause on background mitigates.
- Royalty-free does *not* mean unlicensed; track each track's license URL and attribution; show attribution on long-press track name.
- Auto-pause heuristics: `AudioSession.interruption` on iOS, `AudioFocus` on Android.
- LiveKit room cost per server is non-trivial; defer to single shared "soundtrack" room per server only when ≥1 listener present.

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord | None | First-class |
| Slack | None | First-class |
| ClubHouse | Background BGM during rooms | Server-wide |
| Roblox | Ambient music per game | Same idea in chat-app |
| Spotify in voice | User-driven hack | Free, legal, integrated |

## 8. Rollout

- Internal dogfood with 10 tracks → 1% beta → 10% → GA.
- Flag: `feature.server_soundtrack.enabled`.
- Track library staged in batches (10 → 30 → 80) to verify CDN egress costs.
