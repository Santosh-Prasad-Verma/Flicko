# Screen Reader Full Support — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze + a11y review with consultant | 3d | PM/Design |
| 1 | Migration 252 + override table + admin tool | 1d | Backend |
| 2 | Mobile core: provider, LiveRegion, LandmarkScaffold, A11yIconButton | 3d | Mobile |
| 3 | Semantics retrofit on the 25 hot widgets | 6d | Mobile |
| 4 | Onboarding A11y step + Settings → Accessibility page | 2d | Mobile |
| 5 | Debug A11yProbe overlay | 1d | Mobile |
| 6 | Tests: golden, Patrol, axe-flutter integration | 3d | QA |
| 7 | External consultant pass + fixes | 4d | All |
| 8 | Beta with blind tester cohort (n=5) | 5d | All |
| 9 | GA + a11y blog post | 1d | All |

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/252_accessibility_screen_reader.up.sql` (see SCHEMA)
- [ ] Down migration `252_accessibility_screen_reader.down.sql`
- [ ] Model `backend/internal/models/accessibility_override.go`
- [ ] Service `backend/internal/services/accessibility/screen_reader/service.go` (loads + caches overrides)
- [ ] Service tests (table-driven, ≥80% cov)
- [ ] Handler `backend/internal/handlers/accessibility/overrides_handler.go`
  - `GET /api/v1/accessibility/overrides?locale=` returns map
  - `POST /api/v1/accessibility/overrides` (staff only) upsert
- [ ] Telemetry handler `backend/internal/handlers/accessibility/telemetry_handler.go`
- [ ] Wire routes in `backend/cmd/server/main.go`
- [ ] Permission middleware (existing `RequireAuth`, `RequireStaff` for write)
- [ ] Audit log entries on override write
- [ ] Metrics counters `flicko_accessibility_overrides_*`, `flicko_accessibility_telemetry_*`
- [ ] OpenAPI doc update

## 3. Mobile Tasks

- [ ] Feature folder `mobile/lib/features/accessibility/screen_reader/`
- [ ] `data/accessibility_repository.dart` — fetch overrides + cache locally
- [ ] `data/preferences_datasource.dart` — read/write `accessibility_json` field
- [ ] `domain/announcement.dart`, `live_region_mode.dart` entities
- [ ] `application/screen_reader_provider.dart` (Riverpod `Notifier`)
- [ ] `application/live_region_controller.dart`
- [ ] `presentation/widgets/landmark_scaffold.dart`
- [ ] `presentation/widgets/a11y_icon_button.dart`
- [ ] `presentation/widgets/announce_on_change.dart`
- [ ] `presentation/widgets/focus_ring.dart`
- [ ] `presentation/screens/accessibility_settings_screen.dart`
- [ ] `presentation/screens/onboarding_a11y_step.dart`
- [ ] `presentation/widgets/a11y_probe_overlay.dart` (debug-only)
- [ ] Routing: add to `mobile/lib/core/router/app_router.dart` (`/settings/accessibility/screen-reader`)
- [ ] L10n keys in `mobile/lib/l10n/app_en.arb` (verbose_title, polite_label, etc.)
- [ ] Tests: 25 golden semantics tests; provider unit; Patrol full traversal
- [ ] Empty/error/loading states on settings screen
- [ ] Apply Semantics retrofit to the 25 hot widgets (TRD section 2)

## 4. AI / Infra Tasks

Not applicable — feature is non-AI.

## 5. Files Touched (predicted)

```
backend/
  internal/services/accessibility/screen_reader/service.go        (new)
  internal/services/accessibility/screen_reader/service_test.go   (new)
  internal/handlers/accessibility/overrides_handler.go            (new)
  internal/handlers/accessibility/telemetry_handler.go            (new)
  internal/models/accessibility_override.go                       (new)
  cmd/server/main.go                                              (edit)

