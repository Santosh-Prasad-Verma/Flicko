# Game Stats Integration — IMPL

## Phases
| # | Goal | Days |
|---|------|------|
| 0 | Spec + provider TOS audit | 3 |
| 1 | Migration 152 + token encryption | 2 |
| 2 | Riot adapter (RSO) + fetcher | 4 |
| 3 | Steam adapter (OpenID + WebAPI) | 3 |
| 4 | Xbox / PSN / BNet adapters | 8 |
| 5 | Refresher worker | 2 |
| 6 | Profile widget | 3 |
| 7 | Rank-role auto-grant | 3 |
| 8 | QA + privacy audit | 3 |
| 9 | Beta + GA | 4 |

## Backend
- [ ] `supabase/migrations/152_game_stats.up.sql`
- [ ] `backend/internal/services/gaming/stats/{oauth,fetcher,normalizer,role_assigner}.go`
- [ ] `backend/internal/services/gaming/stats/providers/{riot,steam,xbox,psn,bnet}.go`
- [ ] `backend/internal/handlers/stats_handler.go`
- [ ] Existing `connected_account_service` extension
- [ ] Doppler secrets per provider
- [ ] Metrics + Sentry

## Mobile
- [ ] `mobile/lib/features/gaming/stats/`
- [ ] `LinkedAccountsScreen`, `StatsCard`, `RankRolesScreen` (admin)
- [ ] OAuth via webview package
- [ ] L10n + golden tests

## Files
```
backend/internal/services/gaming/stats/...           (new)
backend/internal/services/gaming/stats/providers/... (new)
backend/internal/handlers/stats_handler.go           (new)
mobile/lib/features/gaming/stats/...                 (new)
supabase/migrations/152_game_stats.up.sql            (new)
```

## Test
- OAuth happy + revoke + re-prompt flows.
- Rate-limit tests with simulated 429.
- Privacy: friends-only visibility verified by RLS.
- Role assignment idempotency.

## Rollout
- Flag `feature.game_stats.enabled`. Default OFF.
- Beta on 5 gaming servers per provider.

## Risks
| Risk | Mitigation |
|------|------------|
| Provider TOS violation | per-provider review + kill-switch |
| Token leak | libsodium encryption + Doppler |
| Rate-limit blackouts | adaptive intervals |

## Cost
- $0. All providers offer free read-only quotas adequate for 100k DAU at our cadence.
