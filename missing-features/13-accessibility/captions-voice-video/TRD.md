# Captions for Voice/Video — Technical Requirements

## 1. Architecture Overview

```
┌────────────────────────────────────────────────────────────────────┐
│ Speaker (Mobile)                                                   │
│   mic → SFU (Azure ACS/Janus) → audio frames                        │
└────────────────────────────────────────────────────────────────────┘
                                │
                                ▼
┌────────────────────────────────────────────────────────────────────┐
│ Backend                                                            │
│  SFU                                                               │
│    │ tap audio                                                     │
│    ▼                                                               │
│  ┌────────────────────────────┐                                   │
│  │ caption_pipeline (Go)       │                                   │
│  │  - VAD                      │                                   │
│  │  - chunk 800-1200ms         │                                   │
│  │  - send to ASR              │                                   │
│  └──────────────┬──────────────┘                                  │
│                 │                                                  │
│                 ▼                                                  │
│   ┌──────────────────────────────────────┐                        │
│   │ ASR backend (Whisper streaming on    │                        │
│   │ Groq for prod; faster-whisper local  │                        │
│   │ for dev)                              │                        │
│   └──────────────┬───────────────────────┘                        │
│                  │ partials + finals                               │
│                  ▼                                                 │
│   ┌──────────────────────────────────────┐                        │
│   │ caption_publisher                    │                        │
│   │   publishes to                        │                        │
│   │   centrifugo voice:<id>:captions     │                        │
│   └──────────────┬───────────────────────┘                        │
└──────────────────┼───────────────────────────────────────────────┘
                   │ WebSocket
                   ▼
┌────────────────────────────────────────────────────────────────────┐
│ Listener (Mobile)                                                  │
│   captions_provider.dart  → CaptionsOverlayWidget                  │
│   + speaker_palette.dart  → per-speaker colour                    │
│   + srt_exporter.dart     → end-of-call export                    │
└────────────────────────────────────────────────────────────────────┘
```

## 2. Components

### Backend (Go)
- **Service:** `backend/internal/services/accessibility/captions/service.go` (orchestrator)
- **Pipeline:** `backend/internal/services/accessibility/captions/pipeline.go` (VAD + chunking)
- **ASR client:** `backend/internal/services/ai/asr/streaming_client.go` (Groq + faster-whisper backends)
- **Publisher:** `backend/internal/services/accessibility/captions/publisher.go` (Centrifugo)
- **Handlers:** `backend/internal/handlers/accessibility/captions_handler.go`
  - `GET /api/v1/voice/:channel_id/captions` — fetch buffered captions for the current call
  - `GET /api/v1/voice/:channel_id/captions.srt` — SRT export (host only)
  - `PATCH /api/v1/users/me/preferences` — caption prefs (existing)
  - `POST /api/v1/voice/:channel_id/captions/consent` — per-call consent toggle

### Mobile (Flutter)
- **Feature folder:** `mobile/lib/features/accessibility/captions/`
  - `data/captions_repository.dart`, `dto/caption_segment.dart`
  - `domain/caption_segment.dart`, `caption_speaker.dart`
  - `application/captions_provider.dart`, `speaker_palette_provider.dart`
  - `presentation/widgets/captions_overlay.dart`
  - `presentation/widgets/caption_position_picker.dart`
  - `presentation/widgets/caption_size_picker.dart`
  - `presentation/screens/captions_settings_screen.dart`
  - `application/srt_exporter.dart`
- **Cross-cutting edits:**
  - `mobile/lib/features/voice/.../voice_call_screen.dart` — overlay captions widget
  - `mobile/lib/features/voice/.../voice_controls_bar.dart` — captions toggle button
  - `mobile/lib/features/calling/.../video_call_screen.dart` — same overlay

### Infra
- DB:
  - New table `caption_segments` (only when consent is given) with TTL purge.
  - New table `caption_consents` (per-call consent ledger).
