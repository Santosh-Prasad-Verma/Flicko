# Smartwatch Support - IMPL

## 1. Phasing

| Phase | Duration | Goal                                                                        |
|-------|----------|-----------------------------------------------------------------------------|
| P0    | 4 days   | Bridge plumbing - method/event channels, WatchConnectivity, Wearable Data   |
| P1    | 6 days   | WearOS module skeleton: app activity, tile, notification listener           |
| P2    | 6 days   | watchOS extension skeleton: app scene, complications, notification scene    |
| P3    | 5 days   | Reply chooser (text/voice/emoji), action queue with idempotency             |
| P4    | 4 days   | Complications: corner, rectangular, tile. Background refresh wiring         |
| P5    | 3 days   | Polish: motion, haptics, accessibility                                      |
| P6    | 2 days   | Telemetry, kill switch, staged rollout                                      |

Total: ~30 working days, 1 mobile engineer + 0.25 backend engineer.

## 2. Module Layout

### 2.1 Flutter (Phone, Dart)
```
mobile/lib/features/smartwatch_support/
  data/
    watch_bridge.dart                   // platform channels
    watch_action_queue_repository.dart
    watch_device_repository.dart
  domain/
    watch_device.dart
    watch_action.dart
  application/
    watch_bridge_service.dart           // Riverpod service
    watch_digest_builder.dart
    watch_action_dispatcher.dart        // pops queue, sends to backend
  presentation/
    watch_settings_screen.dart          // pairing, prefs, queue debug
    providers/
      watch_bridge_provider.dart
  l10n/
    intl_*.arb
```

### 2.2 WearOS (`mobile/android/wear/`)
```
wear/
  build.gradle.kts
  src/main/
    AndroidManifest.xml
    kotlin/io/flicko/wear/
      MainActivity.kt
      App.kt
      bridge/
        FlickoListenerService.kt        // WearableListenerService
        DigestStore.kt
        ActionDispatcher.kt
      ui/
        DigestScreen.kt
        ServerDetailScreen.kt
        NotificationDetailScreen.kt
        ReplyChooserScreen.kt
        components/
          UnreadRow.kt
          VoicePulseDot.kt
          WaveformVisualizer.kt
      tiles/
        FlickoTileService.kt
      complications/
        UnreadCountComplication.kt
        VoiceStatusComplication.kt
      data/
        DataStoreKeys.kt
        AvatarCache.kt
        NotificationBuffer.kt
      notif/
        FlickoNotificationListener.kt
      worker/
        DigestRefreshWorker.kt
```

### 2.3 watchOS (`mobile/ios/Watch/`)
```
Watch/
  FlickoWatch.entitlements
  Info.plist
  Sources/
    FlickoWatchApp.swift                // @main
    Bridge/
      WatchSessionManager.swift
      DigestStore.swift
      ActionQueue.swift
    Views/
      DigestView.swift
      ServerDetailView.swift
      NotificationDetailView.swift
      ReplyChooserView.swift
      Components/
        UnreadRow.swift
        VoicePulseDot.swift
        WaveformView.swift
    Complications/
      UnreadCountComplication.swift
      VoiceStatusComplication.swift
      RectangularComplication.swift
    Audio/
      WatchRecorder.swift               // AVAudioRecorder
    Theme/
      Theme.swift
```

### 2.4 Backend (Go)
```
backend/internal/handlers/watch/
  presence_handler.go
backend/internal/watch/
  module.go
  service.go
  repo.go
backend/migrations/
  143_create_watch_devices.up.sql
  143_create_watch_devices.down.sql
```

## 3. Phase Tasks

### P0 - Bridge
1. Method channel `io.flicko/watch_bridge` (platform-side handlers).
2. Event channel `io.flicko/watch_events` (incoming actions).
3. iOS: `WCSession` activation, delegate methods.
4. Android: `WearableListenerService` registration in `AndroidManifest.xml`.
5. Dart `WatchBridge` wraps both with a uniform API.

### P1 - WearOS Skeleton
6. New Gradle module `wear` linked from root `settings.gradle.kts`.
7. Compose-for-Wear app shell with SwipeDismissNavigation.
8. `DigestScreen` reads from DataStore.
9. `FlickoListenerService` writes incoming `/digest` and `/notification` payloads.
10. Stub tile + complications returning placeholder.

### P2 - watchOS Skeleton
11. Add `Flicko Watch App` target. Set companion bundle id.
12. `FlickoWatchApp` with `WindowGroup` -> `DigestView`.
13. `WatchSessionManager` activates on appear; processes incoming messages.
14. ClockKit complications shells.

