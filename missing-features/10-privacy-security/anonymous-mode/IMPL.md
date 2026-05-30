# Anonymous Mode — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze + threat-model review | 3d | PM/Sec |
| 1 | DB schema + migration 215 | 2d | Backend |
| 2 | HMAC service + handle generator | 3d | Backend |
| 3 | Anon-join handler + ban-check middleware | 4d | Backend |
| 4 | Mod panel API + security-definer fn | 3d | Backend |
| 5 | Mobile join-sheet redesign | 3d | Mobile |
| 6 | Mobile mod panel + reveal flow | 4d | Mobile |
| 7 | Realtime hookup + audit-log redaction | 2d | Both |
| 8 | QA + accessibility audit + threat re-review | 4d | QA/Sec |
| 9 | Beta in 10 internal servers | 5d | All |
| 10 | GA | 1d | All |

Total: ~34 working days, two engineers.

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/215_anonymous_mode.up.sql` + `.down.sql`.
- [ ] HMAC key provisioning script `scripts/anon_mode_keygen.sh` (writes to Vault `kv/privacy/anon_mode_hmac/v1`).
- [ ] Model `backend/internal/models/anon_handle.go` — `AnonMember`, `AnonBan`, `AnonSettings`.
- [ ] Service `backend/internal/services/privacy/anonymous_mode/service.go`.
  - [ ] `JoinAnonymously(ctx, serverID, userID) (*AnonMember, error)` — checks settings, generates handle, computes HMAC, inserts row.
  - [ ] `RevealIdentity(ctx, serverID, userID) error`.
  - [ ] `ListAnonMembers(ctx, serverID, modUserID) ([]AnonMember, error)` — calls `mod_anon_member_view`.
  - [ ] `BanAnonMember(ctx, serverID, internalHash, modUserID, reason, expiresAt) error`.
- [ ] HMAC helper `backend/internal/services/privacy/anonymous_mode/hash.go`.
  - [ ] `func ComputeHash(serverID, userID uuid.UUID, key []byte) [32]byte`.
  - [ ] `func ResolveBan(ctx, hash) (bool, error)` checks against current + previous key versions.
- [ ] Handle generator `backend/internal/services/privacy/anonymous_mode/handle_gen.go`.
  - [ ] Adjective+noun word lists (curated, ~500 each, no slurs).
  - [ ] Collision retry, max 5; widen digits if exhausted.
- [ ] Handler `backend/internal/handlers/anon_handle_handler.go`.
- [ ] Wire routes in `backend/cmd/server/main.go`.
- [ ] Centrifugo channel `anon:server:<id>` publish on join/leave/reveal.
- [ ] Permission middleware: ensure mod-required endpoints check `role_flags & 2`.
- [ ] Audit-log redactor sidecar: ensure `anon_*` log entries never contain `user_id` field.
- [ ] Metrics: counters for joins, reveals, ban-evasion attempts, handle collisions.
- [ ] OpenAPI doc update.
- [ ] Service tests (table-driven, ≥85% cov).
- [ ] Handler tests including RLS-bypass attempts (negative cases).
- [ ] Security tests: ensure direct `SELECT * FROM server_anon_members` as non-self yields zero rows.

## 3. Mobile Tasks

- [ ] Feature folder `mobile/lib/features/privacy/anonymous_mode/`.
- [ ] Data: `AnonHandleDto`, `AnonHandleRepository`, `AnonHandleRemoteDataSource`.
- [ ] Domain: `AnonMember` entity, `JoinAnonymouslyUsecase`, `RevealIdentityUsecase`, `BanAnonMemberUsecase`.
- [ ] Application: `anonJoinProvider`, `anonMemberListProvider`, `anonSettingsProvider` (Riverpod).
- [ ] Presentation: `AnonJoinSheet`, `AnonHandlePreview`, `AnonMemberCard`, `RevealIdentityDialog`, `ModAnonMembersTab`.
- [ ] Routing: add to `app_router.dart` (`/server/:id/join` accepts `anon=1` query).
- [ ] L10n keys in `mobile/lib/l10n/app_en.arb` (~25 new keys).
- [ ] Tests: widget + provider + golden for join sheet and reveal dialog.
- [ ] Empty/error/loading states across all screens.
- [ ] Hide friend-presence dots in anon-mode server contexts (extend `PresenceIndicator`).
- [ ] Suppress global search visibility for anon-only members (filter in `MemberSearchProvider`).

## 4. AI / Infra Tasks

- [ ] Anon-avatar generator: deterministic SVG from handle seed (Go service in `internal/services/privacy/anonymous_mode/avatar_gen.go`). No AI; pure geometry.
- [ ] Vault: register HMAC key path; rotation policy doc.
- [ ] No AI components in v1.

## 5. Files Touched (predicted)

```
backend/
  internal/services/privacy/anonymous_mode/service.go        (new)
  internal/services/privacy/anonymous_mode/hash.go           (new)
  internal/services/privacy/anonymous_mode/handle_gen.go     (new)
  internal/services/privacy/anonymous_mode/avatar_gen.go     (new)
  internal/handlers/anon_handle_handler.go                   (new)
  internal/models/anon_handle.go                             (new)
  internal/repo/anon_handle_repo.go                          (new)
  cmd/server/main.go                                         (edit)
  internal/middleware/audit_redactor.go                      (edit)
