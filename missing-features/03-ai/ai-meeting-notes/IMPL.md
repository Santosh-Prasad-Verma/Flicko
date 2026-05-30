# AI Meeting Notes — IMPL

## Phases
| # | Goal | Days |
|---|------|------|
| 0 | Spec + privacy review | 3 |
| 1 | Migration 138 | 1 |
| 2 | LiveKit Egress hookup | 3 |
| 3 | Whisper + diarization worker | 5 |
| 4 | Groq summarizer + structured prompt | 3 |
| 5 | Publisher | 2 |
| 6 | Mobile views | 4 |
| 7 | Action item → task convert | 2 |
| 8 | Eval harness | 3 |
| 9 | Beta + GA | 3 |

## Backend
- [ ] `supabase/migrations/138_ai_meeting_notes.up.sql`
- [ ] `backend/internal/services/ai/meeting_notes/{trigger,fetch,transcribe,summarize,publish}.go`
- [ ] `backend/internal/services/ai/meeting_notes/prompts/summarize.md`
- [ ] `backend/internal/handlers/meeting_notes_handler.go`
- [ ] LiveKit Egress webhook handler
- [ ] Worker pod with Whisper.cpp + pyannote
- [ ] Metrics + Sentry

## Mobile
- [ ] `mobile/lib/features/ai_assistant/meeting_notes/`
- [ ] `RecordingBanner`, `NotesEmbedCard`, `FullNotesScreen`, `ActionItemList`
- [ ] L10n + golden tests

## Files
```
backend/internal/services/ai/meeting_notes/...                   (new)
backend/internal/handlers/meeting_notes_handler.go               (new)
mobile/lib/features/ai_assistant/meeting_notes/...               (new)
docker/workers/whisper-meeting.Dockerfile                        (new)
supabase/migrations/138_ai_meeting_notes.up.sql                  (new)
```

## Test
- Eval set: 10 seed meetings, expected summary similarity ≥0.7 BLEU vs human.
- Privacy: ensure raw audio deleted after notes published.
- Latency: p95 <90s for 60-min audio on 4 vCPU.

## Rollout
- Flag `feature.meeting_notes.enabled`. Default OFF.
- Beta: 10 work-tagged servers.

## Risks
| Risk | Mitigation |
|------|------------|
| Privacy backlash | recording banner + opt-in per channel + per-user opt-out |
| Hallucinated action items | structured prompts + verification pass |
| Long meetings | chunk and stitch |

## Cost
- Whisper self-hosted (existing pod).
- Groq free tier covers most servers.
- Storage minimal (transcripts only).
- $0 target.
