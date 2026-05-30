# Cross-Server Channels — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze + design + RFC review | 4d | PM/Design/Eng |
| 1 | DB schema + migration 197 | 2d | Backend |
| 2 | Backend service + perm intersector + dispatcher | 7d | Backend |
| 3 | Mobile UI + compose chip | 6d | Mobile |
| 4 | Wire-up + Centrifugo + NATS | 3d | Both |
| 5 | QA + accessibility + chaos test | 4d | QA |
| 6 | Beta rollout | 5d | All |
| 7 | GA | 2d | All |

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/197_cross_server_channels.up.sql`
- [ ] Down migration
- [ ] Models `backend/internal/models/social/cross_server_link.go`
- [ ] Service `backend/internal/services/social/cross-server-channels/service.go`
- [ ] Perm intersector `perms.go`
- [ ] Mod overlay `mod_overlay.go`
- [ ] Dispatcher `dispatcher.go`
- [ ] Repo `backend/internal/repo/social/cross_server_repo.go`
- [ ] Handler `backend/internal/handlers/social/cross_server_handler.go`
- [ ] Wire routes
- [ ] Centrifugo `link:<id>` + `channel:<cid>` registration
- [ ] NATS subjects subscribed by dispatcher
- [ ] Audit log entries
- [ ] Metrics counters
- [ ] OpenAPI doc update

## 3. Mobile Tasks

- [ ] Feature folder `mobile/lib/features/social/cross-server-channels/`
- [ ] DTOs, repository, datasource
- [ ] Domain entities + intersected perm result
- [ ] Riverpod providers (link state, members, compose perms)
- [ ] Presentation: link_badge, link_manage_sheet, propose_dialog, compose_chip, local_mod_menu
- [ ] Routing
- [ ] L10n keys
- [ ] Tests: widget golden, provider, perms unit
- [ ] Empty/error/loading states

## 4. AI / Infra Tasks

- [ ] None in v1

## 5. Files Touched (predicted)

```
backend/
  internal/services/social/cross-server-channels/service.go      (new)
  internal/services/social/cross-server-channels/perms.go        (new)
  internal/services/social/cross-server-channels/mod_overlay.go  (new)
  internal/services/social/cross-server-channels/dispatcher.go   (new)
  internal/handlers/social/cross_server_handler.go               (new)
  internal/models/social/cross_server_link.go                    (new)
  internal/repo/social/cross_server_repo.go                      (new)
  cmd/server/main.go                                             (edit)
mobile/
  lib/features/social/cross-server-channels/...                  (new tree)
  lib/features/messaging/presentation/composer.dart              (edit)
  lib/features/messaging/presentation/channel_header.dart        (edit)
supabase/
  migrations/197_cross_server_channels.up.sql                    (new)
  migrations/197_cross_server_channels.down.sql                  (new)
```

## 6. Test Plan

- Unit: perm intersector across role schemes; mod overlay; dispatcher dedup; >=85%
- Integration: testcontainers Postgres + NATS + Centrifugo with 3-server link
- E2E: Maestro post-from-A and verify visible-in-B
- Load: k6 200 msg/s sustained; verify p99 fanout <800ms
- Accessibility: link badge and compose chip
- Security: cross-server permission bypass attempts; banned-user visibility tests; XSS via shared message store

## 7. Rollout & Feature Flags

- Flag: `feature.cross_server_channels.enabled`
- Default OFF in prod
- Beta: 8 owner volunteer pairs
- Canary: 1% -> 10% -> 50% -> 100% over 14d (slower)

## 8. Rollback Plan

1. Disable flag
2. Hide cross-server UI
3. Existing links: dispatcher continues for inflight; new posts blocked
4. After observation period, optional dissolve

## 9. Dependencies / Blockers

- Depends on: stable messaging, perms model, NATS
- Blocks: nothing (but unlocks shared moderation patterns)

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Inconsistent fanout | M | H | at-least-once + dedup; chaos test |
| Permission gap | M | H | exhaustive perms tests; deny-by-default |
| Bad-actor spillover | M | M | local mod actions, kill-switch per link |
| Dispatcher backlog | L | M | autoscale workers; alert at 5s lag |

## 11. Cost Model

| Component | Free tier? | Estimated $ at 100k DAU |
|-----------|-----------|--------------------------|
| Compute | Railway free | $0 |
| DB | Supabase free | $0 |
| AI | n/a | $0 |
| Storage | reduced via dedup | $0 |
| **Total** | | **$0 target** |

## 12. Done Definition

- [ ] All tasks above checked
- [ ] Code merged to main
- [ ] In-tree spec files updated
- [ ] Dashboard live
- [ ] Beta feedback >=4.0/5
- [ ] Zero P0/P1 bugs in 14-day window
