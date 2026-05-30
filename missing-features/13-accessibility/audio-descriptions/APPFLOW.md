# Audio Descriptions — App Flow

## 1. End-to-End Journey

```mermaid
sequenceDiagram
    participant U as Uploader
    participant V as Viewer (TalkBack)
    participant M as Mobile
    participant API as Go API
    participant N as NATS
    participant W as Worker
    participant SF as Safety/NSFW
    participant LLM as Vision LLM
    participant DB as Supabase
    participant RT as Centrifugo

    U->>M: pick image, optional alt-text "Pixel sleeping"
    M->>API: POST /attachments (upload + manual_alt)
    API->>DB: insert attachment(record, manual_alt)
    API->>N: publish flicko.audio_desc.requested
    API-->>M: 200 attachment_id
    N-->>W: receive job
    W->>SF: NSFW check
    SF-->>W: safe
    W->>DB: cache lookup by sha256 (miss)
    W->>LLM: vision call (image + prompt)
    LLM-->>W: "A black cat sleeping on…"
    W->>DB: insert audio_desc_cache + update attachments.ai_alt
    W->>RT: publish attachment:<id> {audio_desc.ready}
    RT-->>V: realtime push
    V->>M: focus image; long-press "Describe"
    M->>API: GET /attachments/:id/description
    API-->>M: { text, source: "ai_then_manual" }
    M-->>V: render text + play TTS
```

## 2. State Machine

```
[uploaded]
   │ NATS pub
   ▼
[queued]
   │ NSFW check
   ▼
[safe-checking] -- nsfw --> [nsfw-fallback]
[safe-checking] -- safe ---> [llm-running]
[llm-running] -- ok ------>  [ready]
[llm-running] -- fail ----> [error]
[error] -- retry --> [llm-running]
[ready] -- author edit --> [author-overridden]
```

## 3. User Journeys

### J1 — Happy path: blind viewer hears auto-description
1. Asha receives a message with an image.
2. The screen reader announces "Image attachment, button. Description pending."
3. Within 1.5 s the realtime channel pushes `audio_desc.ready` and the announcement updates: "Description: A black cat sitting on a window sill."
4. Asha long-presses, taps "Listen", TTS reads aloud.

### J2 — Author writes alt-text before upload
1. Sighted uploader pastes an image; the upload sheet shows "Suggested by AI" pre-filled.
2. They tap Edit, change to "My cat Pixel napping at golden hour".
3. Upload completes; manual_alt is saved; AI fallback is also stored as backup.

### J3 — Author corrects a hallucination
1. Worker generated "A small dog playing in snow" but the image is a cat.
2. Author taps Edit, types "A cat sitting in front of a TV showing a snow scene".
3. PATCH /description updates `manual_alt`; description source becomes "ai_then_manual".
4. Cache is preserved; manual override takes precedence on read.

### J4 — NSFW image
1. Uploader sends an image flagged NSFW.
2. NSFW filter returns positive.
3. Worker writes "Not safe for work image. Tap to view." into `ai_alt`.
4. UI shows blurred preview with the safe fallback text.

### J5 — Vision LLM down
1. Worker fails after 3 retries.
2. Description set to status `error`.
3. UI shows "Couldn't describe this image. Tap to retry."
4. Author can re-run via long-press → "Try again".

## 4. Edge Cases

- **Animated GIF:** describe first frame; note "(animated)" in description.
- **Image with text:** OCR portion appended in quotes; description first.
- **Re-uploaded image (same hash):** instant cache hit; no LLM cost.
- **Multi-image message:** describe each; UI groups by carousel index.
- **DM:** descriptions stored same way; visibility scoped to participants.
- **Server quota exhausted:** new uploads return manual_alt only; UI badge says "AI quota reached".

## 5. Background / Async

- Triggered by: `attachments.created` event published to NATS.
- Schedule: realtime worker pool (no cron).
- Idempotency key: `audio_desc:<sha256>`.
- Failure policy: retry 3× with exponential backoff (1s, 5s, 25s), then DLQ.
- Concurrency: 8 workers per pod; rate-limited per server.

## 6. Notifications

- No push notifications introduced.
- Realtime push to clients only on description ready.

## 7. Cross-Feature Interactions

- With **screen-reader-full**: live region announces the description as soon as it's ready.
- With **captions-voice-video**: shares TTS provider configuration; settings live in same Accessibility section.
- With **moderation/automod**: NSFW check reuses existing pipeline.
- With **ai-image-search** (future): cache embedded vector beside text description.

## 8. Telemetry Events

- `audio_desc.requested`
- `audio_desc.generated` { latency_ms, model }
- `audio_desc.cache_hit`
- `audio_desc.author_overrode`
- `audio_desc.played` { source, duration_ms }
- `audio_desc.reported` { reason }

## 9. Failure Recovery

- Stuck "generating" job (> 60 s) is reaped by a janitor cron and marked `error`.
- Author override is always allowed regardless of state.
- Force re-run endpoint clears cache row and re-publishes the NATS job.
