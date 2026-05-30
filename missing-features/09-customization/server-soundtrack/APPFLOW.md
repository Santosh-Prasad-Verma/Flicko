# APPFLOW - Server Soundtrack

End-to-end behavior: how an admin selecting a track propagates to every member's client, how clients fetch and loop the audio, how state transitions through the lifecycle, and how each documented edge case resolves.

## 1. Sequence: Admin sets track -> broadcast -> client plays loop

```mermaid
sequenceDiagram
    autonumber
    participant Admin as Admin (Flutter)
    participant API as Go API
    participant DB as Supabase Postgres
    participant Cache as Redis
    participant Audit as audit_log
    participant Cent as Centrifugo
    participant AW as Appwrite Storage
    participant LK as LiveKit SFU
    participant Member as Member (Flutter)

    Admin->>API: PUT /servers/:id/soundtrack {track_id, vol, fade}
    API->>DB: SELECT track + role check (RLS)
    DB-->>API: track row, member is admin
    API->>DB: UPSERT server_soundtracks (version + 1)
    DB-->>API: ok, version=v
    API->>Cache: DEL soundtrack:server:{id}
    API->>Audit: INSERT soundtrack.set
    API->>Cent: PUBLISH server.{id}.soundtrack {track_id, version}
    API-->>Admin: 200 {active, broadcast_id}

    Cent-->>Member: push soundtrack.updated
    Member->>API: GET /servers/:id/soundtrack (if version stale)
    API->>Cache: GET soundtrack:server:{id}
    Cache-->>API: miss
    API->>DB: SELECT joined track
    DB-->>API: row
    API->>Cache: SET soundtrack:server:{id} TTL 300s
    API->>AW: createSignedUrl(track.file_id, ttl=1h)
    AW-->>API: signed URL
    API-->>Member: {track, stream_url, volume_db, fade}

    Member->>AW: GET stream_url (range, prefetch ~10s)
    AW-->>Member: opus loop body
    Member->>LK: subscribe room.audio (priority=4)
    LK-->>Member: voice mix (if any)
    Note over Member: client mixes loop + voice;<br/>ducks loop -6dB while voice active
```

Notes on the sequence:
- Step 5 uses an optimistic version: the server stores `version` and clients keep `last_seen_version`. The push includes only `version`; clients decide whether to refetch.
- Step 14 uses an HTTP range request so the client can begin playback while the rest streams.
- LiveKit is not the source of the music; it is only the voice channel mixer that informs the duck signal.

## 2. State machine (per client, per server)

```
                         enable + has_track
              +--------+ ---------------------> +-----------+
              | IDLE   |                        | RESOLVING |
              +--------+ <-+                    +-----+-----+
                  ^        |                          | got url
                  |        | disable / cleared        v
                  |        |                    +------------+
                  |        +------------------- | BUFFERING  |
                  |                             +-----+------+
                  |                                   | >=2s buffered
                  |                                   v
                  |   member mute toggled       +-----------+
                  |  <------------------------- |  PLAYING  |
                  |                             +-----+-----+
                  |                                   |
                  |       fetch error (>=3 retries)   |
                  |  <-------------------------------+|
                  |                                   |
                  |    bandwidth < 80kbps             |
                  |  <----------- DEGRADED <----------+
                  |                ^
                  |                | recover
                  |                v
                  |              PLAYING
                  v
              +--------+
              | ERROR  |  toast + retry button; auto-retry every 30s
              +--------+
```

Transitions:
- `IDLE -> RESOLVING`: triggered by app start, server join, or `soundtrack.updated` push.
- `RESOLVING -> BUFFERING`: signed URL acquired, decoder primed.
- `BUFFERING -> PLAYING`: at least `fade_seconds` of audio prebuffered, fade-in starts.
- `PLAYING -> PLAYING (muted)`: client retains stream connection but sets gain to -inf; this avoids re-buffer storm if user toggles back.
- `PLAYING -> DEGRADED`: probe detects bandwidth < 80 kbps; client switches to 32 kbps variant.
- any -> `IDLE`: server publishes `soundtrack.cleared` or admin disables.
- any -> `ERROR`: 3 consecutive HTTP failures or decoder fault.

