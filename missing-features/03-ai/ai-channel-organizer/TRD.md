# AI Channel Organizer — TRD

## Architecture
```
admin click → Backend assemble context (channels + 14d msg counts + categories)
            → LLM (Groq llama3-70b) prompt: "propose reorg JSON"
            → validate output schema → store run + suggestions
            → preview UI → selective apply (uses existing channel/category services)
```

## Components
- Backend: `backend/internal/services/ai/channel_organizer/{context.go, prompt.go, planner.go, applier.go}`
- Handler: `channel_organizer_handler.go` — POST /servers/:id/organizer/runs, GET /runs/:rid, POST /runs/:rid/apply
- Prompt template at `backend/internal/services/ai/channel_organizer/prompts/organize.md`
- Provider abstraction: Groq primary, Ollama fallback

## API
```
POST /servers/:id/organizer/runs       → {run_id}
GET  /servers/:id/organizer/runs/:rid  → {status, suggestions[]}
POST /servers/:id/organizer/runs/:rid/apply {suggestion_ids[]}
```

## NFRs
| NFR | Target |
|-----|--------|
| Generation time | <30s p99 |
| Cost / run | <$0.02 |
| Per-day cap | 1 run/server free, 5 Plus |

## Observability
- `flicko_ai_organizer_runs_total{status}`
- `flicko_ai_organizer_apply_total{action}`
- `flicko_ai_organizer_seconds`

## Failure
- Groq down: queue + retry with Ollama; mark "slow".
- Schema mismatch: re-prompt with schema reminder up to 2×.

## Cost guardrails
- Groq input ≤ 8k tokens; output ≤ 2k tokens.
- Hard daily cap per server.