mobile/
  lib/features/accessibility/screen_reader/...                    (new tree)
  lib/core/router/app_router.dart                                 (edit)
  lib/l10n/app_en.arb                                             (edit)
  lib/features/server_channels/.../message_bubble.dart            (edit Semantics)
  lib/features/server_channels/.../message_input.dart             (edit)
  lib/features/server_channels/.../channel_list_item.dart         (edit)
  lib/features/server_channels/.../voice_tile.dart                (edit)
  lib/features/server_channels/.../member_list_item.dart          (edit)
  lib/features/server_channels/.../typing_indicator.dart          (edit)
  lib/features/server_channels/.../reactions_row.dart             (edit)
  lib/features/server_channels/.../message_attachment.dart        (edit)
  lib/features/server_channels/.../mention_chip.dart              (edit)
  lib/features/server/presentation/widgets/server_list_tile.dart  (edit)
  lib/features/home/presentation/home_navigation.dart             (edit)
  lib/features/notifications/.../notification_tile.dart           (edit)
  lib/features/direct_messages/.../dm_thread_tile.dart            (edit)
  lib/features/voice/.../voice_controls_bar.dart                  (edit)
  lib/features/calling/.../incoming_call_sheet.dart               (edit)
  lib/features/profile/.../profile_action_button.dart             (edit)
  lib/features/settings/.../settings_tile.dart                    (edit)
  lib/features/auth/.../oauth_button.dart                         (edit)
  lib/features/onboarding/.../onboarding_step.dart                (edit)
  lib/features/search/.../search_result_item.dart                 (edit)
  lib/features/store/.../store_card.dart                          (edit)
  lib/features/gaming/.../game_card.dart                          (edit)
  lib/features/ai_assistant/.../aura_message_bubble.dart          (edit)
  lib/features/shared/presentation/widgets/snackbar.dart          (edit)
  lib/features/shared/presentation/widgets/bottom_sheet.dart      (edit)

supabase/
  migrations/252_accessibility_screen_reader.up.sql               (new)
  migrations/252_accessibility_screen_reader.down.sql             (new)
```

## 6. Test Plan

- **Unit:** ≥80% coverage on the screen-reader provider, override repository, and Go service.
- **Widget:** golden `findsSemantics` tests for every retrofitted widget.
- **Integration:** Patrol script driving emulator with TalkBack on; assert 12 announcements during a scripted journey.
- **E2E:** Maestro flow `accessibility_screen_reader.yaml` tapping through 6 surfaces.
- **Load:** announcement queue stress test — 100 messages/sec ⇒ debounced output ≤2/sec.
- **Accessibility:** axe-flutter; manual Fable consultant audit.
- **Security:** override write only by staff; tested with non-staff JWT (403).

## 7. Rollout & Feature Flags

- Flag: `feature.screen_reader_full.enabled` (Doppler).
- Default ON in beta and prod (it is largely additive Semantics — risk is low).
- Sub-flag: `feature.screen_reader_full.live_region_assertive.enabled` for the assertive mode default.
- Beta: 5 internal blind testers + Fable cohort.
- Canary: 10% → 50% → 100% over 5 days.
- Kill switch: turning the flag off reverts to baseline Material semantics.

## 8. Rollback Plan

1. Disable flag — landmark roles fall back to default scaffold semantics.
2. Stop telemetry endpoint (graceful 410).
3. Leave migration in place; `accessibility_json` and overrides table are read-only safe.

## 9. Dependencies / Blockers

- Depends on: `user_preferences_service` (already shipped).
- Blocks: `audio-descriptions` (uses LiveRegion), `captions-voice-video` (uses LiveRegion).
- External: external Fable audit booking (~2 weeks lead).

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| TalkBack ignores LiveRegion across rebuild | Medium | Med | Direct `SemanticsService.announce` fallback |
| Performance regression from Semantics tree | Low | Med | Profile p95 frame time; `MergeSemantics` on long lists |
| Localization gaps | High | Low | Fallback to English with explicit Locale tag |
| Override misuse by staff | Low | Low | Audit log + 1-click revert |
| Verbose mode annoys non-AT users who flipped it on | Low | Low | Off by default; explicit toggle |

## 11. Cost Model

| Component | Free tier? | Estimated $ at 100k DAU |
|-----------|-----------|--------------------------|
| Compute (overrides API) | Railway free | $0 |
| DB (overrides table small) | Supabase free | $0 |
| AI | n/a | $0 |
| Storage | n/a | $0 |
| Consultant audit | one-off | ~$3,500 (out of budget category) |
| **Total** | | **$0/mo** ongoing |

## 12. Done Definition

- [ ] All tasks above checked
- [ ] All 25 retrofitted widgets pass golden semantics tests
- [ ] Patrol journey passes on Android 13/14 emulator + iOS 17 sim
- [ ] axe-flutter zero P0 issues
- [ ] External consultant audit signed off
- [ ] Metrics dashboard live
- [ ] Beta feedback ≥4.5/5 from blind tester cohort
- [ ] Zero P0/P1 bugs in 14-day window post-GA
