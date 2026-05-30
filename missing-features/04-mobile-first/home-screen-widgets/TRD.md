# Home Screen Widgets — Technical Requirements

## 1. Architecture Overview

```
+----------------------------------------------------------+
|                    iOS / Android Home                    |
|  +---------+  +---------+  +---------+  +---------+      |
|  | Unread  |  | QReply  |  | Recent  |  | Friends |      |
|  +----+----+  +----+----+  +----+----+  +----+----+      |
+-------|------------|------------|------------|------------+
        |            |            |            |
        v            v            v            v
+----------------------------------------------------------+
|         Native Widget Extension (Swift / Kotlin)         |
|  - Reads from shared App Group / SharedPreferences       |
|  - Writes intent payload back through deep link          |
+----------------------------------------------------------+
                          ^  (refresh)
                          |
+----------------------------------------------------------+
|              Flutter App Process (foreground)            |
|  home_widget package -> WidgetBridge service             |
|  Riverpod -> WidgetCacheNotifier -> serializeForWidget() |
+----------------------------------------------------------+
                          ^
                          |
+----------------------------------------------------------+
|                Background Refresh Worker                 |
|  iOS: BGAppRefreshTask (15m) + APNs silent push          |
|  Android: WorkManager periodic 15m + FCM data message    |
+----------------------------------------------------------+
                          ^
                          |
+----------------------------------------------------------+
|       Backend: GET /api/v1/widgets/digest?cfg_id=...     |
|       Centrifugo channel: widget:<user_id>               |
+----------------------------------------------------------+
```

## 2. Components

### Backend (Go)
- **Service:** `backend/internal/services/widgets/digest_service.go` — assembles a single payload for all widget faces in one query.
- **Handler:** `backend/internal/handlers/widgets/digest_handler.go` — `GET /api/v1/widgets/digest`, `PUT /api/v1/widgets/config`.
- **Model:** `backend/internal/models/widget_config.go`, `widget_digest.go`.
- **Worker:** `backend/internal/services/widgets/push_worker.go` — listens to message-created NATS events, debounces 30s per user, fires APNs `content-available:1` / FCM data message.
- **Repo:** `backend/internal/repo/widget_config_repo.go`.

### Mobile (Flutter)
- Feature folder: `mobile/lib/features/home_widgets/`
  - `data/widget_digest_dto.dart`, `widget_digest_repository.dart`
  - `domain/widget_digest.dart`, `widget_face.dart`
  - `application/widget_cache_notifier.dart` (Riverpod)
  - `presentation/widget_config_screen.dart`, `widgets/face_preview_card.dart`
- Bridge: `mobile/lib/features/home_widgets/services/widget_bridge.dart` — wraps `home_widget` package, exposes `pushDigestToNative(WidgetDigest)`.

### Native iOS
- `mobile/ios/Widgets/FlickoWidgets/` (new target):
  - `FlickoWidgetBundle.swift` (entry)
  - `UnreadPulseWidget.swift` (S/M/L)
  - `QuickReplyWidget.swift` (M)
  - `RecentServerWidget.swift` (S/M)
  - `FriendStatusWidget.swift` (M/L)
  - `TimelineProvider.swift` — reads App Group `group.app.flicko` shared UserDefaults
  - `IntentHandler.swift` — for configurable widgets (server picker, friend picker)

### Native Android
- `mobile/android/app/src/main/java/app/flicko/glance/`:
  - `UnreadPulseWidget.kt` (Glance)
  - `QuickReplyWidget.kt`
  - `RecentServerWidget.kt`
  - `FriendStatusWidget.kt`
  - `WidgetUpdateWorker.kt` (WorkManager)
  - `WidgetReceiver.kt` (registered in AndroidManifest)
  - `glance_appwidget_info_*.xml` (4 metadata files in `res/xml/`)

