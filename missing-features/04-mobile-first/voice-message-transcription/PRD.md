# Voice Message Transcription - PRD

## 1. Summary

Every voice message in Flicko gets a fast, accurate transcript. Transcription runs on-device using Whisper.cpp (via Dart FFI) by default, falling back to a private backend endpoint when on-device inference fails or the device lacks the capacity. Transcripts are searchable, copyable, and accessible to users on the move, hard-of-hearing users, and users in noisy or quiet environments where audio playback isn't viable.

## 2. Problem

Voice messages are fast to send and slow to consume. Users skip them in meetings, can't search them later, and screen-readers cannot navigate them. Transcribing on someone else's server compromises privacy and adds cost. Doing it on-device with off-the-shelf APIs is sluggish and inaccurate. We need accurate transcripts (>90% WER on common languages) without leaking audio to third parties.

## 3. Jobs to Be Done

- **JTBD-1** When I can't listen, I want to read the voice note transcript fast so I don't miss the message.
- **JTBD-2** When I'm searching old conversations, I want voice notes to be findable by their text content.
- **JTBD-3** When I'm hard of hearing, I want a captioned transcript that scrolls in sync with playback.
- **JTBD-4** When my phone is old, I want transcripts to still appear, even if it takes a few seconds longer.
- **JTBD-5** When the speaker code-switches between languages, I want a transcript that captures both.

## 4. Scope

### In Scope (v1)
- On-device transcription via Whisper.cpp (`ggml-tiny.en` for English-only, `ggml-base.q5_1` for multilingual; user-selected model).
- Server fallback `POST /api/v1/transcribe` for unsupported devices or oversized clips.
- Streaming-style word-by-word render for clips >10 s.
- Inline transcript view under voice message bubble.
- Tap-to-play with synchronized highlight.
- Copy and share-as-text.
- Search index integration: transcripts feed the existing Postgres `messages.fts` column.
- Languages: English, Hindi, Spanish, French, Japanese, Portuguese-BR (multilingual base model).

### Out of Scope (v1)
- Speaker diarization.
- Live caption during voice channel calls.
- Custom vocabulary upload.
- Translation; transcript matches source language only.
- Uploading the transcript to other users' devices when they're offline (we recompute per-device).

## 5. Numeric Success Metrics

| Metric                                       | Target                       | Source                    |
|----------------------------------------------|------------------------------|---------------------------|
| Voice messages transcribed                   | 96% within 8 s of receipt    | telemetry                 |
| Word Error Rate (English, on `tiny.en`)      | <= 14%                       | LibriSpeech-test-clean eval |
| Word Error Rate (multilingual, `base`)       | <= 22%                       | Common Voice eval         |
| Voice-message search hits per WAU            | +35% vs pre-launch baseline  | analytics                 |

## 6. Competitive Landscape

| App        | On-device | Server | Languages | Search | Playback sync |
|------------|-----------|--------|-----------|--------|---------------|
| WhatsApp   | Yes (en, es, ru, hi, pt) | -    | 5+    | No     | No            |
| Telegram   | Premium tier (server) | Yes  | many  | Yes    | No            |
| iMessage   | Yes (Live Voicemail era) | -   | en mostly | No  | No            |
| Discord    | -         | -      | -         | No     | No            |
| Slack      | -         | Yes (paid) | English | Yes  | No            |
| **Flicko** | **Yes (Whisper.cpp)** | Yes (fallback) | 6 | Yes | Yes |

Whisper-grade quality with privacy and search-from-day-one is the differentiator.

## 7. Non-Goals

- We will not run transcripts through an LLM for summarization in v1.
- We will not stream partial transcripts before the audio finishes uploading.
- We will not expose a "delete transcript but keep audio" toggle (binds them).

## 8. Assumptions

- Median voice message length is 14 seconds (from analytics). 95th percentile is 90 seconds.
- Most voice messages target English or one supported language.
- Devices with >= 4 GB RAM can run `ggml-base.q5_1` (~150 MB) without OOM.
- Backend fallback usage will be < 12% of clips at steady state.

## 9. Constraints

- **Privacy**: Audio leaves the device only when the user explicitly opts in to fallback, or when on-device fails after retries.
- **Cost**: $0 third-party. Whisper.cpp is OSS (MIT). Backend fallback uses self-hosted whisper.cpp on a CPU-only worker; fits in existing Go services budget.
- **Engineering**: 1 mobile + 0.5 backend + 0.25 ML eng for evals.

## 10. Risks

- **R1**: Whisper.cpp FFI surface incompatibility on iOS Simulator / Android x86 emulators. Mitigation: dual-architecture binaries, host-arch detection, and a fallback engine for emulator-only.
- **R2**: Battery drain on long messages. Mitigation: chunked decoding with throttling under low-battery.
- **R3**: Slow first-launch (model not yet downloaded). Mitigation: bundle `tiny.en` int8 (~75 MB) inside the app; download `base` lazily.
- **R4**: Transcripts misrepresent speaker intent. Mitigation: surface confidence and "may be inaccurate" footer, never auto-translate.
