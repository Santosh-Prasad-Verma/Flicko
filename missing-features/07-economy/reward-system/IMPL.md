# Reward System — Implementation

## Phases
| # | Goal | Days |
|---|------|------|
| 0 | Spec | 1 |
| 1 | Migration 179 | 1 |
| 2 | Backend `reward_service` + evaluator worker | 4 |
| 3 | Admin rule editor screen | 3 |
| 4 | Member rewards screen + push | 2 |
| 5 | Wallet/role/badge dispatch | 2 |
| 6 | QA + fraud checks | 2 |
| 7 | Beta + GA | 3 |

## Backend
- [ ] `supabase/migrations/179_reward_system.up.sql`
- [ ] `backend/internal/models/reward.go`
- [ ] `backend/internal/services/economy/reward/service.go`
- [ ] `backend/internal/services/economy/reward/evaluator.go` (NATS subscriber)
- [ ] `backend/internal/handlers/reward_handler.go` (CRUD rules, GET grants)
- [ ] Permission `MANAGE_REWARDS` added to perm enum
- [ ] Audit entries on rule edits and grants
- [ ] Metrics: `flicko_reward_grants_total`, `flicko_reward_evaluator_lag`

## Mobile
- [ ] `mobile/lib/features/economy/rewards/` (data/domain/application/presentation)
- [ ] Admin: `RuleListScreen`, `RuleEditorScreen`
- [ ] Member: `MyRewardsScreen` showing grants + progress bars
- [ ] Push notification handler "🎉 You earned 50 coins for 100 messages this week"
- [ ] L10n + tests

## Files
```
backend/internal/services/economy/reward/...                 (new)
backend/internal/handlers/reward_handler.go                  (new)
mobile/lib/features/economy/rewards/...                      (new)
supabase/migrations/179_reward_system.up.sql                 (new)
```

## Test
- Unit ≥80%
- Integration: 50 simulated users hit thresholds, verify grants once and only once.
- Fuzz: race condition test on metric increment.

## Rollout
- Flag `feature.rewards.enabled`. Beta on 5 servers.
- Canary 1%→10%→50%→100%.

## Risks
| Risk | Mitigation |
|------|------------|
| Farming via spam | use messages-with-content-quality counter; ignore <3 char msgs |
| Double-grant after retry | UNIQUE (rule, user, day); idempotency key |
| Currency inflation | server admin sets coin caps |

## Cost
- $0 — runs on existing infra. Worker reuses NATS bus.
