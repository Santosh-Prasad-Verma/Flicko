# Server Soundtrack — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze + license audit of seed tracks | 4d | PM/Legal |
| 1 | DB migration 211 | 1d | Backend |
| 2 | Track ingest pipeline + storage | 3d | Backend |
| 3 | Azure ACS ambient track manager | 5d | Backend |
| 4 | Owner settings handler | 2d | Backend |
| 5 | Mobile player widget + audio session | 5d | Mobile |
| 6 | Member volume / mute settings | 2d | Mobile |
| 7 | Auto-pause heuristics | 3d | Mobile |
| 8 | Track browser/picker UI | 3d | Mobile |
| 9 | QA + a11y audit | 3d | QA |
| 10 | Beta with 10 servers | 5d | All |
| 11 | GA | 1d | All |

Total: ~37d.

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/211_server_soundtrack.up.sql`.
- [ ] Down migration.
- [ ] Models `backend/internal/models/soundtrack_track.go`, `server_soundtrack.go`, `member_soundtrack_pref.go`.
- [ ] Service `backend/internal/services/soundtrack/service.go`:
  - Server pick/clear/volume.
  - Member pref set.
  - Track listing.
- [ ] Azure ACS manager `backend/internal/services/soundtrack/azure_acs_manager.go`:
  - Create/destroy ambient room on demand.
  - Publish ambient track from server-side ingest of audio file.
  - Looping logic.
- [ ] Track ingest job `backend/internal/jobs/soundtrack_ingest.go`:
  - Normalize loudness to -16 LUFS.
  - Encode to opus 64 kbps.
  - Upload to Appwrite.
- [ ] Handlers `backend/internal/handlers/soundtrack_handler.go`.
- [ ] Wire routes.
- [ ] Audit log entries.
- [ ] Metrics counters.
- [ ] Seed migration `supabase/migrations/211_seed_tracks.up.sql` with 80 rows.

## 3. Mobile Tasks

- [ ] Feature folder `mobile/lib/features/soundtrack/`.
- [ ] Data: dto + repository + datasource + Azure ACS subscriber.
- [ ] Domain: entities + usecases.
- [ ] Application: providers `soundtrack_provider.dart`, `soundtrack_volume_provider.dart`.
- [ ] Presentation:
  - `soundtrack_player_bar.dart` (docked under server header)
  - `soundtrack_picker_screen.dart`
  - `soundtrack_settings_section.dart` (global preferences)
- [ ] Audio session: integrate `audio_session: ^0.1.21`.
- [ ] Auto-pause hooks:
  - listen to call join via existing voice provider.
  - listen to app lifecycle `AppLifecycleState.paused`.
  - listen to battery saver.
- [ ] L10n keys.
- [ ] Tests: provider state machine; widget golden of player bar collapsed/expanded.

## 4. AI / Infra Tasks

- N/A.

## 5. Files Touched (predicted)

```
backend/
  internal/services/soundtrack/service.go         (new)
  internal/services/soundtrack/azure_acs_manager.go (new)
  internal/jobs/soundtrack_ingest.go              (new)
  internal/handlers/soundtrack_handler.go         (new)
  internal/models/soundtrack_track.go             (new)
  internal/models/server_soundtrack.go            (new)
  cmd/server/main.go                              (edit)
mobile/
  lib/features/soundtrack/...                     (new tree, ~12 files)
  lib/core/router/app_router.dart                 (edit)
  lib/l10n/app_en.arb                             (edit)
supabase/
  migrations/211_server_soundtrack.up.sql         (new)
  migrations/211_server_soundtrack.down.sql       (new)
  migrations/211_seed_tracks.up.sql               (new)
```

## 6. Test Plan

- Unit: provider transitions; auto-pause matrix (call/background/battery saver).
- Integration: Voice room create/destroy, track switch, member subscribe.
- E2E: owner picks track → member sees player bar → mute → auto-pause on call.
- Load: 100 concurrent rooms with 50 listeners each; CPU + bandwidth profiled.
- Accessibility: player bar reachable by keyboard, mute announced.
- Security: ingest sanitizer rejects malformed audio.

## 7. Rollout & Feature Flags

- Flag: `feature.server_soundtrack.enabled`.
- Default OFF in prod.
- Beta: 10 servers, 10 tracks seeded.
- Canary 1% → 10% → 50% → 100% over 10d.

## 8. Rollback Plan

1. Disable flag — server soundtracks stop, members stop subscribing.
2. Voice rooms torn down by manager on flag flip.
3. Leave data; re-enable later.

## 9. Dependencies / Blockers

- Depends on: existing Azure ACS infra (already used for voice).
- Depends on: legal sign-off on seed tracks.
- Blocks: nothing.

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Azure ACS cost overrun | M | H | shared room only when listeners present |
| License issue with seed tracks | L | H | track license URL + audit before seed |
| Battery drain | M | M | auto-pause on background + low-power |
| Audio ducking fights with TTS / voice | M | M | audio_session category mixed-with-others |
| Members find it annoying | M | L | global "no soundtracks" toggle, prominent |

## 11. Cost Model

| Component | Free tier? | Estimated $ at 100k DAU |
|-----------|-----------|--------------------------|
| Azure ACS | self-hosted | $0 (VM cost amortized) |
| Storage | Appwrite free | $0 |
| Egress | counts | ~$50/mo if 8% adoption |
| DB | Supabase free | $0 |
| **Total** | | **~$50/mo at 100k DAU** |

Acceptable; represents per-server P2 cost.

## 12. Done Definition

- [ ] All tasks above checked
- [ ] 80 tracks seeded with license metadata
- [ ] Auto-pause matrix passes
- [ ] Code merged
- [ ] Mute rate <30% in beta
- [ ] Zero P0/P1 bugs in 7-day window
