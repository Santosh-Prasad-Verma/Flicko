# Kanban Boards — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze | 2d | PM |
| 1 | Migration 164 + models | 1d | Backend |
| 2 | Service + handlers + status sync trigger | 3d | Backend |
| 3 | Mobile board view + swipe | 4d | Mobile |
| 4 | Tablet/web drag-drop | 3d | Mobile |
| 5 | Realtime + WIP banner + filters | 2d | Both |
| 6 | Stuck-card nudge cron | 1d | Backend |
| 7 | QA, a11y, load | 2d | QA |
| 8 | Beta -> GA | 21d | All |

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/164_kanban_boards.up.sql`
- [ ] Down migration
- [ ] Models `internal/models/kanban.go`
- [ ] Repo `internal/repo/kanban_repo.go`
- [ ] Service `services/productivity/kanban/service.go` (board CRUD, column reorder, card move)
- [ ] Position rebalancer helper (LexoRank-style)
- [ ] Trigger sync task.status (in migration)
- [ ] Stuck-card cron `kanban_stuck_card_nudge` daily 03:00 UTC
- [ ] Handlers
- [ ] Wire routes
- [ ] Centrifugo channel
- [ ] Audit log entries
- [ ] Prometheus counters
- [ ] OpenAPI doc update
- [ ] Tests: position rebalance, status-sync trigger, WIP exceed event

## 3. Mobile Tasks

- [ ] Folder `mobile/lib/features/productivity/kanban_boards/`
- [ ] DTOs
- [ ] Repository + remote DS
- [ ] Domain entities (Board, Column, Card)
- [ ] Riverpod providers: board state, filtered cards
- [ ] Screens: board list, board view, card sheet, board editor
- [ ] Phone: swipe -> bottom-sheet target picker (`flutter_slidable`)
- [ ] Tablet/web: drag-drop using `flutter_reorderable_grid_view`
- [ ] Filter bar (assignee, label, priority, due)
- [ ] Routing
- [ ] L10n keys
- [ ] Tests: provider tests; widget tests on swipe

## 4. AI / Infra Tasks

Not applicable.

## 5. Files Touched

```
backend/
  internal/services/productivity/kanban/service.go
  internal/handlers/kanban/{board,column,card}_handler.go
  internal/models/kanban.go
  internal/repo/kanban_repo.go
  cmd/server/main.go                 (edit)
  api/openapi.yaml                   (edit)
mobile/lib/features/productivity/kanban_boards/...
mobile/lib/core/router/app_router.dart   (edit)
mobile/lib/l10n/app_en.arb               (edit)
supabase/migrations/164_kanban_boards.up.sql
supabase/migrations/164_kanban_boards.down.sql
```

## 6. Test Plan

- Unit: 80% on kanban package
- Integration: full flow create board -> move card -> task.status synced
- E2E: Maestro on swipe path
- Load: 200 boards x 200 cards; state load p99 < 200ms
- Accessibility: keyboard reorder; screen reader announce
- Security: RLS on cross-server access

## 7. Rollout & Feature Flags

- Flag `feature.kanban_boards.enabled`
- 1% -> 10% -> 50% -> 100% over 21d

## 8. Rollback Plan

1. Flip flag
2. Pause stuck-card cron
3. Tables stay; cards still link to tasks; tasks unaffected
4. Down migration only on corruption

## 9. Dependencies / Blockers

- Depends on: tasks (must ship first)
- External: none

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Position float drift | M | L | Periodic rebalance |
| Phone swipe discoverability | M | M | First-use coach mark |
| Trigger loop with task feature | L | H | Trigger only fires on column_id change |

## 11. Cost Model

| Component | Free tier | Estimated $ at 100k DAU |
|-----------|-----------|--------------------------|
| Compute | Railway free | $0 |
| DB | Supabase | $0 |
| **Total** | | **$0** |

## 12. Done Definition

- [ ] All tasks checked
- [ ] Status sync verified end-to-end
- [ ] Beta NPS >= 30
- [ ] Zero P0/P1 in 7d
