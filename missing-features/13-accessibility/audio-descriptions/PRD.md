# Audio Descriptions — Product Requirements

> **One-line:** AI-generated alt-text for images with one-tap audio playback and manual override.
> **Status:** Missing — to build
> **Category:** 13-accessibility
> **Effort:** L
> **Priority:** P0
> **Slug:** `audio-descriptions`

## 1. Problem

Discord supports manual alt-text on uploaded images but adoption is dismal: a 2024 community audit found <2% of recent attachments included alt-text. Blind and low-vision users hit endless "image attachment" announcements with no content. WCAG 2.1 SC 1.1.1 (Non-text Content) is unmet at the platform level because the system can't infer descriptions when uploaders skip them.

Modern multimodal LLMs (LLaVA-NeXT, Llama 3.2 Vision, Groq's hosted vision endpoints) can generate accurate, brief image descriptions in under 1 second. Pairing automatic generation with one-tap audio playback (TTS via the OS) gives blind users meaningful context with zero effort from uploaders.

Risks of laziness: people may rely on AI captions instead of writing their own — we keep manual override as the canonical source of truth and clearly mark AI captions as such.

## 2. Users & Use Cases

- **Primary persona:** Asha, blind student (also primary for `screen-reader-full`), follows a meme-heavy server.
- **Secondary personas:**
  - Low-vision users who want context before zooming in
  - Multitaskers who prefer audio
  - Auditors checking alt-text coverage
- **Top jobs-to-be-done:**
  1. As a blind user, I want to hear what's in an image when I tap "describe", so that I can follow the conversation.
  2. As an uploader, I want a suggested alt-text I can edit, so that I'm not gating accessibility on my willingness to type.
  3. As a moderator, I want bulk alt-text coverage stats, so that I know if my server is welcoming to blind users.

## 3. Goals & Non-Goals

**Goals**
- AI alt-text for images uploaded after launch and (lazily) for images opened by an AT-using viewer.
- Per-image audio playback button (uses system TTS).
- Author-supplied alt-text takes precedence; AI provides fallback.
- Cache descriptions by image content hash to avoid re-billing.
- Cost ceiling: <$0.01 per active screen-reader user per day.

**Non-Goals (out of scope for v1)**
- Video description (separate feature `captions-voice-video` covers spoken captions; video descriptive audio is post-v1).
- GIF frame-by-frame description (we describe the first frame).
- OCR-only mode — we describe AND OCR-quote any clear text.
- Sign language video output.

## 4. Scope (v1)

- [ ] Backend service `audio_desc` calling vision LLM (LLaVA via Ollama in dev; Groq vision in prod) on attachment upload.
- [ ] Async fan-out via NATS so chat send latency doesn't change.
- [ ] Cache table `audio_desc_cache` keyed by image SHA-256.
- [ ] Manual alt-text field on attachment upload UI.
- [ ] Mobile UI: long-press image → "Describe" → audio plays via TTS.
- [ ] Settings: per-user "Auto-describe images on focus" toggle.
- [ ] Moderator dashboard: server alt-text coverage %.

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| % images with alt-text (manual or AI) | ≥95% within 30d | nightly job over `attachments` |
| Median description latency (upload → ready) | <2.5 s | server trace |
| Audio playback acceptance rate | ≥60% (users who play once and play again next session) | client telemetry |
| Cost per AT-using user/day | <$0.005 | Groq + cache stats |
| Hallucination rate (manual sample) | <3% | weekly QA sample, n=50 |

## 6. Open Questions / Risks

- Privacy: images may contain PII (faces, IDs); we never log raw image bytes, only SHA-256 + truncated description.
- Hallucination: vision LLMs sometimes invent details; we keep responses short and low-temperature.
- Languages: v1 English only. Locale-routing planned with `14-localization`.
- NSFW content: we run an NSFW check first; if positive we skip the LLM and produce "Not safe for work image; tap to view".

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord | Manual alt-text, low adoption | Auto-generated baseline + manual override |
| Slack | None native | Out-of-the-box AI alt-text |
| iMessage | OS-level VoiceOver "describe image" | We integrate inside the chat |
| Be My Eyes | Human + GPT-4V | Server-native, no app switch |

## 8. Rollout

- Internal dogfood (small server) → 5% of servers behind flag → 25% → GA.
- Kill switch flag: `feature.audio_descriptions.enabled` (default OFF; staged ON per server).
- Cost controls: per-server daily LLM call cap; user-level rate limits.