### P3 - Replies
15. `ReplyChooserScreen` (Compose) and `ReplyChooserView` (SwiftUI). Three modes.
16. Voice recording: `MediaRecorder` (Wear) and `AVAudioRecorder` (Watch).
17. Encode audio to 16k mono WAV, base64 encode, send via bridge.
18. Phone receives audio: feed into Whisper.cpp FFI; if unavailable, POST `/api/v1/transcribe`.
19. Action queue with idempotency keys (UUID v4) and exponential backoff.

### P4 - Complications
20. WearOS tile updates via `TileUpdateRequester` on digest write.
21. watchOS `getTimeline` returns one entry; `reloadTimeline` triggered on `WCSession` digest update.
22. Active-voice complication: bound to phone's existing voice presence event.

### P5 - Polish
23. Haptics map per spec. Use `WKHapticType` and `Vibrator` API.
24. Animation timings match UIUX.
25. Audit: VoiceOver/TalkBack pass on each screen.
26. Localization: import existing ARB strings; add 14 new keys.

### P6 - Rollout
27. Backend: presence endpoint `POST /api/v1/devices/watch-presence` (lightweight upsert).
28. Telemetry events.
29. Feature flag `watch_enabled`. 5% -> 25% -> 100% over 10 days.

## 4. Test Plan

### 4.1 Unit (Dart)
- `watch_bridge_service_test.dart` - encode/decode, channel mocks.
- `watch_action_queue_test.dart` - queue ordering, retries, idempotency.

### 4.2 WearOS
- `DigestStoreTest.kt` - serialization round-trip.
- `ActionDispatcherTest.kt` - retry/backoff.
- Compose UI tests for each screen via `createComposeRule`.

### 4.3 watchOS
- XCTest: `WatchSessionManagerTests`, `ActionQueueTests`.
- Snapshot tests via `swift-snapshot-testing` for views and complications.

### 4.4 Integration
- Phone <-> WearOS: scripted notification + reply path on Pixel + Pixel Watch 2.
- Phone <-> watchOS: same on iPhone 15 + Apple Watch Series 9.
- Disconnect tests: turn Bluetooth off mid-reply, verify queue replays.

### 4.5 Manual QA Matrix
| Phone           | Watch                  | Scenarios                                |
|-----------------|------------------------|------------------------------------------|
| Pixel 8         | Pixel Watch 2          | Cold launch, reply, voice, complication  |
| Galaxy S23      | Galaxy Watch 6         | Tile refresh, mute action                |
| iPhone 15 Pro   | Apple Watch S9         | Complications, reply, low-power mode     |
| iPhone 13       | Apple Watch SE 2       | Background tasks, off-wrist              |

## 5. Rollout

1. Internal dogfood: 5 days.
2. TestFlight + Play Internal: 14 days, ~1k testers.
3. Open beta: 21 days. Watch error rate target < 1%.
4. GA gated by feature flag. Kill switch flips to disable bridge writes; watch app shows "Update Flicko on phone."

## 6. $0 Cost Justification

- WatchConnectivity + Wearable Data Layer are first-party, free.
- WearOS Compose, ClockKit, WidgetKit-on-watch: free.
- No third-party transcription. Whisper.cpp via FFI is OSS (MIT).
- Backend additions reuse existing Postgres + Redis. One small table, one small endpoint.
- No new managed services. Total marginal infra: $0.

## 7. Risks & Mitigations

| Risk                                       | Mitigation                                                     |
|--------------------------------------------|----------------------------------------------------------------|
| Apple review flags voice payload privacy   | Onboarding disclosure; opt-in mic permission                   |
| Watch battery drain                        | Push coalescing, tile refresh ceiling, off-wrist suppression   |
| OS bridge API changes (WatchConnectivity)  | Pin minimum OS, smoke-test in CI on each Xcode update          |
| Whisper unavailable on older phones        | Server fallback `/api/v1/transcribe`                           |
| Action queue grows unbounded               | Hard cap 100, oldest evicted, surface in settings              |
| User has phone DND but wants watch alerts  | "Bypass DND on watch" toggle in settings                       |

## 8. Success Criteria

- Watch DAU >= 8% of mobile DAU within 12 weeks.
- Median reply RTT < 1.2 s text, < 4 s voice.
- Crash-free sessions >= 99.4%.
- Notification dismiss rate down 22% vs phone-only control.
