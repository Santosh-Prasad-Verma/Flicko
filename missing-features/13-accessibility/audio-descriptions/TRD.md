# Audio Descriptions — Technical Requirements

## 1. Architecture Overview

```
┌──────────────┐    upload     ┌─────────────────┐
│ Mobile (Flt) │──────────────>│ Go API (gateway)│
└──────────────┘   POST /attach└────────┬────────┘
       ▲                                │
       │                                ▼
       │                       ┌────────────────┐
       │                       │ NATS subject   │
       │                       │ flicko.audio_  │
       │                       │ desc.requested │
       │                       └────────┬───────┘
       │                                ▼
       │                       ┌────────────────┐
       │                       │ Worker         │
       │                       │ audio_desc/    │
       │                       │ worker.go      │
       │                       └────────┬───────┘
       │                                ▼
       │              ┌─────────────────┴────────────────┐
       │              │                                   │
       │              ▼                                   ▼
       │     ┌─────────────────┐               ┌──────────────────┐
       │     │ NSFW filter     │               │ Cache lookup     │
       │     │ (nsfwjs/svc)    │               │ (Redis + table)  │
       │     └────────┬────────┘               └────────┬─────────┘
       │              │ safe                             │ hit
       │              ▼                                  │
       │     ┌─────────────────┐                         │
       │     │ Vision LLM      │                         │
       │     │ (Groq /         │                         │
       │     │  Ollama LLaVA)  │                         │
       │     └────────┬────────┘                         │
       │              ▼                                  ▼
       │     ┌────────────────────────────────────────┐
       │     │ Save to audio_desc_cache + attachments │
       │     │ Publish via Centrifugo channel          │
       │     │ attachment:<id>                         │
       │     └────────┬────────────────────────────────┘
       └────────────  │ realtime push
                      ▼
              ┌─────────────────┐
              │ Mobile updates  │
              │ alt-text state  │
              └─────────────────┘
```

## 2. Components

### Backend (Go)
- **Service:** `backend/internal/services/accessibility/audio_desc/service.go`
- **Worker:** `backend/internal/services/accessibility/audio_desc/worker.go`
- **NSFW filter:** `backend/internal/services/accessibility/audio_desc/nsfw.go` (wraps existing `safety_service.go`)
- **Vision client:** `backend/internal/services/ai/vision/client.go` (Groq + Ollama backends)
- **Handlers:** `backend/internal/handlers/accessibility/audio_desc_handler.go`
  - `GET /api/v1/attachments/:id/description` — read latest description (manual + ai)
  - `PATCH /api/v1/attachments/:id/description` — author overrides
  - `POST /api/v1/attachments/:id/describe` — explicit re-run (rate-limited, owner-only)
- **Models:** `backend/internal/models/audio_desc.go`
- **Repo:** `backend/internal/repo/audio_desc_repo.go`
- **Prompt template:** `backend/internal/services/accessibility/audio_desc/prompts/v1.txt`

### Mobile (Flutter)
- **Feature folder:** `mobile/lib/features/accessibility/audio_descriptions/`
  - `data/audio_desc_repository.dart`, `audio_desc_dto.dart`, `audio_desc_datasource.dart`
  - `domain/audio_description.dart`, `audio_desc_source.dart` (manual | ai)
  - `application/audio_desc_provider.dart`, `tts_player_controller.dart`
  - `presentation/widgets/describe_button.dart` — appears on long-press of an image
  - `presentation/widgets/alt_text_editor.dart` — used in upload sheet
  - `presentation/widgets/audio_desc_inline_banner.dart` — shows description text + play button
- **Cross-cutting edits:**
  - `mobile/lib/features/server_channels/.../message_attachment.dart` — wire up describe button + alt-text
  - `mobile/lib/features/server_channels/.../upload_sheet.dart` — alt-text field
- **TTS:** uses `flutter_tts` package (existing in project) for system TTS playback.

