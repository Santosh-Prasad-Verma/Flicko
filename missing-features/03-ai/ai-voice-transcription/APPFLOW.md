# Live Voice Captions — Whisper.cpp Transcription — App Flow

## 1. End-to-End Journey — Live caption

```mermaid
sequenceDiagram
    participant Sp as Speaker (alice)
    participant LK as Azure ACS SFU
    participant EG as Track Egress
    participant W  as Caption worker
    participant V  as silero-vad
    participant Wp as whisper.cpp pool
    participant CF as Centrifugo
    participant Cl as Client (Flutter)

    Sp->>LK: Opus packets
    LK->>EG: forward track
    EG->>W: PCM 16kHz frames
    loop every 20ms
      W->>V: feed frame
    end
    V-->>W: speech_start at t=124300
    Note over W: collect frames into buffer
    V-->>W: speech_end at t=125860 (1560ms)
    W->>Wp: submit segment[124300..125860]
    Wp-->>W: text="did anyone see the keynote", conf=0.91
    W->>CF: publish caption.final
    CF-->>Cl: caption.final
    Cl-->>Cl: render line with alice color
    W->>W: append voice_transcripts
```

## 2. Streaming partials (long utterance)

```mermaid
sequenceDiagram
    participant W
    participant Wp
    participant CF
    participant Cl
    Note over W: speaker still speaking, 1.5s elapsed
    W->>Wp: submit rolling buffer (no end yet)
    Wp-->>W: text="did anyone see"
    W->>CF: caption.partial
    CF-->>Cl: render italic, cursor
    Note over W: another 1.5s
    W->>Wp: submit rolling buffer
    Wp-->>W: text="did anyone see the keynote yet"
    W->>CF: caption.partial
    Cl-->>Cl: replace last partial line
    Note over W: speech_end
    W->>Wp: final segment
    Wp-->>W: text="did anyone see the keynote yet"
    W->>CF: caption.final
```

## 3. Late-join flow

```mermaid
sequenceDiagram
    participant U  as User
    participant API
    participant DB as Postgres
    U->>API: GET /api/v1/ai/captions/sessions/<sid>?since=now-5m
    API->>DB: SELECT * FROM voice_transcripts WHERE session_id=$1 AND t_start_ms > $now-5m
    DB-->>API: 27 rows
    API-->>U: JSON
    U-->>U: open late-join modal
    U->>U: tap "jump to live"
    U->>CF: subscribe voice_captions:<chan>
```

## 4. Worker overload + degradation

```mermaid
sequenceDiagram
    participant W
    participant Wp as whisper pool
    participant Adm as Admin metric
    Wp-->>W: queue depth 30, p95 inference 2.4s
    W->>W: switch model to tiny.en
    W->>CF: caption.error code=degraded msg="captions: tiny model"
    Adm-->>Adm: alert flicko_ai_captions_degraded=1
```

## 5. State Machine — Worker

```
[idle]
  -- session.started --> [warming]
[warming]
  -- model loaded     --> [listening]
[listening]
  -- speech_start     --> [collecting]
[collecting]
  -- speech_end / 15s --> [transcribing]
  -- session.ended    --> [draining]
[transcribing]
  -- text             --> [listening]
  -- failure          --> [error]
[draining]
  -- empty queue      --> [idle]
[error]
  -- retry            --> [listening]
```

## 6. User Journeys

### J1 — Deaf user joins voice channel
1. Alice joins `#lounge` voice. Toggle `CC` is ON by default (admin enabled, user pref ON).
2. Captions appear within 1s of someone speaking.
3. Reads conversation; sees Bob said "yeah it was wild".
4. Late-join modal showed last 5 min.

### J2 — Admin first-time enable
1. Admin opens channel settings → Captions → toggle ON.
2. Picks `small.en` model.
3. Joins channel; sees CC ON badge.
4. Members in channel get a system message "Captions enabled" with deep link to settings.

### J3 — Profanity reduction
1. User toggles "Reduce profanity" in caption settings.
2. Worker masks recognized profanity tokens with asterisks (post-processing).
3. Original transcript stored unmasked; only client-rendered version masked.

### J4 — Session export
1. Voice session ends.
2. Mod taps "Session ended" notification → Export.
3. Receives `.txt` with timestamps and speakers.

## 7. Edge Cases

- **Music bot playing:** worker pauses transcription when `bot:music` user is in channel (avoid lyrics chaos)
- **Two people talking simultaneously:** per-track isolation handles cleanly; both lines emit
- **User mutes mid-utterance:** worker finalizes the partial it has
- **Whisper hallucinates on silence:** VAD confidence gate ≥0.5 + minimum 200ms speech required
- **User joins after session ended:** export available for 30d
- **Network drops:** client buffers partials; on reconnect, reads `voice_transcripts` from missed window
- **Member's display name has emoji:** rendered as fallback name "alice" with emoji in semantic label

## 8. Background / Async

- **Session lifecycle:**
  - `flicko.voice.session.started` → spawn caption worker
  - `flicko.voice.session.ended` → drain & flush transcript to DB, publish notification
  - Cron `0 */6 * * *` → archive transcripts > 24h to R2 parquet, delete from primary
- **Worker auto-scale:** Kubernetes HPA on `flicko_ai_voice_transcription_active_channels`; one pod per ~32 channels (small.en)
- **Health check:** every 30s; replace pod if WER spikes > 25% over baseline

## 9. Notifications

- **Trigger:** session ended with captions enabled → DM to channel mod
- **Channel:** in-app + push
- **Copy:** "Voice session ended in #lounge. Transcript ready."
- **Deep link:** `flicko://channel/<id>/transcript/<session_id>`
- **Batching rule:** none (one per session is rare)
