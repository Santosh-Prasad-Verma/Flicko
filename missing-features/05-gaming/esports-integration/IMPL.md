# Esports Integration — IMPL

## Phases
| # | Goal | Days |
|---|------|------|
| 0 | Spec | 1 |
| 1 | Migration 154 + games seed | 1 |
| 2 | PandaScore adapter | 3 |
| 3 | Poller + diff logic | 2 |
| 4 | Embed renderer | 2 |
| 5 | Subscription handler | 2 |
| 6 | Mobile screens | 4 |
| 7 | Schedule digest cron | 1 |
| 8 | QA + quota tuning | 2 |
| 9 | Beta + GA | 3 |

## Backend
- [ ] `supabase/migrations/154_esports.up.sql`
- [ ] `backend/internal/services/gaming/esports/{poller,adapter_pandascore,dispatcher,subscriptions}.go`
- [ ] `backend/internal/handlers/esports_handler.go`
- [ ] System-bot user with permission to author embeds in target channel
- [ ] Metrics + Sentry
- [ ] Doppler secret `PANDASCORE_TOKEN`

## Mobile
- [ ] `mobile/lib/features/gaming/esports/`
- [ ] `MatchCardWidget`, `SubscriptionManagerScreen`, `EsportsScheduleScreen`
- [ ] Riverpod providers
- [ ] L10n for game names

## Files
```
backend/internal/services/gaming/esports/...     (new)
backend/internal/handlers/esports_handler.go     (new)
mobile/lib/features/gaming/esports/...           (new)
supabase/migrations/154_esports.up.sql           (new)
```

## Test
- Adapter unit tests with sample fixtures.
- Quota: simulate 1k/day distribution; ensure ≤900.
- E2E: subscribe → trigger fixture event → message posted.

## Rollout
- Flag `feature.esports.enabled`.
- Beta on 5 esports servers.
- Add games incrementally based on demand.

## Risks
| Risk | Mitigation |
|------|------------|
| Quota exhaustion | adaptive interval per priority |
| Provider drift | adapter test fixtures |
| Spammy live updates | only on score change, not every poll |

## Cost
$0. PandaScore free tier covers up to 1k req/mo when tuned.