- Realtime: Centrifugo channel `voice:<channel_id>:captions`.
- Cache: Redis stream `caption:<channel_id>` (in-memory rolling buffer for live, 30 min retention).
- Storage: Appwrite bucket `captions` for SRT exports (auth gated; 30-day TTL).
- AI:
  - Prod: Groq Whisper-large-v3 streaming
  - Dev: faster-whisper local
- Queue: NATS subject `flicko.captions.*` for async ingestion.

## 3. API Contracts

### REST
```
GET    /api/v1/voice/:channel_id/captions            buffered for active call
GET    /api/v1/voice/:channel_id/captions.srt        SRT export (host)
POST   /api/v1/voice/:channel_id/captions/consent    {consent: true/false}
PATCH  /api/v1/users/me/preferences                  caption prefs
```

### Centrifugo
- Channel: `voice:<channel_id>:captions`
- Events:
  - `caption.partial` { speaker_id, text, t_start_ms, t_end_ms, segment_id, is_final: false }
  - `caption.final`   { speaker_id, text, t_start_ms, t_end_ms, segment_id, is_final: true }

### Payloads
```jsonc
// SRT export sample
"00:00:01,200 --> 00:00:04,750\n[Devon] Welcome everyone, let's start.\n\n"

// Caption preferences
{
  "accessibility": {
    "captions_enabled": true,
    "captions_size": "medium",            // small | medium | large
    "captions_position": "bottom",        // top | center | bottom
    "captions_opacity": 0.85,             // 0.5 - 1.0
    "captions_per_speaker_color": true,
    "captions_language": "en"
  }
}
```

## 4. Permissions & Auth

- Read live captions: any user in the voice channel.
- Toggle for self: any user.
- Enable for server: server admin role.
- SRT export: call host or server admin.
- Consent: every speaker must have at least implicit consent (host announces "captions on") before persistence; otherwise stream is volatile.

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| End-to-end caption latency p50 | <1.5 s |
| End-to-end caption latency p99 | <3.5 s |
| WER on benchmark | <8% |
| Throughput per pod | 50 concurrent voice channels |
| Availability | 99.5% (best-effort; voice keeps working without captions) |
| Cost per voice-minute | <$0.0006 (Groq) |

## 6. Dependencies

- Existing services: `voice_service` (Azure ACS/Janus SFU), `centrifugo`, `nats_publisher`, `safety_service` (PII redaction).
- New backend: ASR streaming client.
- External APIs: Groq Whisper streaming.
- Mobile package: existing `web_socket_channel`.

## 7. Observability

- Metrics:
  - `flicko_captions_latency_seconds` histogram (per-segment)
  - `flicko_captions_wer_gauge` (rolling 1h)
  - `flicko_captions_cost_dollars_total{backend}`
  - `flicko_captions_active_channels_gauge`
- Logs: structured `captions.{channel_id, segment_id, speaker_id}`.
- Traces: OTel span `captions.publish` per finalized segment.
- Dashboards: Grafana board `captions-live`.

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| ASR backend down | No captions | Fallback to faster-whisper local; circuit-breaker; UI "Captions paused" |
| WebSocket disconnect | Stale captions | Auto-reconnect with last seq; show "reconnecting" pill |
| WER high in noisy env | Bad UX | Show partial+final clearly; user can disable |
| Speaker palette collision | Hard to tell apart | After 8 speakers, palette repeats with stripe pattern |
| Consent missing | Privacy violation | Drop persistence; in-memory only |
| Late finals overwrite finals | Caption flicker | Use stable segment_id; deduped on client |

## 9. Privacy & Consent

- Captions process audio in real time but persistence requires consent recorded in `caption_consents`.
- Without consent, only ephemeral captions are pushed via Centrifugo (no DB write).
- Server admin can disable captions for their server entirely.
- SRT exports are tagged with consent ledger.

## 10. Migration Path

- v0 → v1: ship English-only Groq backend; per-server opt-in.
- v1 → v2: Spanish + Hindi via Whisper-large-v3; translation hop optional.
- v1 → v3: speaker diarization for guest users.
