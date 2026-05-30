# Karaoke Night — App Flow

## Sequence: Sign Up, Sing, Score

```mermaid
sequenceDiagram
    participant S as Singer (Flutter)
    participant L as Listener (Flutter)
    participant API as Go API
    participant DB as Postgres
    participant LK as LiveKit
    participant EG as LK Egress
    participant AW as Appwrite Storage
    participant Q as Redis (jobs)
    participant W as Pitch Worker

    S->>API: POST /kk/sessions/{id}/queue {song_id}
    API->>DB: INSERT karaoke_signups
    API-->>S: 200 ok
    Note over S,L: when S is at head of queue
    S->>API: POST /kk/sessions/{id}/start
    API->>EG: start track recorder for S's mic
    API->>LK: publishData(cue {song_id, start_in=3000ms})
    LK-->>L: cue
    L->>L: prefetch backing track + LRC
    LK-->>S: cue
    S->>S: start backing track at T0
    loop every line transition
      S->>LK: publishData(LyricAnchor)
      LK-->>L: anchor
      L->>L: jump to line, scroll
    end
    S->>API: POST /kk/sessions/{id}/stop (or auto on track end)
    API->>EG: stop recorder, get WAV URL in AW
    API->>Q: LPUSH kk:score:jobs {session_id, song_id, wav_url, singer}
    W->>Q: BRPOP kk:score:jobs
    W->>AW: GET wav
    W->>W: librosa pitch + DTW
    W->>API: POST /kk/sessions/{id}/scoring/result {score, breakdown}
    API->>DB: INSERT karaoke_scores
    API->>LK: publishData(score_ready)
    LK-->>L: score_ready
    LK-->>S: score_ready
    S->>S: render Score Reveal screen
```

## Sequence: Late Join Mid-Song

```mermaid
sequenceDiagram
    participant L as Listener (joining late)
    participant API as Go API
    participant LK as LiveKit

    L->>API: POST /kk/sessions/{id}/join
    API-->>L: 200 {lk_token, current_song, anchor, lrc_url}
    L->>L: fetch LRC, compute target line
    L->>LK: subscribe data
    L->>L: scroll to current line, wait next anchor
```

## State Machine — Session

```
DRAFT -> READY -> CUEING -> SINGING -> SCORING -> READY (next)
                              |
                              +--> SKIPPED -> READY
                              +--> CANCELLED -> READY
                                                |
                                                v
                                              ENDED
```

## State Machine — Singer Slot

```
SIGNED_UP -> CUED -> ACTIVE -> COMPLETED -> SCORE_PENDING -> SCORE_READY
                |             |
                |             +--> ABANDONED (mic drop)
                +--> WITHDRAWN
```

## State Machine — Score Job

```
QUEUED -> RUNNING -> SUCCEEDED
   |          |
   |          +--> FAILED -> RETRY (max 2)
   +--> EXPIRED (job > 60s)
```

## Edge Cases

### Mic Permission Denied
- Singer cannot start; UI shows "We need mic permission to capture your voice." with deep link to settings.
- Queue advances to next signer after 10 s if not resolved.

### Mic Silent for 5 s
- Treat as abandoned. Auto-stop, mark `ABANDONED`.
- Score still requested; `completeness` reflects portion sung.

### Backing Track Fails to Load on Listener
- Listener sees "Audio unavailable, lyrics still scrolling".
- Other listeners unaffected.

### Worker Crashes Mid-Job
- Job retried up to 2x; if final fail, score posted as `score=null`, breakdown omitted.
- UI shows "Couldn't score this take — try again next song".

### Worker Queue Backed Up (> 5 jobs)
- New songs allowed but score reveal delayed.
- Banner: "Scores are running ~30 s behind tonight."

### Singer Drops Mid-Song
- LK detects participant_left; auto-stop after 5 s.
- Listeners see "Singer dropped — moving on".

### LRC Mismatch with Backing Track
- Drift accumulates beyond 1 s → emergency anchor every line.
- Catalog admin notified via internal alert; song flagged.

### User Submits Track Without Rights
- Upload form requires checkbox attestation.
- Track lands in `pending_review` queue; admin must approve before catalog appears.

### Stealth Mode Singer
- Score saved but not broadcast; listener sees "Score hidden by singer".
- Leaderboard still counts (or not, per setting).

### Two Songs Queued by Same Singer in a Row
- Allowed; no rate limit on queueing for low-traffic v1.

### Singer's Backing Track Longer than 6 min
- Free-tier cap; UI shows "Tracks must be under 6 min." in song picker.

### Voice Channel Members > 25
- v1 cap; new members can listen but not sign up to sing until queue opens slot.

### LiveKit Audio Quality Drops
- Banner "Network is rough — quality may suffer". No app intervention; user adjusts.

### Concurrent Sessions in Same Voice Room
- Disallowed. Only one karaoke session per room.

### Egress Recording Fails
- Score impossible. Session continues; reveal shows "Couldn't capture audio for scoring."
