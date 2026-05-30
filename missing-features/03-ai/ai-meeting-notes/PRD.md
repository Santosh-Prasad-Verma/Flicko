# AI Meeting Notes — PRD

> **One-line:** At end of voice session, auto-transcribe and summarize into action items + decisions, posted in the channel.
> **Effort:** L · **Priority:** P1

## Problem
Voice meetings on Discord vanish — no record, no follow-up. Teams paste manual notes after. Native AI notes give a permanent, searchable trail with action items.

## Users
- Work/study servers running standups and reviews.
- Communities running town halls.

JTBDs:
1. Have notes auto-posted after a voice session.
2. Get crisp action items I can convert to tasks.
3. Search past meetings semantically.

## Goals
- Auto trigger on voice session end (≥3 min, ≥2 participants).
- Output: summary, action items, decisions, follow-ups.
- Posted within 60s of session end.
- Markdown rendered in channel; full transcript saved.

Non-goals: Real-time live notes (uses ai-voice-transcription).

## Scope
- [ ] Auto-trigger on voice session end
- [ ] Whisper transcript with speaker diarization
- [ ] Groq summary using structured prompt
- [ ] Action items list with mention tagging
- [ ] Convert-to-task button (uses task-management feature)
- [ ] Per-server enable/disable

## Metrics
- 30% of eligible voice sessions get notes.
- Time-to-notes p95 <90s.
- Action-item accept rate >50%.

## Risks
- Privacy. Mitigation: explicit per-channel opt-in + on-screen recording indicator.
- Hallucinated action items. Mitigation: structured JSON output with verification pass.

## Competitive
| Product | Take | Gap |
|---------|------|-----|
| Otter.ai | External, paid | Native + free |
| Granola | Mac only | Cross-platform, in-platform |