### Infra
- DB: Supabase Postgres — `widget_configs` table.
- Realtime: Centrifugo channel `widget:<user_id>` for instant refresh hint.
- Cache: Redis `widget:digest:<user_id>` TTL 60s.
- Storage: none (icons are baked into binary).
- Push: APNs `content-available` silent push; FCM data-only message.

## 3. API Contracts

### REST
```
GET    /api/v1/widgets/digest                fetch precomputed payload
PUT    /api/v1/widgets/config                upsert config
GET    /api/v1/widgets/config                read config
POST   /api/v1/widgets/quick-reply           send DM reply from widget
```

### Centrifugo
- Channel: `widget:<user_id>`
- Events: `widget.refresh` (no body, just a kick)

### Payloads
```jsonc
// GET /api/v1/widgets/digest response
{
  "generated_at": "2026-05-29T10:00:00Z",
  "ttl_seconds": 900,
  "unread": {
    "total": 17,
    "mentions": 3,
    "per_server": [
      { "server_id": "s_1", "name": "Game Devs", "icon_url": "...", "unread": 5, "mentions": 1 }
    ]
  },
  "recent_dm": {
    "thread_id": "dm_22",
    "peer_name": "Aisha",
    "peer_avatar": "...",
    "snippet": "see you at 7?",
    "received_at": "2026-05-29T09:55:00Z"
  },
  "recent_servers": [
    { "id": "s_1", "name": "Game Devs", "icon_url": "...", "unread": 5 }
  ],
  "friends": [
    { "user_id": "u_2", "name": "Aisha", "avatar": "...", "presence": "online", "status_text": "coding" }
  ]
}

// PUT /api/v1/widgets/config
{
  "muted_servers": ["s_99"],
  "pinned_friends": ["u_2","u_3","u_4","u_5","u_6","u_7"],
  "show_dm_preview": true,
  "include_mention_only": false
}

// POST /api/v1/widgets/quick-reply
{ "thread_id": "dm_22", "body": "on my way" }
```

## 4. Permissions & Auth

- Widget extension shares the auth token via App Group keychain (iOS) / EncryptedSharedPreferences (Android).
- Token refresh handled by main app; widget reads, never refreshes.
- If token expired, widget shows "Open Flicko to refresh" face.
- Quick-reply endpoint requires same scope as DM send: `dm.write` on the target thread.

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| Widget render time (cold) | <120ms on iPhone 12 |
| Widget render time (warm) | <40ms |
| Background refresh job | <250ms server-side |
| p50 digest latency | <80ms |
| p99 digest latency | <300ms |
| Battery delta over 24h | <=1.2% |
| Memory ceiling iOS extension | <30MB (system limit) |
| Memory ceiling Glance | <50MB |

## 6. Dependencies

- `home_widget: ^0.7.0` (Flutter)
- `androidx.glance:glance-appwidget:1.1.1`
- `androidx.work:work-runtime-ktx:2.9.1`
- iOS WidgetKit (system, iOS 14+)
- Centrifugo client already in app

## 7. Observability

- Metrics: `flicko_widget_render_total{platform,face,size}`, `flicko_widget_refresh_total`, `flicko_widget_quick_reply_total`.
- Logs: structured JSON with `widget_face`, `user_id_hash`, `latency_ms`.
- Sentry: separate dist channel `widget-ios` / `widget-android` to keep symbolication clean.
- Grafana board `home-widgets` with adoption funnel and battery delta panel (sourced from RUM).

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| App Group container missing (iOS reinstall) | widget shows placeholder | detect nil, show "Open Flicko" CTA |
| Token expired in widget | quick-reply 401 | open app via deep link, retry post-launch |
| Backend digest 5xx | stale data shown | render last cached payload, mark "updated 12m ago" |
| Glance crash on Samsung | widget removed by OS | telemetry trip, fallback to legacy RemoteViews |
| APNs silent push throttled | refresh delayed | WorkManager / BGAppRefresh polling fallback |
| User has 200+ servers | digest payload too big | server cap at top 8 by recent activity |
