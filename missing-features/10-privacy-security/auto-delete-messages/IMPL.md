# Auto-Delete Messages — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze | 1d | PM |
| 1 | DB migration 222 + sweeper fn | 2d | Backend |
| 2 | Service + handler | 2d | Backend |
| 3 | Mobile mod settings sheet | 2d | Mobile |
| 4 | Header badge + composer hint + first-time tooltip | 2d | Mobile |
| 5 | QA + load test | 2d | QA |
| 6 | Beta | 3d | All |
| 7 | GA | 1d | All |

Total: ~13 working days, 1 backend + 1 mobile.

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/222_auto_delete_messages.up.sql`.
- [ ] Down migration.
- [ ] Models `internal/models/channel_auto_delete.go`.
- [ ] Service `internal/services/privacy/auto_delete_messages/service.go`.
  - [ ] `SetChannelTtl(ctx, channelID, modID, ttlSeconds, exemptPinned, exemptSystem)`.
  - [ ] `GetChannelTtl(ctx, channelID)`.
  - [ ] `DisableChannelTtl(ctx, channelID, modID)`.
- [ ] Handler `internal/handlers/auto_delete_handler.go`.
- [ ] Wire routes in `cmd/server/main.go`.
- [ ] Sweeper SQL function (separate from `sweep_expired_messages`).
- [ ] Cron registration.
- [ ] Centrifugo publishers (config-changed, message.deleted with reason auto_delete).
- [ ] Audit-log entries (retention-change-only; sweep counts already aggregated in audit table).
- [ ] Metrics + alerts.
- [ ] OpenAPI doc update.
- [ ] Service tests (≥80% cov).
- [ ] Integration: 100 messages, half pinned, sweep at TTL, pinned remain, others gone.
- [ ] Load test: 100 channels with TTL set, 1k msg/s aggregate, sweeper keeps up.

## 3. Mobile Tasks

- [ ] Feature folder `mobile/lib/features/privacy/auto_delete_messages/`.
- [ ] Domain: `AutoDeleteSettings`, `ChannelTtlPreset`.
- [ ] Application: `channelAutoDeleteProvider`.
- [ ] Presentation:
  - [ ] `AutoDeleteSettingsSheet` (mod, with TTL preset radio + exempt toggles).
  - [ ] `AutoDeleteBadge` (header).
  - [ ] `ComposerAutoDeleteHint` (small inline hint above input).
  - [ ] `FirstTimeAutoDeleteTooltip` (member-side, once per channel).
- [ ] Wire realtime listener for `auto_delete.config_changed`.
- [ ] L10n keys.
- [ ] Tests.

## 4. AI / Infra Tasks

- [ ] None.

## 5. Files Touched (predicted)

```
backend/
  internal/services/privacy/auto_delete_messages/service.go        (new)
  internal/handlers/auto_delete_handler.go                         (new)
  internal/models/channel_auto_delete.go                           (new)
  internal/repo/channel_auto_delete_repo.go                        (new)
  cmd/server/main.go                                               (edit)
mobile/
  lib/features/privacy/auto_delete_messages/...                    (new tree)
  lib/features/messaging/presentation/channel_header.dart          (edit)
  lib/features/messaging/presentation/message_composer.dart        (edit)
  lib/features/moderation/presentation/channel_settings.dart       (edit)
supabase/
  migrations/222_auto_delete_messages.up.sql                       (new)
  migrations/222_auto_delete_messages.down.sql                     (new)
```

## 6. Test Plan

- **Unit:** TTL preset validation; pin-exempt logic; system-message-exempt logic.
- **Integration:** Postgres + Centrifugo testcontainers; full lifecycle (set TTL → post → wait → sweep → realtime delete).
- **E2E:** Maestro — mod sets TTL, member posts, sweep tick, message gone with reason "auto_delete."
- **Property test:** random channel population; assert all unpinned non-system rows older than TTL are deleted; assert exempt rows preserved.
- **Load:** 100 channels, sustained 5k inserts/min, sweeper keeps up.
- **Regression:** existing per-message TTL feature unaffected (`expires_at` rows are not touched by this sweeper).

## 7. Rollout & Feature Flags

- Flag: `feature.auto_delete_messages.enabled`.
- Beta: 5%.
- Canary: 25% over 7d.
- Worker pause flag for emergencies: `worker.auto_delete_messages.paused`.

## 8. Rollback Plan

1. Disable flag — UI to set/change TTL hidden.
2. Existing TTL settings continue to operate; if we disable the worker too, channels accumulate again — fine.
3. Down migration drops settings table; cron unschedule.

## 9. Dependencies / Blockers

- pg_cron extension (already in use).
- `disappearing_messages` sweeper pattern.
- Channel mod-role bit.

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Sweeper deletes pinned by bug | Low | High | Strict WHERE on pin status + tests |
| Mod weaponizes auto-delete | Low | Med | Audit log; server-owner override |
| Bulk deletion locks table | Med | Med | Batch size limit + SKIP LOCKED |
| Member confusion | High | Low | First-time tooltip + badge |

## 11. Cost Model

| Component | Free tier? | Estimated $ at 100k DAU |
|-----------|-----------|--------------------------|
| Compute (sweeper) | Railway free | $0 |
| DB | Supabase free | $0 (saves storage) |
| **Total** | | **$0** target |

## 12. Done Definition

- [ ] All tasks above checked.
- [ ] Mod-help center article.
- [ ] Metrics dashboard live.
- [ ] Beta feedback ≥4.0/5.
- [ ] Zero P0/P1 in 14-day window.
