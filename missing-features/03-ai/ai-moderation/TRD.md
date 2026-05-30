# AI Moderation — TRD

## Architecture
```
message send → existing automod → ai_mod classifier (Llama-Guard / Perspective)
   → score per category
   → if any > block_threshold → reject + audit
   → else if any > review_threshold → publish + queue mod review
   → else → publish
```

## Components
- Backend: `backend/internal/services/ai/moderation/{classifier.go, threshold.go, queue.go, appeal.go}`
- Provider abstraction: Llama-Guard via Groq primary; Ollama-hosted fallback.
- Existing `automod_service` integrates ai_mod as a check stage.
- Mod queue extends existing `report_service`.

## API
```
POST /messages (existing) — internally invokes mod
GET  /servers/:id/mod-queue
POST /mod-queue/:id/decision {approve|deny}
GET  /servers/:id/automod/ai-thresholds
PATCH /servers/:id/automod/ai-thresholds {hate, harassment, sexual, self_harm, violence}
POST /messages/:id/appeal
```

## NFRs
| NFR | Target |
|-----|--------|
| p99 classifier latency | <200ms |
| Block accuracy | F1 ≥0.85 on held-out set |
| Cost per message | <$0.0001 |

## Observability
- `flicko_ai_mod_classified_total{category, action}`
- `flicko_ai_mod_seconds`
- `flicko_ai_mod_queue_depth`
- `flicko_ai_mod_overrides_total`

## Failure
- Classifier down: fall through to existing keyword automod.
- Queue full: paginate; alert ops.
- Appeal misuse: per-user appeal cap 3/d.
