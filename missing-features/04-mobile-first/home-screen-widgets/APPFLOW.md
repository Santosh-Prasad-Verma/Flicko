# Home Screen Widgets - APPFLOW

## 1. High-Level User Journey

```
[User installs Flicko]
        │
        ▼
[Onboarding completes]
        │
        ▼
[User long-presses home screen] ──► [Picks "Flicko" widget gallery]
        │                                       │
        ▼                                       ▼
[Widget added with default config]   [Configures size/server/channel]
        │
        ▼
[Widget renders snapshot from Hive cache]
        │
        ▼
[Background refresh every 15 min via WorkManager / BGAppRefreshTask]
        │
        ▼
[Tap a row in widget] ──► [Deep link opens Flicko at /server/:id/channel/:id]
```

## 2. Sequence Diagram - Initial Widget Render

```mermaid
sequenceDiagram
    participant OS as Home Launcher
    participant W as Widget Provider (Glance/WidgetKit)
    participant SHM as SharedPreferences / App Group
    participant Cache as Hive (widget_cache.box)
    participant App as Flicko Flutter App
    participant API as Flicko Backend

    OS->>W: provideGlance() / timeline()
    W->>SHM: read widget_configs[widget_id]
    alt config missing
        W-->>OS: render "Configure Flicko" placeholder
    else config present
        W->>Cache: read latest snapshot for serverId/channelId
        alt cache fresh (<15m)
            W-->>OS: render rich state
        else cache stale or empty
            W->>App: trigger headless isolate fetch
            App->>API: GET /api/v1/widgets/snapshot?...
            API-->>App: 200 {messages, members, status}
            App->>Cache: write snapshot
            App->>SHM: bump last_refresh_at
            W-->>OS: render rich state
        end
    end
```

## 3. Sequence Diagram - Background Refresh

```mermaid
sequenceDiagram
    participant Sched as WorkManager (Android) / BGTaskScheduler (iOS)
    participant Bridge as home_widget bridge
    participant Iso as Background Isolate
    participant API as Backend
    participant Cache as Hive

    Sched->>Bridge: invoke callbackDispatcher()
    Bridge->>Iso: spawn HomeWidgetBackgroundService
    Iso->>Cache: load enabled widget_configs
    loop per widget
        Iso->>API: GET /api/v1/widgets/snapshot
        API-->>Iso: snapshot JSON
        Iso->>Cache: write snapshot
    end
    Iso->>Bridge: HomeWidget.updateWidget(name)
    Bridge->>Sched: complete success
```

## 4. State Machine - Widget Lifecycle

```
                     ┌──────────────┐
   add to home  ───► │ UNCONFIGURED │
                     └──────┬───────┘
                            │ user picks server/channel
                            ▼
                     ┌──────────────┐    network ok    ┌────────────┐
                     │  CONFIGURED  │ ───────────────► │   FRESH    │
                     └──────┬───────┘                  └─────┬──────┘
                            │                                │ 15m TTL
                            │ network err or not signed in   ▼
                            │                          ┌────────────┐
                            │                          │   STALE    │
                            │                          └─────┬──────┘
                            │                                │ refresh
                            ▼                                ▼
                     ┌──────────────┐                  ┌────────────┐
                     │  ERROR (auth │ ◄────────────────│ REFRESHING │
                     │  / 401 / no  │                  └────────────┘
                     │   network)   │
                     └──────┬───────┘
                            │ user opens app + reauths
                            ▼
                     ┌──────────────┐
                     │   RECOVERED  │
                     └──────────────┘
```

## 5. Tap Interaction Flow

```mermaid
sequenceDiagram
    participant User
    participant Widget
    participant OS
    participant App as Flicko App
    participant Router as GoRouter

    User->>Widget: taps row "#general - 3 unread"
    Widget->>OS: WidgetUrl: flicko://server/abc/channel/xyz?msg=msg_42
    OS->>App: launch + intent
    App->>Router: parseDeepLink(uri)
    Router->>Router: push /server/abc/channel/xyz with scrollTo=msg_42
    App-->>User: chat opens scrolled to msg
```

## 6. Edge Cases

### 6.1 Offline (no network)
- Background isolate detects `SocketException`, marks `last_refresh_status=offline`.
- Widget continues rendering last cached snapshot with a small "offline" badge.
- Tap still deep-links into the app; the app shows offline-mode chat.

### 6.2 Auth expired (401)
- Snapshot endpoint returns 401.
- Background job stores `auth_required=true` flag.
- Widget renders "Sign in to Flicko" CTA. Tap opens `/auth/login`.

### 6.3 Server / channel deleted
- Backend returns 410 Gone.
- Widget config marks `dangling=true` and prompts reconfigure.

### 6.4 Low battery / Doze mode
- Android: WorkManager constraints (`requiresBatteryNotLow=false`, `requiresCharging=false`) but min interval bumped to 30 min when battery <15%.
- iOS: BGAppRefreshTask is throttled by the OS. Treat any window as best-effort.

### 6.5 Widget removed by user
- Provider receives `onDeleted(widgetId)`. App receives broadcast via home_widget; we delete the matching `widget_configs` row.

### 6.6 App not signed in at all
- Default placeholder widget shows logo + "Open Flicko to start". No backend calls attempted.

### 6.7 Glance / WidgetKit size class change
- Re-render triggered automatically. Layout selects a `Compact`, `Medium`, or `Large` template based on `GlanceModifier.size` / `WidgetFamily`.

### 6.8 OS-level dark/light mode flip
- Widget reads `Theme.of(context).colorScheme` (Glance) / `colorScheme` env (WidgetKit). No extra refresh needed.

### 6.9 Background callback not registered
- If Flutter engine cold-starts, `home_widget` re-registers `callbackDispatcher` via `@pragma('vm:entry-point')`. Failing that, widget shows cached data only.

### 6.10 Multiple widgets, same channel
- Snapshot is keyed by `channelId`, shared across widgets. Refresh dedupes by channel.

## 7. Refresh Cadence Summary

| Trigger              | Android                   | iOS                          |
|----------------------|---------------------------|------------------------------|
| Periodic             | WorkManager 15m           | BGAppRefreshTask, OS-paced   |
| App foreground sync  | on AppLifecycleState.resumed | same                       |
| New message push     | FCM data-only -> trigger update | APNs background -> update |
| Manual refresh tap   | tappable refresh icon     | tappable refresh icon        |
