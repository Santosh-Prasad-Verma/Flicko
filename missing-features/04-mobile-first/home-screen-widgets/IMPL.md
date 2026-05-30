# Home Screen Widgets - IMPL

## 1. Phasing

| Phase | Duration | Goal                                                                                  |
|-------|----------|---------------------------------------------------------------------------------------|
| P0    | 3 days   | Plumbing - `home_widget` package wiring, App Group, manifest entries, Hive boxes      |
| P1    | 5 days   | iOS WidgetKit small/medium "channel feed" + Android Glance equivalent                 |
| P2    | 4 days   | Background refresh (WorkManager + BGAppRefreshTask), snapshot endpoint, Redis cache   |
| P3    | 3 days   | Configuration UI inside the Flutter app, deep linking, dangling-widget recovery       |
| P4    | 3 days   | Theming, AMOLED variant, large size with avatars, accessibility audit                 |
| P5    | 2 days   | Telemetry, kill switch, staged rollout                                                |

Total: ~20 working days, one mobile engineer + half a backend engineer.

## 2. Dependencies (pubspec.yaml)

```yaml
dependencies:
  home_widget: ^0.6.0          # Flutter <-> native bridge
  workmanager: ^0.5.2          # Android background scheduling
  hive: ^2.2.3
  hive_flutter: ^1.1.0
  path_provider: ^2.1.4
  flutter_riverpod: ^2.5.1
```

iOS additions:
- `mobile/ios/Runner.xcodeproj` - new target `FlickoWidgets` (WidgetKit extension).
- App Group `group.io.flicko.widgets` enabled on both targets.

Android additions:
- `mobile/android/app/build.gradle` - `compileSdk 34`, `glance` BoM `1.1.0`.

## 3. File / Module Layout

### 3.1 Flutter (Dart)
```
mobile/lib/features/home_widgets/
  data/
    widget_config_repository.dart
    widget_snapshot_repository.dart
    widget_api_client.dart
  domain/
    widget_config.dart            // Hive model
    widget_snapshot.dart
    widget_kind.dart
  application/
    widget_refresh_service.dart   // background callback dispatcher
    widget_sync_service.dart      // syncs configs across devices
  presentation/
    widget_gallery_screen.dart
    widget_config_screen.dart
    widget_preview_card.dart
    providers/
      widget_configs_provider.dart
      widget_refresh_provider.dart
  platform/
    home_widget_bridge.dart       // wraps `home_widget` package
    deep_link_handler.dart
```

### 3.2 iOS (Swift)
```
mobile/ios/Widgets/
  FlickoWidgets.swift              // @main WidgetBundle
  ChannelFeedWidget/
    ChannelFeedWidget.swift
    ChannelFeedProvider.swift      // TimelineProvider
    ChannelFeedEntry.swift
    Views/
      CompactChannelView.swift
      MediumChannelView.swift
      LargeChannelView.swift
  UnreadBadgeWidget/
    UnreadBadgeWidget.swift
  Shared/
    AppGroupStore.swift            // UserDefaults wrapper
    SnapshotDecoder.swift
    Theme.swift
    DeepLink.swift
  Assets.xcassets/
```

### 3.3 Android (Kotlin)
```
mobile/android/app/src/main/kotlin/io/flicko/widgets/glance/
  FlickoGlanceReceiver.kt
  ChannelFeedWidget.kt
  UnreadBadgeWidget.kt
  data/
    SnapshotStore.kt
    PrefsKeys.kt
  ui/
    ChannelFeedContent.kt
    UnreadBadgeContent.kt
    Theme.kt
  worker/
    WidgetRefreshWorker.kt
mobile/android/app/src/main/res/xml/
  channel_feed_widget_info.xml
  unread_badge_widget_info.xml
```

### 3.4 Backend (Go)
```
backend/internal/handlers/widgets/
  snapshot_handler.go
  config_handler.go
backend/internal/widgets/
  module.go
  service.go
  cache.go            // Redis coalescing
backend/migrations/
  142_create_widget_configs.up.sql
  142_create_widget_configs.down.sql
```

## 4. Detailed Task List

### P0 - Plumbing
1. Add `home_widget`, `workmanager`, Hive deps. Generate Hive adapters.
2. Register App Group `group.io.flicko.widgets`. Enable on Runner + FlickoWidgets targets.
3. Add `flutter_app_group_id` to Info.plist. Add Android `<provider>` for `home_widget`.
4. Wire `HomeWidget.setAppGroupId` and `HomeWidget.registerInteractivityCallback` at app start.
5. Add a `widget://` deep link scheme to `app_router.dart`.

