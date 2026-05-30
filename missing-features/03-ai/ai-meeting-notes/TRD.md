# AI Meeting Notes — TRD

## Architecture
```
voice session end → trigger → fetch egress audio →
  Whisper transcript (with diarization via pyannote)
  → Groq summary (structured prompts)
  → store transcript + summary + action items
  → post message + (optional) tasks created
```

## Components
- Backend: `backend/internal/services/ai/meeting_notes/{trigger,fetch,transcribe,summarize,publish}.go`
- Egress consumer (LiveKit Egress webhook).
- Whisper.cpp or whisper.cpp+pyannote container worker.
- Groq client wrapper.
- Reuses `task_service` for action items.

## API
```
POST /channels/:id/meeting-notes/run     (manual)
GET  /channels/:id/meeting-notes
GET  /meeting-notes/:id (full)
DELETE /meeting-notes/:id (admin only)
```

## NFRs
| NFR | Target |
|-----|--------|
| Time to publish | <90s for 60-min meeting |
| Cost / hour audio | <$0 (self-hosted) |
| Language support | en, es, fr, de, pt, ja, ko, hi v1 |

## Observability
- `flicko_ai_notes_runs_total{status}`
- `flicko_ai_notes_duration_seconds`
- `flicko_ai_notes_audio_minutes_total`

## Failure
- Whisper fail → retry once → ship transcript-only without summary.
- Groq fail → fallback Ollama llama3-8b on-prem.
- Long meetings (>2h) → chunk and stitch.
