# Read Receipts Control — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze | 1d | PM |
| 1 | DB migration 221 + resolver fn | 1d | Backend |
| 2 | Service patch + reciprocity logic | 2d | Backend |
| 3 | Mobile shared toggle component | 2d | Mobile |
| 4 | Wire DM/friend/server settings | 2d | Mobile |
| 5 | First-time tooltip | 1d | Mobile |
| 6 | One-shot migration job | 1d | Backend |
| 7 | QA + property-based tests | 2d | QA |
| 8 | Beta | 2d | All |
| 9 | GA | 1d | All |

Total: ~13 working days, 1 backend + 1 mobile.

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/221_read_receipts_control.up.sql`.
- [ ] Down migration.
- [ ] Models: `internal/models/user_settings.go` patches; `internal/models/receipt_overrides.go`.
- [ ] Service `internal/services/messaging/receipts.go`.
  - [ ] `ResolvePolicy(ctx, userID, scope) (Policy, error)`.
  - [ ] `ShouldEmitSeen(ctx, senderID, viewerID, scope) bool`.
- [ ] Cache layer with Redis pub/sub invalidation.
- [ ] Patch `messages_handler.go` `markSeen` to consult resolver before publishing event.
- [ ] One-shot migration job: backfill `user_settings` rows with default-off.
- [ ] Service tests.
- [ ] Property-based test: 1000 random scope/override combinations; assert reciprocity invariant.

## 3. Mobile Tasks

- [ ] Feature folder `mobile/lib/features/privacy/read_receipts_control/`.
- [ ] Domain: `ReceiptScope`, `ReceiptPolicy`.
- [ ] Application: `receiptSettingsProvider`, `firstTimeTooltipProvider`.
- [ ] Presentation:
  - [ ] `ReceiptToggleTile` (shared component).
  - [ ] `FirstTimeReceiptTooltip`.
  - [ ] `ReceiptSettingsScreen`.
- [ ] Patch `DmSettingsScreen`, `FriendProfileScreen`, `ServerSettingsScreen`.
- [ ] L10n keys.
- [ ] Tests.

## 4. AI / Infra Tasks

- [ ] None.

## 5. Files Touched (predicted)

```
backend/
  internal/services/messaging/receipts.go            (new)
  internal/services/messaging/service.go             (edit)
  internal/handlers/messages_handler.go              (edit)
  internal/models/user_settings.go                   (edit)
  internal/models/receipt_overrides.go               (new)
  cmd/migrate_receipts_default_off.go                (new, one-shot)
mobile/
  lib/features/privacy/read_receipts_control/...     (new tree)
  lib/features/dm/presentation/dm_settings_screen.dart      (edit)
  lib/features/friends/presentation/friend_profile.dart     (edit)
  lib/features/servers/presentation/server_settings.dart    (edit)
  lib/features/settings/presentation/privacy_screen.dart    (edit)
supabase/
  migrations/221_read_receipts_control.up.sql        (new)
  migrations/221_read_receipts_control.down.sql      (new)
```

## 6. Test Plan

- **Unit:** resolver precedence (DM > friend > server > global); reciprocity property.
- **Integration:** Postgres + Redis testcontainers; toggle, message, observe receipt path.
- **E2E:** Maestro — Alice and Bob both off → no receipts; both on → receipts; one on, other off → none.
- **Migration test:** existing user data converts cleanly to default-off.

## 7. Rollout & Feature Flags

- Flag: `feature.read_receipts_control.enabled`.
- Beta: 10%.
- Canary: 50% over 5d.
- Default-off applies to new + existing users at flip.

## 8. Rollback Plan

1. Disable flag — receipts revert to old global behavior (always on).
2. Override tables stay populated for re-enable.

## 9. Dependencies / Blockers

- Existing messaging service.
- `user_settings` table.

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Existing-user confusion | High | Low | first-time tooltip + help center article |
| Reciprocity bug leaks one-sided | Low | Med | property-based test in CI |
| Cache lag | Low | Low | invalidation pub/sub |

## 11. Cost Model

| Component | Free tier? | Estimated $ at 100k DAU |
|-----------|-----------|--------------------------|
| Compute | Railway free | $0 |
| DB | Supabase free | $0 |
| **Total** | | **$0** target |

## 12. Done Definition

- [ ] All tasks above checked.
- [ ] Help-center article published.
- [ ] Metrics dashboard live.
- [ ] Beta feedback ≥4.0/5.
