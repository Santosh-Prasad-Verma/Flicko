# Voice Message Transcription - TRD

## 1. Architecture Overview

```
┌──────────────────────────────────────────────────────────────────────┐
│                            Phone (Flutter)                           │
│                                                                      │
│  ┌──────────────┐    audio bytes    ┌─────────────────────────────┐ │
│  │ VoiceMessage │ ────────────────► │ TranscriptionOrchestrator   │ │
│  │ Bubble       │                   │ (Riverpod)                  │ │
│  └──────────────┘                   └────────────┬────────────────┘ │
│                                                  │                  │
│                                  ┌───────────────┼───────────────┐  │
│                                  ▼               ▼               ▼  │
│                          ┌────────────┐  ┌────────────┐  ┌────────┐ │
│                          │ WhisperFFI │  │ ServerFB   │  │  Cache │ │
│                          │ (on-device)│  │ (HTTP)     │  │ (Hive) │ │
│                          └─────┬──────┘  └──────┬─────┘  └────────┘ │
└────────────────────────────────┼────────────────┼─────────────────────┘
                                 │                │
                          (local CPU)             │ HTTPS multipart
                                                  ▼
                                ┌─────────────────────────────────┐
                                │  Backend (Go)                   │
                                │  POST /api/v1/transcribe        │
                                │   ├ rate limit + auth           │
                                │   ├ enqueue to internal queue   │
                                │   └ whisper.cpp worker (CPU)    │
                                └─────────────────────────────────┘
```

## 2. Components

### 2.1 TranscriptionOrchestrator (Dart, Riverpod)
- Resolves engine choice: on-device first, server fallback after timeout/failure.
- Streams partial transcripts to UI via `StateNotifier`.
- Caches results keyed by audio content hash (xxhash64).

### 2.2 WhisperFFI (Dart FFI)
- Wraps `libwhisper.dylib` / `libwhisper.so` from Whisper.cpp.
- Exposes a single `transcribeChunk(audioPath, modelPath, lang) -> stream of segments`.
- Runs on a background isolate (`Isolate.spawn`) to avoid jank.

### 2.3 ServerFallback Client
- Multipart upload to `POST /api/v1/transcribe`.
- TLS only, JWT auth, 10 MB hard cap (covers 5 min at 16k mono opus).

### 2.4 Backend Transcribe Service (Go)
- Receives upload, enqueues to internal channel-based worker pool (no Redis queue; in-process is enough for this volume).
- Worker shells out to `whisper.cpp` binary built with `make GGML_OPENBLAS=1`.
- Returns transcript JSON synchronously when small (<= 30 s); else returns 202 + polling URL.

### 2.5 Cache
- Hive box `voice_transcripts.box` keyed by `messageId` -> transcript JSON.
- Auto-prune entries older than 30 days for messages no longer visible in chat.

## 3. REST/WS Surface

### 3.1 `POST /api/v1/transcribe`

Multipart fields:
- `audio` - file (opus or wav, <= 10 MB)
- `language` - ISO 639-1 (optional; auto-detect if absent)
- `client_hash` - xxhash64 hex of audio (for idempotency)

Response 200:
```json
{
  "transcript_id": "tr_abc123",
  "lang": "en",
  "segments": [
    {"start_ms": 0,    "end_ms": 1840,  "text": "Hey, are we still on for", "conf": 0.94},
    {"start_ms": 1840, "end_ms": 3120,  "text": "four pm?",                "conf": 0.91}
  ],
  "engine": "whisper.cpp:base.q5_1",
  "took_ms": 1830
}
```

Response 202 (async):
```json
{ "transcript_id": "tr_abc123", "poll_url": "/api/v1/transcribe/tr_abc123" }
```

### 3.2 `GET /api/v1/transcribe/{transcript_id}`
Polling endpoint. Returns 200 with transcript or 202 with `progress_pct`.

### 3.3 `POST /api/v1/messages/:id/transcript` (existing surface, extended)
Persists the transcript text into `messages.fts` for search. Only the user who owns the message can attach.

## 4. Data Flow

### 4.1 Outbound (sender side, optional pre-transcription)
Sender's phone optionally pre-transcribes before send so the recipient sees a transcript instantly. Stored as part of the message envelope when present.

### 4.2 Inbound (recipient side)
1. Voice message renders with shimmer placeholder.
2. Orchestrator looks up cache by `messageId`.
3. On miss, runs Whisper on background isolate.
4. Streams segments to UI; final transcript written to cache.
5. If server fallback used, `messages.fts` is updated by backend at write time.

## 5. NFRs

| Property                                           | Target                                |
|----------------------------------------------------|---------------------------------------|
| Transcription start-to-first-word (on-device)      | < 1.5 s for 14 s clip on Pixel 7      |
| Transcription end-to-end (on-device, 14 s clip)    | < 8 s p95 on Pixel 7 / iPhone 13      |
| Transcription end-to-end (server, 14 s clip)       | < 4 s p95                              |
| WER English (`tiny.en`)                            | <= 14%                                 |
| WER multilingual (`base.q5_1`)                     | <= 22%                                 |
| Battery delta per 10 transcriptions                | <= 0.7%                                |
| Crash-free transcription sessions                  | >= 99.6%                               |
| Cache hit ratio after week 1                       | >= 60%                                 |

## 6. Observability

Telemetry events:
- `transcribe.started` { engine, lang, audio_ms_bucket }
- `transcribe.first_word` { latency_ms_bucket }
- `transcribe.completed` { engine, lang, latency_ms_bucket, char_count_bucket }
- `transcribe.failed` { engine, error_code }
- `transcribe.fallback` { from_engine, to_engine, reason }
- `transcribe.cache_hit` { age_bucket }

Backend metrics (Prometheus):
- `transcribe_request_duration_seconds`
- `transcribe_queue_depth`
- `transcribe_worker_busy_total`

## 7. Security

- All backend endpoints require JWT.
- Rate limit: 30 transcribes/minute/user, 10 MB per request, 100 MB/day/user.
- Audio uploads stored in-memory only on the worker; never written to disk.
- Transcripts persisted only if user explicitly enables fallback or message is theirs.
- We strip metadata (EXIF-like) from audio on upload.

## 8. Failure Modes

| Failure                                       | Behavior                                                |
|-----------------------------------------------|---------------------------------------------------------|
| Whisper.cpp init fails (missing model)        | Trigger model download; show "Preparing transcripts"   |
| FFI crash on isolate                          | Mark device "fallback only" for 24 h                    |
| Server timeout                                | Show "Tap to retry"                                     |
| Audio corrupt                                 | "Couldn't read audio. Play to listen."                 |
| Network offline + no on-device                | Queue locally; retry on reconnect                       |

## 9. Engine Selection Logic

```
1. If cached -> return cache.
2. If WhisperFFI available and audio <= 90 s and battery >= 15% -> on-device.
3. If on-device fails or times out (45 s) -> server fallback (if user opted in).
4. If user opted out of server -> show "Couldn't transcribe. Tap to retry."
```

## 10. Backend Worker Pool

```
- Pool size: GOMAXPROCS / 2, min 2, max 8 per node.
- Each worker holds a long-lived whisper.cpp context with the chosen model loaded.
- Audio re-sampled to 16k mono via libsox before decoding.
- Hot models in memory: tiny.en (~75 MB) and base.q5_1 (~150 MB). Total ~250 MB per worker. Within existing pod memory limits.
```

## 11. Migrations

`145_create_voice_transcripts.up.sql` adds a transcripts table linked to `messages` with FTS column. See SCHEMA.md.
