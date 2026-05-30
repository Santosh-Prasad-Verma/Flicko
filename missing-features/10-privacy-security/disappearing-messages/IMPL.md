# Disappearing Messages — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze + threat-model review | 2d | PM/Sec |
| 1 | DB migration 216 + sweep function | 2d | Backend |
| 2 | Sweeper attach-delete worker + NATS hookup | 3d | Backend |
| 3 | Send-with-TTL handler patch | 1d | Backend |
| 4 | Mobile composer TTL picker | 2d | Mobile |
| 5 | Mobile countdown chip + ephemeral badge | 2d | Mobile |
| 6 | Per-DM default TTL settings | 2d | Both |
| 7 | QA + load test sweeper at 5k rows/min | 3d | QA |
| 8 | Beta rollout | 4d | All |
| 9 | GA | 1d | All |

Total: ~20 working days, 1 backend + 1 mobile.

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/216_disappearing_messages.up.sql`.
- [ ] Down migration.
- [ ] Update `internal/models/message.go` to add `ExpiresAt *time.Time` and `TtlSeconds *int`.
- [ ] Patch `internal/services/messages/service.go` `SendMessage` to accept TTL and compute `expires_at`.
- [ ] Validate TTL allowlist `{300, 3600, 86400, 604800}`.
- [ ] Worker `internal/services/privacy/disappearing_messages/attachment_sweeper.go`.
  - [ ] Subscribes to PG NOTIFY `disappearing_sweep_attachments`.
  - [ ] Deletes Appwrite blobs.
  - [ ] Removes `attachments` rows.
- [ ] Worker `internal/services/privacy/disappearing_messages/search_sweeper.go`.
  - [ ] Subscribes to PG NOTIFY `disappearing_sweep_search`.
  - [ ] Calls Meilisearch delete-by-id.
- [ ] Centrifugo publisher: on sweep, publish `message.deleted` to `channel:<id>`.
- [ ] Audit-log entries (privacy-preserving, no content).
- [ ] Metrics counters and lag histogram.
- [ ] OpenAPI doc update.
- [ ] Service tests (table-driven, ≥80% cov).
- [ ] Integration test: send 100 ephemeral, advance time, sweeper runs, all gone.
- [ ] Load test: 5k rows/min, sweep duration < 30s.

## 3. Mobile Tasks

- [ ] Feature folder `mobile/lib/features/privacy/disappearing_messages/`.
- [ ] Domain: `MessageTtl` enum (`off`, `m5`, `h1`, `d1`, `d7`).
- [ ] Application: `ttlPickerProvider`, `dmDefaultTtlProvider`.
- [ ] Presentation: `TtlPickerSheet`, `EphemeralBadge`, `CountdownChip`, `DmTtlSettingsTile`.
- [ ] Patch `MessageComposer` to add a clock-icon button → opens `TtlPickerSheet`.
- [ ] Patch `MessageBubble` to render `EphemeralBadge` and `CountdownChip` when `expires_at != null`.
- [ ] Local self-cleanup: when `expires_at` passes on the client, remove the bubble even before realtime delete arrives (defense in depth).
- [ ] Routing: no new routes; settings tile under existing DM settings.
- [ ] L10n keys (~15 new).
- [ ] Tests: widget + provider + golden.

## 4. AI / Infra Tasks

- [ ] None.

## 5. Files Touched (predicted)

```
backend/
  internal/services/privacy/disappearing_messages/service.go         (new)
  internal/services/privacy/disappearing_messages/attachment_sweeper.go (new)
  internal/services/privacy/disappearing_messages/search_sweeper.go  (new)
  internal/services/messages/service.go                              (edit)
  internal/handlers/messages_handler.go                              (edit)
  internal/models/message.go                                         (edit)
mobile/
  lib/features/privacy/disappearing_messages/...                     (new tree)
  lib/features/messaging/presentation/message_composer.dart          (edit)
  lib/features/messaging/presentation/message_bubble.dart            (edit)
  lib/features/dm/presentation/dm_settings_screen.dart               (edit)
supabase/
  migrations/216_disappearing_messages.up.sql                        (new)
  migrations/216_disappearing_messages.down.sql                      (new)
```

## 6. Test Plan

- **Unit:** TTL validation, expires-at math, worker idempotency.
- **Integration:** Postgres + Redis + Centrifugo via testcontainers; full lifecycle (send → wait → sweep → realtime → client removal).
- **E2E (Maestro):** send disappearing message, see countdown, advance device clock, message gone.
- **Load:** k6 — 50 sends/sec with TTLs across distribution; sweeper keeps up.
- **Soak:** 24h run with 1k/hour ephemeral msgs; orphan attachments stay at 0.
- **Security tests:**
  - After sweep, `SELECT * FROM messages WHERE id = <expired_id>` returns 0 rows.
  - `pg_dump` after sweep has no record of the content.
  - Audit log row contains no content payload.
  - Read-replica replication lag does not leak post-delete content beyond 1s.

## 7. Rollout & Feature Flags

- Flag: `feature.disappearing_messages.enabled` (Doppler).
- Worker pause flag: `worker.disappearing_messages.paused`.
- Beta: 5% of DAU.
- Canary: 25% over 7d.

## 8. Rollback Plan

1. Disable flag — composer no longer offers TTL.
2. Existing scheduled sweeps continue (data already past `expires_at` should still be deleted; rolling back the sweeper would be a privacy regression).
3. Down migration only if data corruption — drops table additions, removes column.
4. If sweeper bug deletes wrong rows: pause worker via flag, restore from PITR backup, root-cause before re-enabling.

## 9. Dependencies / Blockers

- pg_cron extension on Supabase Postgres (already enabled).
- Appwrite SDK retry/backoff configured.
- Centrifugo publisher already in use for messages.

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Sweeper deletes wrong rows due to bug | Low | Critical | strict WHERE clause + integration tests + dry-run mode |
| Sweep lag during traffic spike | Med | Med | batch size dynamic + alert at 5min lag |
| Orphaned attachments | Med | Low | nightly orphan-scrub job |
| Backup retention conflicts | Low | Med | document that PITR retains content for restore window |

## 11. Cost Model

| Component | Free tier? | Estimated $ at 100k DAU |
|-----------|-----------|--------------------------|
| Compute (sweeper) | Railway free | $0 |
| DB (saves rows, no growth) | Supabase free | $0 |
| Storage (saves space, net negative) | Appwrite free | $0 |
| **Total** | | **$0** target |

## 12. Done Definition

- [ ] All tasks above checked.
- [ ] Code merged to main.
- [ ] Privacy-policy update merged with GA.
- [ ] Metrics dashboard live.
- [ ] Beta feedback ≥4.0/5.
- [ ] Zero P0/P1 in 14-day window.
