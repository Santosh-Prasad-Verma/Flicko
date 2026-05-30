# Screen Capture Protection — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze | 1d | PM |
| 1 | DB migration 218 | 1d | Backend |
| 2 | Backend handlers + consent flow | 3d | Backend |
| 3 | Android FLAG_SECURE plugin wrap | 2d | Mobile |
| 4 | iOS UIScreen observer + scrim | 3d | Mobile |
| 5 | ProtectedScope widget + lifecycle | 2d | Mobile |
| 6 | DM consent UX | 2d | Mobile |
| 7 | Mod settings UI for channel | 1d | Mobile |
| 8 | Realtime hookup | 1d | Both |
| 9 | QA + manual device matrix | 4d | QA |
| 10 | Beta | 3d | All |
| 11 | GA | 1d | All |

Total: ~22 working days, 1 backend + 1 mobile.

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/218_screen_capture_protection.up.sql`.
- [ ] Down migration.
- [ ] Model patches: `internal/models/channel.go`, `internal/models/dm.go`.
- [ ] Service `internal/services/privacy/screen_capture_protection/service.go`.
  - [ ] `SetChannelProtection(ctx, channelID, modID, enabled)`.
  - [ ] `RequestDmProtection(ctx, dmID, requesterID)`.
  - [ ] `ConsentDmProtection(ctx, dmID, userID, consented)`.
  - [ ] `RecordRecordingEvent(ctx, userID, scope, started, stopped)`.
- [ ] Handler `internal/handlers/screen_capture_handler.go`.
- [ ] Wire routes in `cmd/server/main.go`.
- [ ] Permission middleware: only mods can flip channel-level flag.
- [ ] Centrifugo publishers for protection-changed and recording events.
- [ ] Audit-log entries.
- [ ] Service tests + handler tests (≥80% cov).

## 3. Mobile Tasks

- [ ] Add `flutter_windowmanager` dependency.
- [ ] Native plugin wrappers:
  - [ ] `ScreenCapturePlugin.kt` (Android) — toggle FLAG_SECURE.
  - [ ] `ScreenCapturePlugin.swift` (iOS) — `NotificationCenter` observer for `UIScreen.captureDidChangeNotification`.
- [ ] MethodChannel `flicko/screen_capture` with methods:
  - `enable()`, `disable()`, `isCaptured()` and stream of capture-state changes.
- [ ] Feature folder `mobile/lib/features/privacy/screen_capture_protection/`.
- [ ] Domain: `RecordingEvent`, `ProtectionScope`.
- [ ] Application: `protectionScopeProvider` (Riverpod).
- [ ] Presentation:
  - [ ] `ProtectedScope` widget (auto-attach/detach on lifecycle).
  - [ ] `RecordingScrim` overlay.
  - [ ] `RecordingBanner` realtime banner.
  - [ ] `CaptureProtectionInfoSheet` (educates limits).
  - [ ] `DmConsentPrompt`.
  - [ ] `ProtectedChannelBadge`.
- [ ] Wrap `MessagingScreen`, `DmScreen`, `EncryptedVoiceScreen` in `ProtectedScope` when `protected == true`.
- [ ] Wire realtime listener for `screen_capture.recording_*` events.
- [ ] Routing: no new routes.
- [ ] L10n keys (~15 new).
- [ ] Tests: widget + provider + integration with mocked MethodChannel.
- [ ] Web client: stub renders "open in mobile" placeholder for protected scopes.

## 4. AI / Infra Tasks

- [ ] None.

## 5. Files Touched (predicted)

```
backend/
  internal/services/privacy/screen_capture_protection/service.go    (new)
  internal/handlers/screen_capture_handler.go                       (new)
  internal/models/channel.go                                        (edit)
  internal/models/dm.go                                             (edit)
  internal/repo/channels_repo.go                                    (edit)
  cmd/server/main.go                                                (edit)
mobile/
  lib/features/privacy/screen_capture_protection/...                (new tree)
  lib/features/messaging/presentation/messaging_screen.dart         (edit)
  lib/features/dm/presentation/dm_screen.dart                       (edit)
  lib/features/voice/presentation/voice_channel_screen.dart         (edit)
  lib/features/moderation/presentation/channel_security_settings.dart (new)
  android/app/src/main/kotlin/.../ScreenCapturePlugin.kt            (new)
  ios/Runner/ScreenCapturePlugin.swift                              (new)
  ios/Runner/AppDelegate.swift                                      (edit)
supabase/
  migrations/218_screen_capture_protection.up.sql                   (new)
  migrations/218_screen_capture_protection.down.sql                 (new)
```

## 6. Test Plan

- **Unit:** consent recompute logic; recording-event idempotency.
- **Integration:** Postgres + Centrifugo via testcontainers.
- **Device matrix:** Android 10/12/14 stock + Pixel + Samsung; iOS 16/17/18.
- **Manual tests:**
  - Android screenshot in protected channel → produces black image.
  - Android screen-record → black frames.
  - iOS Control-Center record → scrim within 500ms.
  - iOS AirPlay → scrim.
  - Web → "open in mobile" placeholder.
  - Rooted Android → screenshot succeeds; we surface a warning to other side via Play-Integrity check.
- **E2E:** Maestro flow — toggle protection, verify badge, simulate record event, banner appears.

## 7. Rollout & Feature Flags

- Flag: `feature.screen_capture_protection.enabled` (Doppler).
- Beta: 5% of DAU.
- Canary: 25% over 7d.

## 8. Rollback Plan

1. Disable flag — protection toggle hidden.
2. Existing protected channels stay protected.
3. Down migration only as last resort.

## 9. Dependencies / Blockers

- `flutter_windowmanager` package compatibility.
- iOS `UIScreen.captureDidChangeNotification` API stable since iOS 11.
- Play-Integrity API enrolled.

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| FLAG_SECURE bypass on rooted | Med | Med | Warning banner via integrity attestation |
| iOS detection lag on older devices | Med | Med | Document; recommend iOS 16+ |
| Web users confused | Low | Low | Clear placeholder message |
| Plugin breaks on OS upgrade | Low | High | Plugin owned in-house; CI matrix on each iOS beta |

## 11. Cost Model

| Component | Free tier? | Estimated $ at 100k DAU |
|-----------|-----------|--------------------------|
| Compute | Railway free | $0 |
| DB | Supabase free | $0 |
| **Total** | | **$0** target |

## 12. Done Definition

- [ ] All tasks above checked.
- [ ] Manual device matrix passed.
- [ ] Privacy-policy update merged with GA.
- [ ] Metrics dashboard live.
- [ ] Beta feedback ≥4.0/5.
