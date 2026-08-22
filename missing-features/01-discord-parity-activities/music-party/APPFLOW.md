# Music Party — App Flow

## Sequence: Create Session, Add Tracks, Play

```mermaid
sequenceDiagram
    participant DJ as DJ (Flutter)
    participant API as Go API
    participant DB as Postgres
    participant R as Redis
    participant LK as Azure ACS
    participant SP as Spotify
    participant L as Listener (Flutter)

    DJ->>API: POST /mp/sessions {room_id, settings}
    API->>DB: INSERT mp_sessions
    API->>R: SET mp:s:{id}:state, dj=DJ
    API->>LK: mintToken(DJ, can_publish_data)
    API-->>DJ: 201 {session, lk_token}
    L->>API: POST /mp/sessions/{id}/join
    API->>DB: INSERT mp_participants
    API->>LK: mintToken(L, can_subscribe_data)
    API-->>L: 200 {lk_token, queue, anchor}
    DJ->>API: POST /mp/sessions/{id}/queue {spotify_uri}
    API->>DB: INSERT mp_queue
    API->>R: ZADD mp:s:{id}:queue
    API-->>DJ: 200
    API->>LK: publishData(queue_update)
    LK-->>L: queue_update
    DJ->>SP: SDK play(track_uri)
    SP-->>DJ: ok
    DJ->>API: POST /mp/sessions/{id}/anchor
    API->>R: HSET mp:s:{id}:state position, playing
    DJ->>LK: publishData(TrackAnchor)
    LK-->>L: TrackAnchor
    L->>SP: SDK play(track_uri, position)
    loop every 4s
      DJ->>LK: anchor heartbeat
      LK-->>L: anchor
      L->>L: drift check, seek if > 700ms
    end
```

## Sequence: Round-Robin Rotation

```mermaid
sequenceDiagram
    participant DJ as Current DJ
    participant API as Go API
    participant SP as Spotify
    participant Next as Next DJ
    participant L as Listener

    DJ->>SP: track ends event
    DJ->>API: POST /mp/sessions/{id}/skip {reason=ended}
    API->>API: rotate dj per round-robin
    API->>R: SET mp:s:{id}:dj = Next
    API->>LK: publishData(dj_changed)
    API-->>Next: Centrifugo "you-are-dj"
    Next->>SP: SDK play(next_track)
    Next->>API: POST anchor
```

## Sequence: Vote-Skip

```mermaid
sequenceDiagram
    participant L1 as Listener 1
    participant L2 as Listener 2
    participant API as Go API
    participant DJ as DJ

    L1->>API: POST /vibe {kind=skip_vote}
    API->>R: INCR mp:s:{id}:skip:{track_uri}
    API->>API: votes >= threshold * listeners?
    L2->>API: POST /vibe {kind=skip_vote}
    API->>R: INCR
    API->>API: threshold reached
    API->>LK: publishData(skip)
    LK-->>DJ: skip
    DJ->>API: POST /skip {reason=vote}
    API->>API: advance queue
```

## State Machine — Session

```
DRAFT -> READY -> PLAYING <-> PAUSED -> ENDED
                     ^
                     | track_change (atomic)
                     v
                  PLAYING (new track)
```

## State Machine — Queue Item

```
QUEUED -> PLAYING -> COMPLETED
   |          |
   |          +--> SKIPPED (dj or vote)
   +--> REMOVED (by adder or DJ)
```

## State Machine — DJ Slot

```
        +------- handoff ------+
        v                      |
   IDLE -> ACTIVE_DJ -> ROTATING
              |              |
              | leave        | next_dj_chosen
              v              v
           ROTATING       ACTIVE_DJ (new)
```

## Edge Cases

### Free-Tier Listener Joins
- Detect via Spotify `subscription_level`. If `free`, route to preview path.
- Server fetches `preview_url` from Spotify for queued track; client plays via `audioplayers`.
- Sync limited to "play same preview at start". No mid-track seek.

### DJ Premium Lapses Mid-Session
- Spotify SDK throws PREMIUM_REQUIRED.
- Server marks DJ ineligible, triggers immediate rotation.
- Listener-vote mode: surface a vote modal with eligible candidates.

### Spotify Outage
- After 3 consecutive 5xx, session enters `degraded` state.
- Banner: "Spotify is having issues. We'll reconnect automatically."
- Queue ops still allowed; playback paused until SDK responds.

### Track Unavailable in Listener Region
- Listener's SDK returns `restriction.reason=market`.
- Server logs `mp_track_skipped_total{reason=market}` and broadcasts skip after 3 listeners report.

### DJ Disconnect
- LK webhook + 5 s grace.
- Round-robin: advance to next listener.
- Manual: pause session, surface "DJ left — pick a new DJ" modal to remaining users; first taker becomes DJ.

### All Listeners Leave
- Session keeps DJ for 60 s with their track playing.
- After 60 s of zero listeners, end session.

### Network Drop on Listener
- SDK retains buffered audio; on reconnect, fetch `GET /anchor`, seek.

### Add to Queue While Skipping
- Queue ops use Redis `ZADD` with score `now()` to avoid race; final order recomputed on broadcast.

### Duplicate Track in Queue
- Allowed (people request the same banger). Show count badge "x2".

### Long Track (> 10 min)
- Allowed. Rotation modes still trigger on track-end.
- Skip-vote threshold reachable as usual.

### Voice Room Banned User Tries to Join
- 403 from `/join`; client shows "You don't have access to this room."

### Spotify Token Refresh During Playback
- Server refreshes 60 s before expiry; client SDK re-auths silently. No user-visible interruption.

### Preview File 404
- Some tracks lack `preview_url`. Free listener sees "Preview unavailable for this track" and silent gap. DJ continues.