## 3. Edge cases

### 3.1 Track removed (retired) while in use

1. Platform admin retires `trk_x` (`is_retired = true`).
2. Background job scans `server_soundtracks` rows referencing `trk_x`.
3. For each row, job nulls `track_id`, sets `enabled = false`, bumps `version`, publishes `soundtrack.cleared` to the server channel.
4. Clients in `PLAYING` fade out over `fade_seconds`, transition to `IDLE`.
5. Admin sees a banner in Server Settings: "The previous track was retired. Choose a new one."

If a client is already mid-fetch on `trk_x`'s signed URL when retirement happens, the URL stays valid until expiry (1h). That is acceptable; the next push reconciles the state.

### 3.2 Low-bandwidth fallback

Client measures sustained throughput on the soundtrack socket (EWMA over 15s).

```
if (avg_kbps < 80 && variant != "low") {
   load 32kbps_variant;
   set state = DEGRADED;
} else if (avg_kbps > 140 && variant == "low") {
   reload 48kbps_variant on next loop boundary;
   set state = PLAYING;
}
```

If even the 32 kbps variant cannot sustain (3 stalls in 60s), client moves to `IDLE` and shows a non-blocking toast: "Soundtrack paused due to weak connection." Voice channel quality is unaffected.

### 3.3 Member mute (local override)

1. Member taps mute on the strip.
2. Client immediately sets gain to -inf (no fade; mute is intentional).
3. Client persists `user_soundtrack_overrides` via `PUT /me/soundtrack-overrides/:server_id` with `mute=true`.
4. On other devices, client polls or receives `user.{user_id}.overrides` push and applies the same mute.
5. Server soundtrack continues for everyone else; the muted client still maintains the stream subscription so unmute is instant.

If the override write fails (offline), the local mute is queued in the outbox and retried; mute remains effective locally regardless.

### 3.4 Admin disables soundtrack

1. `DELETE /servers/:id/soundtrack` flips `enabled=false`, bumps `version`, leaves `track_id` intact for fast re-enable.
2. Push `soundtrack.cleared` -> clients fade out.
3. Re-enabling within 5 minutes uses the cached row; no new signed URL needed if existing one is unexpired.

### 3.5 Centrifugo unreachable

- Clients fall back to a 60s poll on `/servers/:id/soundtrack`.
- Backend keeps publishing; once Centrifugo recovers, clients suppress duplicate state changes via `version` comparison.
- If push has been silent for 5 minutes and no poll has succeeded, the strip shows a small dot indicator: "Out of sync".

### 3.6 Many members joining simultaneously (raid / popular server)

- Cache prevents DB hot row contention; signed URL issuance is the rate-limited path (Appwrite quota).
- API batches signed URL creation per track for 250 ms windows; multiple member fetches within a window share a URL (TTL 1h).
- If Appwrite returns 429, API serves the cached URL even if it has < 5 min remaining; clients refetch on first 403.

### 3.7 Voice channel ducking

- LiveKit emits `participant.is_speaking` events.
- Client subscribes; whenever any speaker is active in the user's current room, the soundtrack gain is multiplied by `10^(-6/20)` (a -6 dB duck) over 120 ms.
- On silence (700 ms hangover), gain ramps back over 240 ms.
- If the user is not in a voice channel, no ducking is applied.

### 3.8 App backgrounded on mobile

- After 30 s of background, client tears down the audio session to save battery.
- On foreground, state goes `IDLE -> RESOLVING` again, reusing the cached `version` and signed URL when still valid.

## 4. Validation order on PUT

1. Auth (JWT) - rejects unauthenticated.
2. Membership + role (admin or owner) - 403 otherwise.
3. Track exists, not retired - 422 otherwise.
4. Volume in `[-36, -6]` dB, fade in `[0, 8]` s - 422 otherwise.
5. Persist with optimistic lock on `version` - retry once on conflict.
6. Cache invalidate, audit, publish - any failure here logs but still returns 200 (best-effort propagation, idempotent retry by client).
