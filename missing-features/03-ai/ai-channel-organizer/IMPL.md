# AI Channel Organizer — IMPL

## Phases
| # | Goal | Days |
|---|------|------|
| 0 | Spec + prompt design | 2 |
| 1 | Migration 141 | 1 |
| 2 | Context builder + Groq client | 3 |
| 3 | Streaming SSE handler | 2 |
| 4 | Applier service | 2 |
| 5 | Admin UI | 4 |
| 6 | Eval harness with golden seeds | 2 |
| 7 | QA + safety | 2 |
| 8 | Beta + GA | 3 |

## Backend
- [ ] `supabase/migrations/141_ai_channel_organizer.up.sql`
- [ ] `backend/internal/services/ai/channel_organizer/{context,prompt,planner,applier}.go`
- [ ] `backend/internal/services/ai/channel_organizer/prompts/organize.md`
- [ ] `backend/internal/handlers/channel_organizer_handler.go`
- [ ] Permission MANAGE_SERVER required
- [ ] Audit hooks per applied change
- [ ] Metrics

## Mobile
- [ ] `mobile/lib/features/server_settings/organizer/`
- [ ] `OrganizerScreen`, `SuggestionList`, `ApplySheet`
- [ ] SSE consumer
- [ ] L10n + tests

## Files
```
backend/internal/services/ai/channel_organizer/...   (new)
backend/internal/handlers/channel_organizer_handler.go (new)
mobile/lib/features/server_settings/organizer/...    (new)
supabase/migrations/141_ai_channel_organizer.up.sql  (new)
```

## Test
- Eval golden: 5 seed servers with known issues; expect ≥70% precision.
- Hard caps tested.
- RLS test for non-admin.

## Rollout
- Flag `feature.ai_organizer.enabled`. Plus tier first.

## Risks
- Hallucinated category rename to NSFW. Mitigation: classifier on output before showing.

## Cost
- Groq free; capped 1/server/day; <$0.02/run.