### Infra
- DB: new table `audio_desc_cache` (see SCHEMA.md), new columns on `attachments`.
- Realtime: Centrifugo channel `attachment:<id>` for description-ready events.
- Cache: Redis `audio_desc:<sha256>` (TTL 30 days).
- Storage: existing Appwrite bucket — no changes.
- AI:
  - Dev: Ollama LLaVA-NeXT-7B local
  - Prod: Groq vision endpoint (Llama 3.2 11B Vision)
- Queue: NATS subject `flicko.audio_desc.*`.

## 3. API Contracts

### REST
```
GET    /api/v1/attachments/:id/description       fetch description
PATCH  /api/v1/attachments/:id/description       author override
POST   /api/v1/attachments/:id/describe          force re-run (admin/owner)
```

### Centrifugo
- Channel: `attachment:<attachment_id>`
- Event: `audio_desc.ready` payload `{ attachment_id, text, source, language, generated_at }`

### Payloads
```jsonc
// GET response
{
  "attachment_id": "uuid",
  "text": "A black cat sitting on a window sill in afternoon light",
  "source": "ai",                 // "ai" | "manual" | "ai_then_manual"
  "language": "en",
  "ocr": null,
  "nsfw": false,
  "generated_at": "2026-05-29T12:34:56Z",
  "model": "llama-3.2-11b-vision",
  "model_version": "2024-11-01"
}

// PATCH request
{ "text": "A black cat named Pixel asleep in the sunlight." }
```

## 4. Permissions & Auth

- Read: any user with access to the parent message channel.
- Write (manual override): attachment owner OR channel admin.
- Re-run: owner OR server admin; rate-limited 3/hour.

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| p50 description latency | <1.5 s |
| p99 description latency | <4 s |
| Throughput | 100 images/min/instance |
| Availability | 99.5% (best-effort; chat is unblocked) |
| Cost per call | <$0.0008 (Groq) |
| Cache hit ratio | >70% server-wide |
| Max image size processed | 4 MB (resized to 1280px before send) |

## 6. Dependencies

- Existing: `attachment_service`, `safety_service` (NSFW), `nats_publisher`, `centrifugo`.
- New backend: `vision_client` Go module.
- External APIs: Groq vision (with retry + circuit-breaker via `gobreaker`).

## 7. Observability

- Metrics:
  - `flicko_audio_desc_requests_total{result="generated|cache|nsfw|error"}`
  - `flicko_audio_desc_latency_seconds` histogram
  - `flicko_audio_desc_cost_dollars_total`
  - `flicko_audio_desc_cache_hit_ratio` gauge
- Logs: structured `audio_desc.{request_id, attachment_id, source}`.
- Traces: OTel span `audio_desc.generate` wrapping NSFW + LLM + cache write.
- Dashboards: Grafana board `audio-descriptions`.

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| Vision LLM down | No new descriptions | Cache + fallback "Image; no description available"; circuit-breaker |
| LLM hallucinates | Wrong description | Author override; report-error link |
| NSFW false negative | Bad description served | Manual override; human review queue |
| NATS lag | Delayed description | UI shows "Generating…" placeholder; SLA <10s |
| Cost spike | Over-budget | Per-server daily quota; degrade to "no description" |
| Cache poisoning | Wrong description served indefinitely | Cache invalidation on author override; admin "purge" |

## 9. Prompt Template (v1)

```
You are an accessibility assistant. In one short sentence (<=140 chars),
describe what is visible in this image. Be concrete and specific. Do not
guess names, brands, or text you can't read clearly. If text is visible
and legible, quote it inside double quotes after the sentence.

Avoid:
- Speculation about emotions, intent, or context outside the frame
- Mentioning that this is an image
- Generic phrases like "this image shows"
```

Temperature 0.2; max_tokens 80; system prompt cached on Groq.

## 10. Migration Path

- v0 → v1: NSFW first, then optional LLM. Manual override always wins.
- v1 → v2: add per-language generation; expose alt-text in OpenGraph for shared links.
