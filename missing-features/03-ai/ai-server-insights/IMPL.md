# AI Server Insights — IMPL

## Phases
| # | Goal | Days |
|---|------|------|
| 0 | Spec + privacy review | 2 |
| 1 | Migration 134 | 1 |
| 2 | Aggregator queries | 4 |
| 3 | Pattern detector | 3 |
| 4 | Groq summarizer + structured prompt | 3 |
| 5 | Cron + publisher | 2 |
| 6 | Mobile views | 4 |
| 7 | Email digest (Resend) | 2 |
| 8 | Eval + tuning | 2 |
| 9 | Beta + GA | 3 |

## Backend
- [ ] `supabase/migrations/134_ai_server_insights.up.sql`
- [ ] `backend/internal/services/ai/server_insights/{aggregator,patterns,summarizer,publisher}.go`
- [ ] `backend/internal/services/ai/server_insights/prompts/weekly.md`
- [ ] pg_cron schedule `0 9 * * 1`
- [ ] System-bot author posts message embed
- [ ] Resend integration for email digest
- [ ] Metrics + Sentry

## Mobile
- [ ] `mobile/lib/features/server_settings/insights/`
- [ ] `InsightsTab`, `ReportFullScreen`, `SuggestionsList`, `SubscribeToggle`
- [ ] Riverpod
- [ ] L10n + golden tests

## Files
```
backend/internal/services/ai/server_insights/...        (new)
mobile/lib/features/server_settings/insights/...        (new)
supabase/migrations/134_ai_server_insights.up.sql       (new)
```

## Test
- Aggregator correctness on seed dataset.
- Number-faithfulness eval: LLM never invents stats not in facts.
- Skip rule (<50 active) tested.
- Privacy: no message body in report payloads.

## Rollout
- Flag `feature.server_insights.enabled`. Default ON for servers >50 active.
- Plus tier: manual run + email.

## Risks
| Risk | Mitigation |
|------|------------|
| Hallucinated numbers | LLM consumes structured facts only |
| Boring/repetitive prose | prior-report context for variety |
| Email noise | opt-in only |

## Cost
- Groq free quota covers most servers.
- Resend free 3k emails/month.
- $0 target.
