# Live Voice Captions — Whisper.cpp Transcription — Product Requirements

> **One-line:** Real-time captions in voice channels via on-stream Whisper transcription.
> **Status:** Missing — to build
> **Category:** 03-ai
> **Effort:** XL
> **Priority:** P1

## 1. Problem

Discord's voice channels exclude deaf/hard-of-hearing users entirely; non-native speakers struggle when conversations are fast. Discord ships no native captions; third-party bots like SoundCloud Bot are paid and lossy. Slack Huddles got captions in 2024 (paid only). Microsoft Teams has them but enterprise-locked.

For Flicko's gaming guilds, study groups, and remote teams, captioning is an accessibility table-stake. Whisper.cpp can run on CPU at faster-than-realtime for `small.en` and `tiny.en` models. We have an Egress mixer producing the audio; we can tap it.

## 2. Users & Use Cases

- **Primary persona:** Hard-of-hearing member who would otherwise skip voice channels.
- **Secondary persona:** Late-joiner who wants to read what was said before joining.
- **Tertiary persona:** Non-native speaker who reads faster than they listen.

**Top 3 jobs-to-be-done:**
1. As a deaf user, I want live captions of every speaker, so that I can participate equally.
2. As a late joiner, I want a scrollable transcript of the past 5 minutes, so that I catch up.
3. As a server admin, I want to enable/disable per channel, so that I can respect privacy in voice DMs.

## 3. Goals & Non-Goals

**Goals**
- Per-speaker captions: `alice: hey did anyone see…`
- ≤2s end-to-end latency from speech to caption (p95)
- Whisper.cpp `small.en` (244MB) for English; `medium` (769MB) for multilingual servers
- Push captions via Centrifugo channel `voice_captions:<channel_id>`
- Persist transcript per session for late-join + post-session export
- Speaker diarization via LiveKit's per-track audio (no diarization model needed)

**Non-Goals**
- Closed-caption stylization (just text)
- Real-time translation of captions (compose with `ai-auto-translate` v2)
- Speaker emotion detection
- Voice cloning / TTS

## 4. Scope (v1)

- [ ] Egress audio tap → Whisper.cpp worker per voice channel
- [ ] Per-speaker chunking via VAD (`silero-vad` 16ms frames)
- [ ] Caption emit on utterance end OR every 1.5s (whichever first) for streaming
- [ ] Rolling transcript stored Postgres `voice_transcripts`
- [ ] Mobile overlay: bottom captions panel in voice screen
- [ ] Toggle per channel by admin (default OFF)
- [ ] Per-user toggle: "show captions" (default ON when admin enables)
- [ ] Storage: 24h hot, archive nightly to R2

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Adoption | 15% of voice sessions enable captions | event |
| Latency p95 (speech end → caption shown) | <2s | metric |
| Word Error Rate (sampled human-graded) | <12% en, <22% multilingual | weekly QA |
| Cost per voice-minute | $0 | infra |
| % deaf users using voice channels | tracked self-disclosed | survey |

## 6. Open Questions / Risks

- **Risk:** Whisper.cpp CPU cost at scale. Mitigation: per-channel worker pool capped at 8; spillover queue.
- **Risk:** Background-noise channels (gaming) make transcripts noisy. Mitigation: VAD threshold tuned per channel; "noise mode" picks `tiny` model.
- **Q:** Store raw audio? Decision: NO — only transcripts.
- **Q:** Should captions show during music playback? Decision: NO — auto-pause when music-bot is active.

## 7. Competitive Landscape

| Product | Their take | Gap |
|---------|------------|-----|
| Discord | None | We have it free |
| Slack Huddles | Captions paid Pro+ | Free |
| Teams | Captions enterprise | Free, self-hosted |
| Zoom | Captions free | Equal |
| Google Meet | Real-time captions | Equal, but on chat platform |

## 8. Rollout

- Internal Flicko team voice room (1 wk)
- Flag-gated 5% then 25% then 100%
- Per-server toggle defaults OFF
- Accessibility-first: opt-out via "enable captions" master switch

## 9. Compliance

- Audio is processed in-memory only; never persisted to disk
- Transcripts treated as user-content under TOS
- GDPR delete cascades by `speaker_user_id`
- WCAG 2.1 AA: captions readable without color reliance, customizable size
