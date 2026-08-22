# Music Party — TRD

## Architecture

```
+------------------+        +-------------------+        +------------------+
|  Flutter Client  |  Spot  |  Spotify Web      |  Spot  |  Flutter Client  |
|  (DJ, Premium)   |<------>|  Playback SDK     |<------>|  (Listener Prem) |
+------------------+   API  +-------------------+   API  +------------------+
        ^                                                          |
        | LK data (mp-sync)                                        |
        v                                                          v
+--------------------+    +------------------------+    +-------------------+
|  Azure ACS Cloud     |<-->|  Go Service /api/v1/mp |<-->|  Postgres         |
|  data: mp-sync     |    |  Chi router            |    |  mp_sessions      |
+--------------------+    +------------------------+    |  mp_queue         |
                                  |          |          +-------------------+
                                  v          v
                         +-----------+  +-------------+
                         | Redis     |  | Centrifugo  |
                         | hot state |  | events      |
                         +-----------+  +-------------+
```

## Components
- **DJ** authenticates Spotify (OAuth Authorization Code with PKCE), holds the active playback device, drives the queue.
- **Listeners (Premium)** connect their Spotify devices and play the same URI at the same position.
- **Listeners (Free)** play 30 s preview MP3 (no Spotify auth needed) via `audioplayers`.
- **voice data channel `mp-sync`** carries `TrackAnchor` frames; durable state lives in Redis + Postgres.

## REST Routes
Base: `/api/v1/mp`

| Method | Path | Purpose |
|---|---|---|
| POST | `/sessions` | Create session in voice room |
| GET | `/sessions/:id` | Fetch state |
| PATCH | `/sessions/:id` | Update settings (rotation_mode, vote_skip_threshold) |
| DELETE | `/sessions/:id` | End |
| POST | `/sessions/:id/join` | Join, returns LK + Spotify scope hints |
| POST | `/sessions/:id/leave` | Leave |
| POST | `/sessions/:id/queue` | Add track |
| GET | `/sessions/:id/queue` | List queue |
| PATCH | `/sessions/:id/queue/:itemId` | Reorder (DJ only) |
| DELETE | `/sessions/:id/queue/:itemId` | Remove |
| POST | `/sessions/:id/play` | DJ starts current head |
| POST | `/sessions/:id/skip` | DJ or vote-skip |
| POST | `/sessions/:id/dj` | Hand off DJ |
| POST | `/sessions/:id/anchor` | DJ pushes anchor |
| GET | `/sessions/:id/anchor` | Late joiner pulls |
| POST | `/sessions/:id/vibe` | Reaction (heart, fire, skip-vote) |
| POST | `/spotify/oauth/callback` | OAuth callback |

## Payload Examples

POST `/sessions`
```json
{
  "room_id": "rm_01HX...",
  "settings": {
    "rotation_mode": "round_robin",
    "vote_skip_threshold": 0.5,
    "max_listeners": 25
  }
}
```

POST `/sessions/:id/queue`
```json
{
  "spotify_uri": "spotify:track:11dFghVXANMlKmJXsNCbNl",
  "added_by": "u_12"
}
```

Azure ACS data payload (TrackAnchor)
```json
{
  "v": 1,
  "type": "anchor|skip|reaction|queue_update",
  "session_id": "mp_01HX...",
  "track_uri": "spotify:track:11dFghVXANMlKmJXsNCbNl",
  "position_ms": 73250,
  "playing": true,
  "wall_clock_ms": 1733000123456,
  "dj_id": "u_12",
  "seq": 17
}
```

## DJ Rotation Algorithms
- **manual** — DJ stays until handoff or leaves.
- **round_robin** — On track-ended, advance DJ slot to next listener in `mp_participants` ordered by `joined_at`. Wrap.
- **listener_vote** — At end of every track, listeners vote on next DJ from candidate list (5 s window). Highest votes wins, tie → oldest joiner.

State stored: `current_dj_id`, `next_dj_id`, `rotation_mode`.

## Sync Engine
- DJ emits anchor every 4 s and on every play/pause/skip/seek.
- Listener computes drift; if > 700 ms, calls Spotify `seek` to expected position.
- Free listener with preview cannot seek mid-preview; instead waits to next track.
- Track change handled atomically: anchor type=track_change with both old and new URI.

## Spotify Integration
- OAuth scopes: `streaming user-read-email user-read-private user-modify-playback-state user-read-playback-state`.
- Tokens stored encrypted in `spotify_tokens` table; refreshed server-side ahead of expiry.
- Web Playback SDK only available on web; mobile uses Spotify App Remote SDK (Android, iOS via flutter_spotify_remote wrapper). Free user fallback: preview MP3.

## NFRs
- Anchor delivery p99 < 200 ms.
- Drift p95 < 400 ms among Premium listeners.
- Queue add to broadcast p95 < 250 ms.
- Session create p95 < 600 ms.
- Vote-skip aggregation window 5 s; outcome broadcast within 200 ms of close.

## Observability
Counters:
- `mp_sessions_created_total`
- `mp_sessions_active`
- `mp_tracks_played_total{result=completed|skipped|errored}`
- `mp_queue_adds_total`
- `mp_dj_rotations_total{mode}`
- `mp_drift_ms_bucket`
- `mp_spotify_errors_total{code}`
- `mp_preview_fallbacks_total`

Logs: `session_id`, `dj_id`, `track_uri`, `seq`, `spotify_status`.

Alerts:
- `mp_spotify_errors_total` rate > 5% for 10 min.
- DJ-rotation deadlock (no rotation > 10 min in round_robin).

## Security
- Only voice-room members can create/join.
- DJ-only mutations enforced server-side using Redis `mp:s:{id}:dj`.
- Vote-skip rate-limited to 1/track/user.
- Spotify tokens encrypted at rest using libsodium sealed boxes; never returned to client.

## Failure Modes
- **DJ Premium expired** — server detects via Spotify error 403 PREMIUM_REQUIRED, auto-rotates DJ.
- **Track unavailable in region** — broadcast skip with reason; advance queue.
- **Spotify SDK disconnect** — retry 3x, then degrade listener to preview mode.
- **All listeners free-tier** — session shifts to "preview-only" mode, max 30 s/track.
