# Smart Notifications - IMPL

## 1. Phasing

| Phase | Duration | Goal                                                                       |
|-------|----------|----------------------------------------------------------------------------|
| P0    | 3 days   | Capability probe + heuristic classifier + plumbing                         |
| P1    | 5 days   | LLM classifier (Android Gemini Nano + iOS Phi-3-mini via Mediapipe)        |
| P2    | 4 days   | NotificationPolicy + DigestQueue + system notification channels            |
| P3    | 4 days   | Settings UI, quiet-hours, per-channel overrides                            |
| P4    | 3 days   | "Why this?" screen + feedback loop + bias store                            |
| P5    | 3 days   | Backend migration + preferences endpoint + sync                            |
| P6    | 3 days   | Telemetry, kill switch, automatic degradation, rollout                     |

Total: ~25 working days, 1 mobile + 0.25 backend + 0.25 ML eng.

## 2. Module Layout

### 2.1 Flutter
```
mobile/lib/features/smart_notifications/
  data/
    notif_prefs_repository.dart
    notif_inbox_repository.dart
    notif_bias_repository.dart
    notif_digest_repository.dart
    notif_api_client.dart
    classifier/
      classifier.dart                  // abstract
      llm_classifier.dart
      heuristic_classifier.dart
      capability_probe.dart
      prompt_template.dart
      json_validator.dart
  domain/
    notif_prefs.dart
    notif_inbox_entry.dart
    classification_result.dart
    tier.dart
  application/
    notif_ingress_service.dart
    notification_policy.dart
    digest_scheduler.dart
    feedback_collector.dart
    sync_service.dart                  // pull/push prefs
  presentation/
    settings/
      notif_settings_screen.dart
      quiet_hours_sheet.dart
      channel_override_sheet.dart
    inbox/
      inbox_screen.dart
      tier_ribbon.dart
    why/
      why_this_screen.dart
    onboarding/
      smart_notif_onboarding.dart
    providers/
      classifier_provider.dart
      policy_provider.dart
      inbox_provider.dart
  l10n/
    intl_*.arb
```

### 2.2 iOS
```
mobile/ios/NotificationService/
  NotificationService.swift            // UNNotificationServiceExtension
  ClassifierBridge.swift               // calls Mediapipe inference engine
  ModelLoader.swift
  PolicyApplicator.swift
mobile/ios/Runner/
  AppDelegate+Notifications.swift
```

### 2.3 Android
```
mobile/android/app/src/main/kotlin/io/flicko/notifications/
  FlickoMessagingService.kt             // FirebaseMessagingService override
  ClassifierBridge.kt                   // AICore wrapper
  ModelLoader.kt
  PolicyApplicator.kt
  channels/
    NotificationChannelInitializer.kt
```

### 2.4 Backend (Go)
```
backend/internal/handlers/notifications/
  priorities_handler.go
backend/internal/notifications/priorities/
  module.go
  service.go
  repo.go
backend/migrations/
  144_create_notification_priorities.up.sql
  144_create_notification_priorities.down.sql
```

## 3. Phase Tasks

### P0 - Plumbing
1. CapabilityProbe: detect AICore (Android), Phi-3 model availability (iOS).
2. HeuristicClassifier with rules + keyword set.
3. Hive boxes for prefs, inbox, bias, digest queue, classification log.
4. Hook FCM `onBackgroundMessage`. iOS UNNotificationServiceExtension target.
5. Wire `NotifIngressService` to feed payload into classifier.

### P1 - LLM Classifier
6. Add `google_ai_edge_genai` dep + custom platform channel for AICore.
7. Add Mediapipe LLM Inference dep + Core ML compile step. Bundle int4 model.
8. Implement `LLMClassifier`: prompt template + JSON validator + timeout 1 s.
9. Eval harness with 500 hand-labeled samples from internal volunteers.
10. Auto-degradation: track latency p95 over rolling 50 samples; switch to heuristic if > 250 ms.

### P2 - Policy + Digest
11. NotificationPolicy: combine tier, overrides, quiet-hours -> route.
12. DigestQueue + DigestScheduler (WorkManager periodic + iOS BGTask).
13. Notification channels (Android) and categories (iOS).
14. Critical-alert request flow (iOS) gated behind explicit consent.

