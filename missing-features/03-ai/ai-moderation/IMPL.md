# AI Moderation — IMPL

## Phases
| # | Goal | Days |
|---|------|------|
| 0 | Spec + bias audit | 4 |
| 1 | Migration 137 | 1 |
| 2 | Classifier abstraction (Groq + Ollama) | 4 |
| 3 | Hook into automod pipeline | 3 |
| 4 | Mod queue UI | 4 |
| 5 | Threshold settings UI | 2 |
| 6 | Appeal flow | 2 |
| 7 | Eval harness with seeded toxic + benign sets | 3 |
| 8 | Beta + tune | 4 |
| 9 | GA | 2 |

## Backend
- [ ] `supabase/migrations/137_ai_moderation.up.sql`
- [ ] `backend/internal/services/ai/moderation/{classifier,threshold,queue,appeal}.go`
- [ ] Existing `automod_service` extended with `ai_mod_check`
- [ ] `backend/internal/handlers/mod_queue_handler.go`
- [ ] Metrics + Sentry
- [ ] Doppler `LLAMA_GUARD_KEY`

## Mobile
- [ ] `mobile/lib/features/moderation/ai/`
- [ ] `BlockDialog`, `ModQueueScreen`, `ThresholdSettingsScreen`, `AppealForm`
- [ ] Riverpod, L10n
- [ ] Golden tests

## Files
```
backend/internal/services/ai/moderation/...           (new)
backend/internal/handlers/mod_queue_handler.go        (new)
backend/internal/services/automod_service.go          (edit, add ai stage)
mobile/lib/features/moderation/ai/...                 (new)
supabase/migrations/137_ai_moderation.up.sql          (new)
```

## Test
- F1 ≥0.85 on held-out toxic dataset; FPR <2% on benign.
- Latency p99 <200ms.
- Edit-after-flag flow.
- Appeal cap (3/d) enforced.

## Rollout
- Flag `feature.ai_mod.enabled`. Default OFF.
- Beta: 10 large servers; tune thresholds.
- Plus tier optional; free tier gets defaults.

## Risks
| Risk | Mitigation |
|------|------------|
| Bias against dialects | per-locale threshold tuning + appeal |
| Privacy | text not stored long-term; hash only |
| Cost spike | Groq free quota + cap |

## Cost
- Groq llama-guard free quota covers first ~1M msgs/day.
- Self-hosted Ollama fallback always free.
- $0 target.
