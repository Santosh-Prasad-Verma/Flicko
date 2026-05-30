# Achievement System — Implementation Plan

## Phases

### Phase 1 — Foundations (week 1-2)

Goal: data model + ingestion path operational, no UI.

Backend tasks (`backend/internal/services/gaming/achievements/`):
- [ ] `migrations/150_create_achievements.sql` (see SCHEMA.md).
- [ ] `models/achievement.go` — structs and enums.
- [ ] `models/progress.go` — counter struct.
- [ ] `repo/postgres.go` — `UpsertProgress`, `InsertUnlock`, `ListShelf`, `SetShelf`.
- [ ] `repo/cache.go` — Redis idempotency + shelf cache.
- [ ] `engine/rules.go` — load/parse `rules.yaml`, hot reload via SIGHUP.
- [ ] `engine/evaluator.go` — pure function `(progress, rule) -> unlock?`.
- [ ] `consumer/nats.go` — subscribe `events.>`, fan to evaluator.
- [ ] `cmd/ach-engine/main.go` — wires consumer + repo + evaluator.
- [ ] `internal/seed/rules.yaml` — 60 achievements.

Mobile tasks (`mobile/lib/features/gaming/achievements/`):
- [ ] `data/models/achievement.dart`, `unlock.dart`, `shelf_slot.dart`.
- [ ] `data/api/achievements_api.dart` — Dio client.
- [ ] `data/repos/achievement_repo.dart` — caches via Hive box `ach_cache`.

### Phase 2 — Profile shelf UI (week 3)

Backend:
- [ ] `handlers/shelf.go` — GET shelf, PUT shelf with shape `[{slot, ach_id, server_id?}]`.
- [ ] Validation: max 6 slots, each must be unlocked + visible to viewer.

Mobile:
- [ ] `presentation/widgets/achievement_card.dart` — rarity ring, icon, title.
- [ ] `presentation/widgets/shelf_row.dart` — horizontal scroll, "See all" pill.
- [ ] `presentation/screens/achievements_screen.dart` — full list, filter chips.
- [ ] `presentation/screens/edit_shelf_screen.dart` — drag-reorder via `reorderables`.
- [ ] `presentation/widgets/locked_progress_card.dart` — progress bar variant.

### Phase 3 — Unlock pipeline (week 4)

Backend:
- [ ] `publisher/unlock.go` — emit `achievement.unlocked` with i18n prefilled per user locale.
- [ ] WS bridge in existing `notification-svc` to deliver to client.
- [ ] Backfill worker `cmd/ach-backfill/main.go` for replay with `silent=true`.

Mobile:
- [ ] `presentation/widgets/unlock_toast.dart` — animated banner.
- [ ] `presentation/widgets/confetti_overlay.dart` — only for Legendary, gated by `MediaQuery.disableAnimations`.
- [ ] Subscribe to `achievement.unlocked` via existing WS multiplexer.
- [ ] Local de-dupe by `(user_id, ach_id)` over 5 min.

### Phase 4 — Server-scoped + polish (week 5)

Backend:
- [ ] `handlers/server_ach.go` — owner enable/disable from catalog.
- [ ] Catalog endpoint returns `server_template=true` rows only for enable flow.
- [ ] Rarity nightly cron in `cmd/ach-rarity/main.go`.

Mobile:
- [ ] Server settings tab "Achievements" — toggle list, preview card.
- [ ] Member profile inside server shows server-scoped progress section.

### Phase 5 — Hardening (week 6)

- [ ] Load test: 5k events/s for 30 min, p95 < 5s end-to-end.
- [ ] Chaos: kill engine mid-burst, verify dedupe + replay.
- [ ] Backfill 3y account: completes < 30 min, 0 user-facing toasts.
- [ ] RLS pen test: visitor cannot read another user's `user_progress`.

## Test plan

| Layer | Test | Tool |
|---|---|---|
| Engine eval | rule fires at threshold once | Go table tests |
| Engine eval | hidden achievement progresses but not visible | Go table tests |
| Repo idempotency | duplicate event no-ops | integration with testcontainers |
| Backfill | 1M events in < 5 min on dev | cmd test |
| Mobile shelf | drag reorder persists across restart | widget test |
| Mobile toast | reduced-motion drops confetti | golden test |
| API contract | shelf payload matches schema | dredd |

## Rollout

1. Deploy migration 150 behind `feature_flag.achievements=false`.
2. Enable engine for internal users; verify metrics for 48h.
3. 5% rollout; watch unlock distribution per rarity.
4. 25% -> 100% over 2 weeks if rarity holds (Legendary <2%, Common >70%).
5. Server-scoped GA after 4 more weeks of stability.

## $0 cost analysis

- Postgres: 60M rows worst case; single jsonb-free row ~120 bytes; 7.2 GB. Not free-tier — but at 1M users, projected 6M unlocks, 720 MB, fits.
- Redis: hot keys ~10k entries, 1 MB.
- NATS: embedded in existing event bus; no incremental cost.
- Workers: 1 vCPU sufficient at projected throughput; runs on shared box.
- Icons: SVG, served from existing CDN.

Total incremental infra: $0 against the existing free tier budget.
