# Captions for Voice/Video — Product Requirements

> **One-line:** Live captions in voice/video calls with per-speaker color and SRT export.
> **Status:** Missing — to build
> **Category:** 13-accessibility
> **Effort:** XL
> **Priority:** P0
> **Slug:** `captions-voice-video`

## 1. Problem

WCAG 2.1 SC 1.2.4 (Captions, Live) requires synchronized captions for live audio in synchronized media. Discord recently rolled out limited voice captions but they are English-only, not customisable, and disappear after the call ends. There is no per-speaker colour, no resizing, no positioning, and no export. Deaf and hard-of-hearing users (estimated 5% of users in noisy environments alone, plus the ~2% of permanently HoH users globally) cannot fully participate in voice channels or live streams.

This feature is a force multiplier: it improves accessibility AND helps in noisy environments, while studying, when listening on speaker, and when on slow connections.

We share infrastructure with the existing `ai-voice-transcription` feature: WebSocket transcript stream from Whisper-streaming server. Captions reuse that stream for rendering.

## 2. Users & Use Cases

- **Primary persona:** Devon, late-deafened user, joins voice channels for community standups.
- **Secondary personas:**
  - Hearing users in loud environments (cafes, trains)
  - Multilingual users following English-spoken meetings as ESL learners
  - Note-takers who want a transcript export
  - Compliance officers needing meeting records
- **Top jobs-to-be-done:**
  1. As a deaf user, I want live captions during voice and video calls, so that I can follow conversations.
  2. As a host, I want the captions to differentiate speakers by colour, so that participants don't lose track of who said what.
  3. As a note-taker, I want to export the captions as an SRT file at end of call, so that I can attach them to the meeting recap.

## 3. Goals & Non-Goals

**Goals**
- Live captions overlay rendered on top of voice/video tile.
- Per-speaker color (deterministic hash of `user_id` mapped to a safe palette).
- User can resize (3 sizes) and reposition (top/center/bottom) the caption pane.
- SRT export at end of call (gated by host permission).
- Realtime via the existing `ai-voice-transcription` WebSocket stream.
- ≤2-second median caption latency.
- Languages: English at GA; Spanish + Hindi at +30d.

**Non-Goals (out of scope for v1)**
- Translation (post-v1; uses same stream + LLM translate hop).
- Speaker identification beyond Discord-known users (no diarization on third-party audio).
- Permanent recording (separate compliance feature).
- Sign language video output.

## 4. Scope (v1)

- [ ] Captions overlay widget consumable in voice/video tiles.
- [ ] WebSocket subscription to `voice:<channel_id>:captions`.
- [ ] Per-speaker colour mapping (deterministic + override).
- [ ] User settings: enable, font size, position, language, opacity.
- [ ] SRT export endpoint and "Export captions" button at end of call.
- [ ] Privacy: captions only stored if at least one participant has consented; otherwise transcript is buffered in-memory and dropped at call end.
- [ ] Mod controls: enable/disable for the entire server.

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Adoption (% of voice DAU enabling captions) | ≥18% within 60d | preference setting metric |
| Median caption latency | <2 s | client trace |
| Word error rate (WER) on standard mic | <8% | nightly eval against LibriSpeech |
| Satisfaction among deaf testers | ≥4.5/5 | quarterly survey |
| Captions-export success rate | ≥99% | server metrics |
| Cost per voice-minute | <$0.0006 | infra metrics |

## 6. Open Questions / Risks

- Privacy: voice audio is sensitive. We must clearly disclose when captions (and therefore transcripts) are active.
- Compliance: captions inherit recording-consent rules of the call.
- Latency: Whisper-large-v3 streaming via Groq has p99 ~1.5s; degrades on poor networks.
- Speaker labelling: relies on Centrifugo per-publisher tokens; if a participant joins via guest link, they appear as "Guest" with auto-assigned colour.
- Bandwidth: extra ~3 kbps per active speaker for caption push; acceptable.

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord | English-only, basic | Multi-language, customisation, SRT export |
| Google Meet | Strong CC, no per-speaker color | Per-speaker colour + reposition |
| Zoom | Best-in-class CC | We'll match latency at lower cost |
| Slack Huddles | None | First-party |

## 8. Rollout

- Internal dogfood with deaf testers + 1 server → 5% beta → 25% → GA.
- Kill switch flag: `feature.captions_voice_video.enabled` (default OFF).
- Per-server admin opt-in, then per-user opt-in.
