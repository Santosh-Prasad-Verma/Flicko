# AI Image Generation — TRD

## Architecture
```
/imagine slash → handler → quota check → prompt filter
   → Pollinations.ai (primary) / SDXL self-hosted (fallback)
   → image bytes → NSFW classify → Appwrite store → message embed
```

## Components
- Backend: `backend/internal/services/ai/image_gen/{quota.go, generator.go, providers/{pollinations.go,sdxl.go}, safety.go}`
- Handler: integrated into existing slash-command handler with `/imagine` registration.
- Worker: synchronous; large jobs (>15s) async with NATS subject `flicko.ai.image.gen`.
- Storage: Appwrite bucket `ai-images`, hot 30d, then archive.

## API
```
POST /commands/imagine {prompt, style?, ar?}
GET  /me/image-gen/quota
POST /images/:id/reroll
POST /images/:id/variations
```

## NFRs
| NFR | Target |
|-----|--------|
| p50 latency | <12s |
| p99 latency | <30s |
| Cost / image | $0 (Pollinations) |
| NSFW pass-through | <1% |

## Observability
- `flicko_ai_image_total{status, provider, style}`
- `flicko_ai_image_seconds`
- `flicko_ai_image_nsfw_blocked_total`

## Failure
- Pollinations down: switch to SDXL self-hosted (slower).
- NSFW classifier flag: regenerate once with safer prompt prefix; otherwise refuse.
- Quota exhausted: friendly message + upsell card.

## Cost guardrails
- Free 5/d, Plus 50/d.
- Monthly cap per server too (optional admin setting).
