# Live Voice Captions — Whisper.cpp Transcription — Technical Requirements

## 1. Architecture Overview

```
   ┌────────────────────────────────────────────────────────────┐
   │  LiveKit / SFU (existing voice infra)                     │
   │  per-participant track => RTP G.711/Opus                  │
   └─────────────┬──────────────────────────────────────────────┘
                 │
                 ▼  Track Egress  (per-track raw PCM 16kHz)
   ┌────────────────────────────────────────────────────────────┐
   │  Caption worker (Go):                                      │
   │  voice_transcription/worker.go                             │
   │                                                            │
   │  per (channel, speaker):                                   │
   │    1. PCM frames (20ms) -> ringbuffer                      │
   │    2. silero-vad -> speech segments                        │
   │    3. on segment >= 200ms or 1.5s rolling:                 │
   │         submit to whisper.cpp pool                         │
   │    4. whisper => tokens                                    │
   │    5. publish Centrifugo voice_captions:<channel_id>       │
   │    6. append voice_transcripts                             │
   └─────────────┬──────────────────────────────────────────────┘
                 │
                 ▼
       Centrifugo  ── client subscribers ──▶  Flutter overlay
```

Pipeline:

```
[PCM 16kHz] → [VAD] → [segment 200ms..15s] → [whisper.cpp small/tiny] → [text]
                                                       ↓
                                                 [Centrifugo + DB]
```

## 2. Components

### Backend (Go)
- `backend/internal/services/ai/voice_transcription/worker.go` — long-lived per-channel worker
- `backend/internal/services/ai/voice_transcription/vad.go` — silero-vad ONNX runtime via `github.com/yalue/onnxruntime_go`
- `backend/internal/services/ai/voice_transcription/whisper_pool.go` — worker pool wrapping `whisper.cpp` via cgo (`github.com/mutablelogic/go-whisper` or homegrown bindings)
- `backend/internal/services/ai/voice_transcription/segmenter.go` — utterance assembly
- `backend/internal/services/ai/voice_transcription/publisher.go` — Centrifugo publish + Postgres append
- `backend/internal/services/ai/voice_transcription/livekit_egress.go` — connects as Egress sink
- `backend/internal/handlers/ai_captions_handler.go` — REST: enable/disable, get transcript
- `backend/internal/models/voice_transcript.go`
- `backend/internal/repo/voice_transcript_repo.go`
- Models on disk:
  - `models/whisper-small.en.bin` (488MB)
  - `models/whisper-tiny.en.bin` (75MB)
  - `models/whisper-small.bin` multilingual (488MB)
  - `models/silero-vad.onnx` (1.7MB)

### Mobile (Flutter)
- `mobile/lib/features/ai_assistant/captions/data/captions_repository.dart`
- `mobile/lib/features/ai_assistant/captions/data/captions_centrifugo_client.dart`
- `mobile/lib/features/ai_assistant/captions/domain/caption.dart`
- `mobile/lib/features/ai_assistant/captions/application/captions_provider.dart`
- `mobile/lib/features/ai_assistant/captions/presentation/captions_overlay.dart`
- `mobile/lib/features/ai_assistant/captions/presentation/captions_settings_sheet.dart`
- Hook into existing `voice_channel_screen.dart`

### Infra
- DB: Supabase Postgres (migration `133`)
- Realtime: Centrifugo channel `voice_captions:<channel_id>`
- Cache: Redis `captions:rolling:<channel_id>` (last 30 lines, TTL 5m)
- AI: Whisper.cpp + silero-vad (CPU only, no GPU needed for `tiny` and `small`)
- Queue: NATS `flicko.ai.captions.session.{started,ended}`
- Storage: R2 archive `flicko-archive/transcripts/<yyyymm>/<channel_id>.parquet`

## 3. API Contracts

### REST

```
POST /api/v1/ai/captions/channels/:id/enable     (admin)
POST /api/v1/ai/captions/channels/:id/disable    (admin)
GET  /api/v1/ai/captions/channels/:id/state      { enabled, model, language }
GET  /api/v1/ai/captions/sessions/:session_id    paginated transcript
GET  /api/v1/ai/captions/sessions/:session_id/export.txt
```

### Centrifugo

- Channel: `voice_captions:<channel_id>`
- Events:
  - `caption.partial` `{ speaker_user_id, t_start_ms, text, is_final:false }`
  - `caption.final`   `{ ..., is_final:true, segment_id }`
  - `caption.error`   `{ code, msg }`

### Payload example
```jsonc
{
  "session_id": "uuid",
  "speaker_user_id": "uuid",
  "speaker_name": "alice",
  "t_start_ms": 124300,
  "t_end_ms":   125860,
  "text": "did anyone see the keynote",
  "is_final": true,
  "confidence": 0.91,
  "language": "en"
}
```

## 4. Permissions & Auth

- Required: voice channel member
- Admin-only: enable/disable feature per channel
- RLS on `voice_transcripts`: members of the channel server can read
- Centrifugo subscription token includes `channel_id` claim and is server-issued only to members

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| Caption end-to-end latency p95 | <2s (utterance end → mobile render) |
| Word Error Rate (en, clean audio) | <12% |
| Throughput per node | 32 concurrent voice channels (small.en) or 128 (tiny.en) |
| Availability | 99.5% |
| Cost per voice-minute | $0 (CPU on existing nodes) |
| Memory per worker | <600 MB |
| CPU per channel (small.en) | ~0.4 core average |

## 6. Dependencies

- LiveKit Egress already deployed
- Centrifugo already deployed
- New libs:
  - Go: `github.com/yalue/onnxruntime_go v1.16.x` (silero), custom whisper.cpp cgo wrapper
  - C: `whisper.cpp` v1.7.x compiled with AVX2/F16C
- External: none; fully self-hosted

## 7. Observability

- Metrics:
  - `flicko_ai_voice_transcription_active_channels` gauge
  - `flicko_ai_voice_transcription_latency_seconds` histogram (p50, p95)
  - `flicko_ai_voice_transcription_segment_duration_seconds` histogram
  - `flicko_ai_voice_transcription_wer_estimate` (sampled)
  - `flicko_ai_voice_transcription_whisper_inference_seconds`
  - `flicko_ai_voice_transcription_cpu_load` per worker
  - `flicko_ai_voice_transcription_dropped_segments_total` (overload)
- Logs: per-segment `session_id, speaker, t_start_ms, t_end_ms, conf, text_sha256`
- Traces: `captions.segment → captions.whisper → captions.publish`

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| Whisper queue saturated | dropped captions | scale worker pool; downgrade to `tiny.en`; show "captions degraded" banner |
| LiveKit Egress disconnect | captions stop | reconnect with backoff; backfill transcript from rolling buffer |
| ONNX init fail | VAD broken | fallback to RMS-energy VAD (lossy but functional) |
| Speaker switch mid-segment | mis-attribution | per-track isolation prevents this; verified in tests |
| User on slow network | partial captions | client buffers `partial` events and replaces on `final` |
| Channel idle (no speech) | no captions ok | worker idles at 1mW; no spam |
| Unsupported language | poor quality | language-detect first 10s → switch model `multilingual` |
| User leaves voice mid-utterance | dangling partial | finalize on disconnect with timestamp |
