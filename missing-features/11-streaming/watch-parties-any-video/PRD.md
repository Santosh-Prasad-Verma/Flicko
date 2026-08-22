# PRD: Watch Parties for Any Video

## Problem
Flicko members already gather in voice and stage channels but cannot watch videos together unless someone screen-shares, which loses fidelity, breaks DRM, and saturates upload bandwidth. Members want to drop a YouTube, Twitch, Vimeo, or MP4 link into a server and host a synchronized viewing room with reactions, chat, and presence, the same way Discord Watch Together works but without locking the experience to one provider.

## Goals
- Let any server member with the `start_watch_party` permission spin up a party in under 10 seconds from a single URL.
- Support YouTube, Twitch (VOD + live), Vimeo, and direct MP4/HLS sources behind a single provider abstraction so new providers can be added without UI rewrites.
- Keep playback drift between participants under 750 ms at the 95th percentile under normal network conditions.
- Survive host disconnects through automatic host election so the party never freezes when the originator leaves.
- Pipe a chat sidebar that shares moderation, slow mode, and emoji rules with the parent text channel.

## Non-Goals
- Re-streaming or transcoding third-party content. Each client fetches the original source itself; Flicko only synchronizes timestamps.
- Bypassing geo-restrictions, DRM, or paid subscriptions. Twitch subscriber-only VODs simply fail to load for non-subscribers.
- Offline or background playback.
- Replacing native RTMP streaming (covered by the `native-rtmp-streaming` feature). Watch parties are for shared playback of pre-existing media.

## Users and Personas
- Casual server members hosting a Friday-night movie night with an MP4 they own.
- Esports communities co-watching a Twitch VOD of yesterday's tournament.
- Music servers reacting together to a freshly dropped YouTube music video.
- Moderators who need to pause, seek, or kill a party that violates server rules.

## Core User Stories
1. As a host, I paste `https://youtu.be/abc` into the new-party sheet, pick a name, choose voice channel `#movie-night`, and tap Start. Within five seconds participants see the YouTube player ready at 0:00.
2. As a participant, I open a notification card, join, and the player auto-seeks to 14:32 because the party is already in progress.
3. As a host, I scrub to 22:10. Every other client lands within one second of 22:10 without buffering thrash.
4. As a host, I close the app mid-party. Within three seconds another participant is promoted to host and playback continues.
5. As a moderator, I open the party in the moderation tab, force-pause it, and post a public reason in the chat sidebar.

## Functional Requirements
- **Provider detection**: paste a URL, the client calls `POST /watch-parties/resolve` which returns `{provider, external_id, duration_seconds, thumbnail_url, embeddable: true}` or a structured error.
- **Party lifecycle**: states are `scheduled`, `live`, `paused`, `ended`. Hosts can schedule up to 7 days ahead; ended parties are read-only and retained for 30 days.
- **Host election**: if the host's heartbeat lapses for 8 seconds, the participant with the lowest `joined_at` who is still connected is promoted. Promotion is idempotent; ties break on `participant_id` lexicographic order.
- **Drift correction**: every 2 seconds the host broadcasts `{position_ms, playback_rate, wall_clock_ms}` over the voice data channel. Clients drifting more than 600 ms hard-seek; clients drifting 200 to 600 ms nudge `playbackRate` to 0.95 or 1.05 until aligned.
- **Chat sidebar**: lives inside the party panel, posts to a synthetic `watch_party:<id>` topic on the existing chat infra, inherits parent channel moderation.
- **Reactions**: timestamped emoji bursts ("3:14 fire") replayed in the timeline scrubber.
- **Permissions**: `start_watch_party`, `join_watch_party`, `moderate_watch_party` per role; defaults grant `start` and `join` to `@everyone`.

## Success Metrics
- 60 percent of servers with more than 50 weekly active members host at least one party in the first 30 days post-launch.
- Median time from party creation to first participant playback under 6 seconds.
- Drift exceeding 1 second in fewer than 5 percent of 1-second sampling windows across the trailing 7 days.
- Host-disconnect freezes resolved within 5 seconds in at least 99 percent of cases.

## Constraints and Assumptions
- Voice rooms are reused: a watch-party room ID matches the linked voice channel's room when present, otherwise a synthetic room `wp_<party_id>` is provisioned on demand.
- Participant cap: 250 concurrent per party (voice data-channel fan-out budget). Parties exceeding 200 active participants stop relaying reactions individually and switch to aggregated counters.
- Provider terms-of-service: YouTube IFrame API requires the embed UI to remain visible; we never strip controls. Twitch embeds require parent domain registration; we ship a per-environment allow-list.
- The MP4 provider only accepts URLs returning `Content-Type: video/mp4` or `application/vnd.apple.mpegurl` over HTTPS with CORS allowing our origin.

## Open Questions
- Do we ship a "BYO captions" upload at launch, or rely on provider-native captions for v1? Current plan: provider-native only at launch.
- Should scheduled parties block the host's calendar and send reminder pings? Tracked separately; default off until we ship a calendar primitive.
- How do we handle Twitch live VOD that ends mid-party and gets archived? The provider returns `live_ended`, the party is paused with a banner, host can switch to the resulting VOD with one tap.

## Rollout
- Phase 1: internal dogfood server, MP4 provider only, no scheduling.
- Phase 2: 5 percent server rollout, all providers, scheduling disabled.
- Phase 3: full rollout with scheduling and moderation tools.
- Kill-switch: `feature_flags.watch_parties_enabled` per-environment plus per-server override.