### P3 - Settings UI
15. Settings hub screen with toggle + summaries.
16. Quiet-hours sheet with time pickers.
17. Per-channel override sheet (server selector + channel selector + tier picker).
18. Onboarding cards (4 steps).

### P4 - Feedback
19. "Why this?" detail screen with prompt and reason rendered locally.
20. Thumbs-up / thumbs-down / mark-urgent actions.
21. FeedbackCollector updates AuthorBias and ChannelBias with clamping + decay.
22. Calibration toast after 5 corrections in a week.

### P5 - Backend
23. Migration 144.
24. `GET /api/v1/preferences/notif/priorities` and `PUT` (idempotent).
25. JSON validation via `validator` Go package.
26. Sync service: pull on app launch, push on settings change with debouncing.

### P6 - Polish + Rollout
27. Telemetry events as in TRD.
28. Feature flag `smart_notif_enabled`.
29. Rollout 5% -> 25% -> 100% over 14 days.
30. Status page banner if model service has issues.

## 4. Test Plan

### 4.1 Unit (Dart)
- `heuristic_classifier_test.dart` - rule coverage.
- `notif_policy_test.dart` - quiet-hours edge cases (TZ DST, midnight wrap).
- `feedback_collector_test.dart` - clamping + decay math.
- `digest_scheduler_test.dart` - coalescing, empty-window no-op.

### 4.2 Native
- iOS: `ClassifierBridgeTests` - prompt round-trip with mocked Mediapipe.
- Android: `ClassifierBridgeTest` - AICore mock with Robolectric.

### 4.3 Backend
- `priorities_handler_test.go` - happy path, schema validation, 401, 429.
- Property-based tests on JSON validator with `quick.Check`.

### 4.4 Eval
- Held-out set of 200 labeled notifications. Targets: precision urgent >= 0.9, recall urgent >= 0.85.
- Re-evaluated weekly for 4 weeks post-launch using anonymous opt-in feedback.

### 4.5 Manual QA
| Scenario                                         | Expected                        |
|--------------------------------------------------|---------------------------------|
| DM during quiet hours, urgent on                 | Buzz + bypass DND if opted in   |
| Loud server with 50 noise messages in 5 min      | One coalesced digest entry      |
| Override on #oncall = urgent                     | Always buzz regardless of LLM   |
| Heuristic fallback active                        | Reasonable behavior, no crash    |
| Model still downloading                          | Heuristic mode with banner       |
| Time-zone change mid-day                         | Quiet-hour wall clock unchanged |

## 5. Rollout

1. Internal: 5 days dogfood.
2. Closed beta: 1k users, 14 days.
3. Open beta: 21 days.
4. GA gated by feature flag. Kill switch flips classifier to heuristic-only globally.
5. Halt rollout if false-negative rate on `urgent` exceeds 2% in any cohort.

## 6. $0 Cost Justification

- Gemini Nano: free, OS-provided.
- Phi-3-mini: open weights (MIT), distributed via existing CDN we already pay for.
- Mediapipe and Core ML: free runtimes.
- Backend additions: one small table, one cached endpoint. No new infra.
- Telemetry: piggybacks on existing pipeline.
- Marginal infra cost: $0.

## 7. Risks & Mitigations

| Risk                                            | Mitigation                                                  |
|-------------------------------------------------|-------------------------------------------------------------|
| Model size bloats binary                        | Defer download to first launch, App Group / app dir         |
| Classifier latency regressions                  | Auto-degradation to heuristic, monitor in telemetry         |
| User trust collapse on missed urgent            | "Why this?" + feedback + on-call override CTA               |
| AICore availability narrower than expected      | Heuristic remains a credible default                         |
| Privacy regulator scrutiny                      | On-device by design + explicit privacy copy in onboarding   |

## 8. Success Criteria

- Notifications per DAU down >= 45%.
- "Too many notifications" complaints down >= 60%.
- Urgent false-negative rate < 1.2%.
- Crash-free sessions >= 99.5% on the notification path.