mobile/
  lib/features/privacy/anonymous_mode/...                    (new tree)
  lib/features/server_join/presentation/join_sheet.dart      (edit)
  lib/features/moderation/presentation/mod_panel.dart        (edit)
  lib/features/profile/presentation/profile_screen.dart      (edit)
  lib/core/router/app_router.dart                            (edit)
  lib/l10n/app_en.arb                                        (edit)
supabase/
  migrations/215_anonymous_mode.up.sql                       (new)
  migrations/215_anonymous_mode.down.sql                     (new)
scripts/
  anon_mode_keygen.sh                                        (new)
```

## 6. Test Plan

- **Unit:** ≥85% on new code; HMAC determinism; handle uniqueness retry; ban-resolve across key versions.
- **Integration:** Postgres + Redis + Centrifugo via testcontainers; full join → ban → re-join evasion attempt → blocked.
- **Security tests:**
  - Direct query bypass: as non-self, `SELECT * FROM server_anon_members` returns 0 rows.
  - Mod posing as direct querier: `SELECT user_id` from mod-view raises.
  - Audit log scan: simulate 1k anon actions, grep result for `user_id` → must be empty.
  - HMAC key rotation: ban under v1 still blocks join after key rotated to v2.
- **E2E:** Maestro flow — join anon, post message, mod sees handle only, mod bans, user attempts re-join → rejected.
- **Load:** k6 — 100 anon joins/sec for 5m. p99 < 600ms.
- **Accessibility:** axe + manual screen reader pass on join sheet and reveal dialog.

## 7. Rollout & Feature Flags

- Flag: `feature.anonymous_mode.enabled` (Doppler).
- Per-server flag: `server_anon_settings.allow_anon_joins`.
- Default OFF in prod.
- Beta: 10 internal Flicko-staff servers.
- Canary: 1% of public servers (auto-enable owner-side toggle visibility) → 10% → 50% → 100% over 14d.
- Kill switch tested in staging; flipping it immediately disables join-anon endpoint, leaves existing anon members intact.

## 8. Rollback Plan

1. Disable global flag (instant; users can no longer use anon mode going forward).
2. Existing anon memberships continue to function — do not auto-reveal anyone.
3. Stop Centrifugo publishes for `anon.*` events if they cause issues.
4. Down migration 215 only as last resort — would orphan ban records and is destructive of user privacy state.
5. If a P0 privacy bug ships (e.g. user_id leak), force-flag-off immediately, rotate HMAC key, post incident report.

## 9. Dependencies / Blockers

- Depends on: `services/e2ee/key_manager.go` Vault wiring; `services/audit_log` v2; `services/server_membership` mod-role bit.
- Blocks: `auto-delete-messages` mod actions (will need anon-aware addressing).
- External: Vault availability SLO; Supabase pgsodium for at-rest encryption of `server_anon_members`.

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| user_id leaks into anon log stream | Med | High | log-redactor sidecar + grep test in CI |
| HMAC key compromised | Low | Critical | rotate; old hashes get re-resolved on next join |
| Stylometric deanonymization | Med | Med | docs warning + future "writing-style scrambler" feature |
| Mods abuse "list anon members" | Low | Med | rate-limit + audit-log every mod read |
| Banned user creates new account to bypass | Med | Med | account-age + verified-email gates |

## 11. Cost Model

| Component | Free tier? | Estimated $ at 100k DAU |
|-----------|-----------|--------------------------|
| Compute (HMAC + handle-gen) | Railway free | $0 |
| DB rows | Supabase free up to 500MB | $0 |
| Vault | self-host | $0 |
| Anon-avatar SVG storage | Appwrite free | $0 |
| **Total** | | **$0** target |

## 12. Done Definition

- [ ] All tasks above checked.
- [ ] Code merged to main.
- [ ] Threat-model doc signed off by security lead.
- [ ] Privacy-policy update merged simultaneously with GA.
- [ ] Metrics dashboard live in Grafana.
- [ ] Beta feedback ≥4.0/5; zero P0/P1 privacy bugs in 14-day window.
- [ ] Penetration test on join + mod paths cleared.
