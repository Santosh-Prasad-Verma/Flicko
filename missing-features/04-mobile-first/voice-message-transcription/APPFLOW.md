# Voice Message Transcription - APPFLOW

## 1. End-to-End Flow (Recipient)

```mermaid
sequenceDiagram
    participant Chat as Chat Screen
    participant Orch as TranscriptionOrchestrator
    participant Cache as Hive Cache
    participant FFI as WhisperFFI Isolate
    participant FB as Server Fallback
    participant BE as Flicko Backend

    Chat->>Orch: voice_message_visible(messageId, audioUrl)
    Orch->>Cache: lookup(messageId)
    alt cache hit
        Cache-->>Orch: transcript
        Orch-->>Chat: render transcript
    else miss
        Orch->>Orch: download audio (if not local)
        Orch->>FFI: transcribe(audioPath, lang?, model)
        FFI-->>Orch: stream of segments
        Orch-->>Chat: render words progressively
        alt success
            Orch->>Cache: write(messageId, transcript)
        else failure
            alt server fallback opted-in
                Orch->>FB: POST /api/v1/transcribe
                FB->>BE: enqueue
                BE-->>FB: 200 transcript
                FB-->>Orch: transcript
                Orch->>Cache: write
                Orch-->>Chat: render
            else opted out
                Orch-->>Chat: "Tap to retry"
            end
        end
    end
```

## 2. End-to-End Flow (Sender, Pre-Transcription)

```mermaid
sequenceDiagram
    participant Mic as Recorder
    participant Sender as Composer
    participant Orch as TranscriptionOrchestrator
    participant FFI as WhisperFFI Isolate
    participant API as Backend Messages API

    Mic->>Sender: stop recording
    Sender->>Orch: transcribe pre-send(filepath)
    Orch->>FFI: transcribe local
    FFI-->>Orch: transcript
    Sender->>API: POST /api/v1/messages (audio + transcript)
    API-->>Sender: 201 Created (message + fts indexed)
```

## 3. Server Fallback Async Flow (Long Clips)

```mermaid
sequenceDiagram
    participant Phone
    participant API
    participant Worker
    participant Cache as Server Cache

    Phone->>API: POST /api/v1/transcribe (audio 90s)
    API->>Worker: enqueue
    API-->>Phone: 202 {transcript_id, poll_url}
    loop every 2s
        Phone->>API: GET /api/v1/transcribe/:id
        API->>Cache: read progress
        alt incomplete
            API-->>Phone: 202 {progress_pct: 45}
        else complete
            API-->>Phone: 200 {segments, lang}
        end
    end
```

## 4. State Machine - Per-Message Transcription

```
                     ┌──────────────┐
   message visible ► │   PENDING    │
                     └──────┬───────┘
                            │ start engine
                            ▼
                     ┌──────────────┐
                     │  RUNNING     │
                     └─┬─────┬──────┘
              first wd │     │ failure
                       ▼     ▼
              ┌──────────────┐  ┌────────────┐
              │ STREAMING    │  │ FAILED     │
              └─────┬────────┘  └──────┬─────┘
              done  │                  │ retry / fallback
                    ▼                  ▼
              ┌──────────────┐  ┌────────────┐
              │ COMPLETED    │  │ FALLBACK   │
              └──────────────┘  │ (running)  │
                                └─────┬──────┘
                                      │ ok / err
                          ┌───────────┼─────────┐
                          ▼                     ▼
                  ┌──────────────┐      ┌────────────┐
                  │ COMPLETED    │      │ ABANDONED  │
                  └──────────────┘      └────────────┘
```

## 5. Edge Cases

### 5.1 Offline Reception
- Message arrives while offline (push delivered audio link). Audio fetch fails.
- Bubble shows transcript shimmer + "Will transcribe when online." Retry on reconnect.

### 5.2 Audio Cached But Model Missing
- For multilingual: trigger `base` download (with WiFi-only constraint by default).
- Until ready: bubble can use `tiny.en` if message language is English; otherwise wait.

### 5.3 Battery <15%
- On-device disabled; bubble shows "Low battery. Charge to transcribe locally." If fallback opted in, use server.

### 5.4 Long Clip (>90 s)
- Default to server fallback if user opted in. Otherwise on-device with chunking and progress UI.

### 5.5 Phone Goes to Background Mid-Transcription
- Isolate continues if app is in foreground. Background isolates suspend; we resume on foreground.

### 5.6 Whisper Crashes
- Caught at FFI boundary; isolate restarts. After 3 crashes per session for the same model, switch to fallback or alternate model.

### 5.7 Cache Eviction
- Hive box size capped at 200 MB. LRU eviction. Re-transcribed on next view.

### 5.8 User Reactions to Inaccurate Transcripts
- Long-press transcript -> "Report wrong transcript" -> sends opt-in feedback (with audio hash only, no audio) for eval set.

### 5.9 Encryption-At-Rest Audio
- All audio is already AES encrypted by existing media pipeline. Transcript data follows the same key ring.

### 5.10 Sender's Pre-Transcript Is Wrong
- Recipient devices re-run transcription locally if confidence median < 0.55, ignoring sender's transcript.

### 5.11 Two Recipients See Different Transcripts
- Acceptable: each device runs its own engine. Search index uses sender's transcript when present, recipients' otherwise.

### 5.12 Network Partition Mid-Server-Fallback
- Phone retries `GET /api/v1/transcribe/:id` up to 5 minutes. After that, abandon and prompt manual retry.

### 5.13 Code-Switched Language Mid-Clip
- Whisper auto-detects per chunk. Each segment carries its own `lang`. UI renders without flagging.

### 5.14 Hardware-Accelerated Decoding Disabled by OS
- Fall back to CPU. Latency multiplied ~2x; surface "slower than usual" toast on first hit.

## 6. Background Processing Diagram

```mermaid
flowchart LR
  A[New voice msg arrives] --> B{Foreground?}
  B -- yes --> C[Spawn isolate, transcribe immediately]
  B -- no --> D[Queue in TranscribeWorkScheduler]
  D --> E{User opens chat?}
  E -- yes --> F[Drain queue eagerly for visible items]
  E -- no --> G[Tick on next foreground]
```

## 7. Search Indexing Trigger

```mermaid
sequenceDiagram
    participant Phone
    participant API
    participant DB as Postgres

    Phone->>API: POST /api/v1/messages/:id/transcript
    API->>API: validate ownership
    API->>DB: UPDATE messages SET fts = to_tsvector(...) WHERE id = $1
    DB-->>API: ok
    API-->>Phone: 204
```

Indexing only fires for messages the user authored. Recipients' local transcripts are searchable only on the device.
