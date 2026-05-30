# AI Image Generation — IMPL

## Phases
| # | Goal | Days |
|---|------|------|
| 0 | Spec + safety policy | 3 |
| 1 | Migration 136 | 1 |
| 2 | Pollinations adapter | 2 |
| 3 | SDXL fallback (self-hosted) | 4 |
| 4 | NSFW classifier integration | 2 |
| 5 | Quota service | 2 |
| 6 | Slash command UI | 4 |
| 7 | Embed + re-roll | 3 |
| 8 | Server admin controls | 2 |
| 9 | Eval + safety | 3 |
| 10 | Beta + GA | 4 |

## Backend
- [ ] `supabase/migrations/136_ai_image_generation.up.sql`
- [ ] `backend/internal/services/ai/image_gen/{generator,quota,safety}.go`
- [ ] `backend/internal/services/ai/image_gen/providers/{pollinations.go, sdxl.go}`
- [ ] Existing slash command handler extension
- [ ] Embed renderer in `embed_service`
- [ ] Metrics + Sentry

## Mobile
- [ ] `mobile/lib/features/ai_assistant/image_gen/`
- [ ] `ImagineSheet`, `ImageEmbedCard`, `QuotaCard`
- [ ] Riverpod
- [ ] L10n + golden tests

## Files
```
backend/internal/services/ai/image_gen/...               (new)
backend/internal/services/ai/image_gen/providers/...     (new)
mobile/lib/features/ai_assistant/image_gen/...           (new)
supabase/migrations/136_ai_image_generation.up.sql       (new)
```

## Test
- Provider fallback (Pollinations 503 → SDXL).
- NSFW seed set: 100 prompts, expect ≥99 blocked.
- Quota concurrency: 10 simultaneous requests respect cap.
- Idempotency on re-roll.

## Rollout
- Flag `feature.ai_image.enabled`. Default OFF.
- Beta on art-tagged servers.

## Risks
| Risk | Mitigation |
|------|------------|
| Pollinations outage | self-hosted SDXL warm pool |
| NSFW slip-through | dual classifier (vision + text) |
| Bot abuse | per-IP + per-user rate limit + captcha after burst |

## Cost
- $0 with Pollinations.
- SDXL fallback runs on existing CPU/GPU pod (idle reused).
