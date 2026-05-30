# LFG System — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze + design review | 2d | PM/Design |
| 1 | DB schema + migration 150 | 1d | Backend |
| 2 | LFGService + handlers | 4d | Backend |
| 3 | Asynq expirer + voice integration | 2d | Backend |
| 4 | Mobile board UI + compose sheet | 5d | Mobile |
| 5 | Realtime + slot accept flow | 3d | Both |
| 6 | Cross-server hub | 2d | Both |
| 7 | QA + a11y + load test | 3d | QA |
| 8 | Beta on 10 partner servers | 5d | All |
| 9 | GA | 1d | All |

## 2. Backend Tasks

- [ ] `supabase/migrations/150_lfg_system.up.sql` (and `.down.sql`)
- [ ] `backend/internal/models/lfg.go` (LFGPost, LFGSlot, LFGServerSettings)
- [ ] `backend/internal/repo/lfg_repo.go` (pgx, prepared statements)
- [ ] `backend/internal/services/gaming/lfg/service.go` (Create/List/AcceptSlot/Cancel/Expire)
- [ ] `backend/internal/services/gaming/lfg/schema.go` with embedded JSON Schemas per game
- [ ] `backend/internal/services/gaming/lfg/expirer.go` (asynq periodic task)
- [ ] `backend/internal/handlers/gaming/lfg/handler.go` + route registration
- [ ] Wire into `backend/internal/gaming/module.go` `Initialize()`
- [ ] Centrifugo channel ACL function for `lfg:server:*` and `lfg:hub:*`
- [ ] Voice service adapter: `EnsureLFGVoiceChannel(ctx, postID, slotsTotal) (channelID, error)`
- [ ] Rate-limit middleware via existing `services/ratelimit`
- [ ] Audit log entries on create/cancel/admin actions
- [ ] Prometheus counters + histograms
- [ ] OpenAPI doc update
- [ ] Service tests ≥80%, table-driven, including concurrency cases for slot fill

## 3. Mobile Tasks

- [ ] `mobile/lib/features/gaming/lfg/data/lfg_remote_datasource.dart`
- [ ] `mobile/lib/features/gaming/lfg/data/lfg_repository_impl.dart`
- [ ] `mobile/lib/features/gaming/lfg/domain/lfg_post.dart`, `lfg_slot.dart`, usecases
- [ ] `mobile/lib/features/gaming/lfg/application/lfg_board_provider.dart` (StreamProvider)
- [ ] `mobile/lib/features/gaming/lfg/application/lfg_filter_provider.dart`
- [ ] `mobile/lib/features/gaming/lfg/presentation/lfg_board_screen.dart`
- [ ] `mobile/lib/features/gaming/lfg/presentation/lfg_compose_sheet.dart`
- [ ] `mobile/lib/features/gaming/lfg/presentation/lfg_post_card.dart`
- [ ] `mobile/lib/features/gaming/lfg/presentation/lfg_post_detail_screen.dart`
- [ ] Add routes to `mobile/lib/core/router/app_router.dart`
- [ ] L10n keys in `mobile/lib/l10n/app_en.arb`: 18 strings
- [ ] Tests: widget for compose sheet validation, provider for stream merging, golden for card states
- [ ] Empty / error / loading / disabled states

## 4. AI / Infra Tasks

Not applicable in v1 (no model usage). Future: rank-prediction nudge based on game-stats-integration.

## 5. Files Touched (predicted)

```
backend/
  internal/services/gaming/lfg/service.go              (new)
  internal/services/gaming/lfg/schema.go               (new, embeds *.schema.json)
  internal/services/gaming/lfg/expirer.go              (new)
  internal/handlers/gaming/lfg/handler.go              (new)
  internal/models/lfg.go                               (new)
  internal/repo/lfg_repo.go                            (new)
  internal/gaming/module.go                            (edit — wire LFG)
  cmd/server/main.go                                   (edit — register asynq tasks)
mobile/
  lib/features/gaming/lfg/...                          (new tree, ~12 files)
  lib/core/router/app_router.dart                      (edit)
  lib/l10n/app_en.arb                                  (edit)
supabase/
  migrations/150_lfg_system.up.sql                     (new)
  migrations/150_lfg_system.down.sql                   (new)
```

## 6. Test Plan

- Unit: ≥80% coverage on service + validator. Property-based tests for slot concurrency (rapid).
- Integration: Postgres + Redis + Centrifugo via testcontainers; 50 concurrent slot accepts → exactly N succeed.
- E2E: Patrol flow — create post, second device joins slot, voice channel opens.
- Load: k6 — 200 rps create + 1000 rps list for 10 min; p99 list <250ms.
- A11y: axe + manual TalkBack and VoiceOver pass on board + compose.
- Security: tabletop — slot tampering, RLS bypass attempts, rate-limit evasion.

## 7. Rollout & Feature Flags

- Flag: `feature.lfg.enabled` (Doppler) — global kill switch.
- Per-server flag: `lfg_server_settings.enabled` defaulted off until admin toggles on.
- Beta: 10 partner gaming servers (≥200 members each).
- Canary: 1% → 10% → 50% → 100% over 7d.
- Kill switch tested in staging with synthetic post traffic.

## 8. Rollback Plan

1. Disable global flag (instant).
2. Stop asynq expirer worker.
3. Revert handler routes.
4. Leave tables in place (cheap); only run down-migration if data corruption.

## 9. Dependencies / Blockers

- Depends on: existing voice service (`internal/services/voice`), Centrifugo channel ACL hooks.
- Blocks: gaming-profiles-deep (cross-feature surfacing), achievement-system (LFG-related achievements).
- External: none.

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Voice service can't keep up at peak | M | H | Pre-warm channel pool; backoff on accept |
| Rank-fakers ruining matches | H | M | Trust badges via game-stats-integration; report flow |
| Cross-server brigading | M | M | Server-age + size gate; per-user post quota |
| Slot race conditions | M | H | Row lock + redlock + idempotency key |
| Schema drift between client/server | L | M | Schema versioned; client warns on unknown fields |

## 11. Cost Model

| Component | Free tier? | Estimated $ at 100k DAU |
|-----------|-----------|--------------------------|
| Compute (Go service) | Railway free | ~$5/mo |
| Postgres rows | Supabase free | ~$0 (light rows) |
| Redis ops | Upstash free | ~$0 |
| Centrifugo | Self-hosted on Railway | ~$0 |
| Storage | n/a | $0 |
| **Total** | | **~$5/mo** |

## 12. Done Definition

- [ ] All tasks above checked.
- [ ] Code merged to main behind flag.
- [ ] Metrics dashboard live on Grafana.
- [ ] Beta feedback ≥4.0/5 from partner-server admins.
- [ ] Zero P0/P1 bugs in 7-day window.
- [ ] Median time-to-fill <6 min during beta window.