### P1 - First Widgets
6. Implement `ChannelFeedWidget` SwiftUI views for `.systemSmall`, `.systemMedium`, `.systemLarge`.
7. Implement `ChannelFeedWidget` Glance composable mirroring layout.
8. Read snapshot from App Group / SharedPreferences. Decode JSON.
9. Render placeholder + error states (offline, sign-in needed, dangling channel).
10. Hook tap actions to `widgetUrl(URL("flicko://server/...))`.

### P2 - Backend & Background
11. Migration 142. Repo + service + handler. Open routes in `gaming/module.go` style.
12. `GET /api/v1/widgets/snapshot` returns `{messages:[...], unread, members, generated_at}`.
13. Redis coalescing with 60s TTL keyed by `userId+cacheKey`.
14. Android `WidgetRefreshWorker` periodic 15-min job.
15. iOS `BGAppRefreshTask` scheduled in `AppDelegate.application(_:didFinishLaunchingWithOptions:)`.
16. `widget_refresh_service.dart` - the `@pragma('vm:entry-point') callbackDispatcher` Flutter side.

### P3 - Config UI
17. Widget gallery screen, accessible from Settings -> Widgets.
18. Per-widget config screen: pick server, pick channel, size selector, theme override.
19. Sync configs to backend on save. Pull configs on app launch (idempotent merge).
20. Detect dangling channel (410) and surface a toast in-app + on widget.

### P4 - Theming & A11y
21. AMOLED variant with `Color.black` background.
22. Use `LocalContentColor` (Glance) and `Color.primary` (SwiftUI) for auto contrast.
23. Add `accessibilityLabel` per row. Verify VoiceOver / TalkBack flow.
24. Dynamic Type / Material font scaling - clamp at 1.4x to prevent layout breakage.

### P5 - Telemetry & Rollout
25. Emit metrics via existing `/api/v1/telemetry/event` (see Observability in TRD).
26. Feature flag `widgets_enabled` (LaunchDarkly OSS / self-hosted flagsmith - already in stack).
27. Roll out 5% -> 25% -> 100% over 7 days.

## 5. Test Plan

### 5.1 Unit (Dart)
- `widget_config_repository_test.dart` - CRUD round-trip with in-memory Hive.
- `widget_snapshot_repository_test.dart` - TTL + eviction.
- `widget_refresh_service_test.dart` - retry/backoff logic, 401 surfaces auth_required.

### 5.2 Native
- iOS snapshot tests: render each size class with mock entries (FlickoWidgetsTests).
- Android Glance preview tests with `GlanceAppWidgetReceiver` test harness.

### 5.3 Backend (Go)
- `snapshot_handler_test.go` - happy path, 401, 410, rate limit (429).
- `cache_test.go` - coalescing under concurrent reads via `t.Parallel`.

### 5.4 Integration
- Patrol/integration_test - configure widget, simulate background refresh, verify deep link.
- iOS: manually verify via Xcode Widgets simulator preview.
- Android: `adb shell am broadcast -a android.appwidget.action.APPWIDGET_UPDATE`.

### 5.5 Manual QA Matrix
| Device                  | Sizes | Theme   | Background |
|-------------------------|-------|---------|------------|
| Pixel 7 (Android 14)    | S/M/L | L/D/AM  | Doze, normal |
| Galaxy S22 (One UI 6)   | S/M/L | L/D     | normal     |
| iPhone 13 (iOS 17)      | S/M/L | L/D     | low-power  |
| iPad mini (iPadOS 17)   | M/L/XL| L/D     | normal     |

## 6. Rollout

1. Internal dogfood (Flicko team) - 3 days.
2. Closed beta (TestFlight + Play Internal) - 7 days, 500 users.
3. Open beta - 14 days. Monitor refresh failure rate (< 2 percent target).
4. GA gated by feature flag. Kill switch flips `widgets_enabled=false` and the app no-ops the bridge.

## 7. $0 Cost Justification

- WidgetKit and Glance are first-party, free.
- `home_widget` package is OSS (BSD-3).
- Snapshot endpoint reuses existing Postgres + Redis already deployed.
- Background scheduling is OS-provided.
- Telemetry piggybacks on existing `events` table.
- No third-party services. Total marginal infra cost: $0.

## 8. Risks & Mitigations

| Risk                                              | Mitigation                                              |
|---------------------------------------------------|---------------------------------------------------------|
| iOS BGAppRefresh throttled, widget shows stale    | Explicit "stale at" timestamp, manual refresh button    |
| Auth token expiry inside widget                   | Short-lived widget token, refresh on app foreground     |
| Glance limited composables (no LazyColumn nested) | Cap at 5 rows; use `LazyColumn` only at root           |
| home_widget callback drops on Flutter upgrade     | Pin version, smoke test in CI on each Flutter bump      |
| Snapshot leaks PII via App Group                  | Exclude container from iCloud, encrypt with `CryptoKit` AES-GCM if extras flagged sensitive |
