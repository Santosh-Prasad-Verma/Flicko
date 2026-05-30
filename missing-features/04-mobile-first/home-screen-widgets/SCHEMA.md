# Home Screen Widgets - SCHEMA

## 1. Storage Strategy

Home screen widgets are mostly **client-side**. We persist:
- Widget configuration (server, channel, size, theme) in Hive on the device.
- Snapshot cache (last fetched messages and metadata) in Hive.
- Cross-isolate handoff via `SharedPreferences` (Android) and App Group `UserDefaults` (iOS) so native widget code can read state without spinning up Flutter.

A small backend table is added so the same widget config can sync across user devices.

## 2. Backend Schema

### 2.1 Migration `142_create_widget_configs.up.sql`

```sql
-- Cross-device sync of widget preferences. Widgets themselves render from
-- on-device cache; this table is metadata only.
CREATE TABLE IF NOT EXISTS widget_configs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    device_id       TEXT NOT NULL,
    platform        TEXT NOT NULL CHECK (platform IN ('ios', 'android')),
    widget_kind     TEXT NOT NULL CHECK (widget_kind IN (
                        'channel_feed', 'unread_badge', 'dm_list',
                        'voice_status', 'now_playing'
                    )),
    size_class      TEXT NOT NULL CHECK (size_class IN ('small', 'medium', 'large')),
    server_id       UUID NULL REFERENCES servers(id) ON DELETE SET NULL,
    channel_id      UUID NULL REFERENCES channels(id) ON DELETE SET NULL,
    theme           TEXT NOT NULL DEFAULT 'system'
                        CHECK (theme IN ('system', 'light', 'dark', 'amoled')),
    refresh_minutes INT  NOT NULL DEFAULT 15 CHECK (refresh_minutes BETWEEN 5 AND 120),
    extras          JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    deleted_at      TIMESTAMPTZ NULL
);

CREATE INDEX idx_widget_configs_user
    ON widget_configs(user_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_widget_configs_user_device
    ON widget_configs(user_id, device_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_widget_configs_channel
    ON widget_configs(channel_id) WHERE deleted_at IS NULL;
```

### 2.2 Migration `142_create_widget_configs.down.sql`

```sql
DROP INDEX IF EXISTS idx_widget_configs_channel;
DROP INDEX IF EXISTS idx_widget_configs_user_device;
DROP INDEX IF EXISTS idx_widget_configs_user;
DROP TABLE IF EXISTS widget_configs;
```

### 2.3 Snapshot endpoint - no new tables

`GET /api/v1/widgets/snapshot?widget_id=...&kind=channel_feed&channel_id=...`

Reads from existing `messages`, `channels`, `members` tables. No persistence backend-side beyond the existing chat schema.

## 3. On-Device Storage (Hive)

Hive boxes live under `getApplicationSupportDirectory()/widget/`.

### 3.1 `widget_configs.box`

```dart
@HiveType(typeId: 80)
class WidgetConfig extends HiveObject {
  @HiveField(0) String widgetId;        // OS-assigned id (Android: int as String, iOS: kind+family)
  @HiveField(1) WidgetKind kind;
  @HiveField(2) WidgetSize size;
  @HiveField(3) String? serverId;
  @HiveField(4) String? channelId;
  @HiveField(5) String theme;           // system|light|dark|amoled
  @HiveField(6) int refreshMinutes;
  @HiveField(7) DateTime createdAt;
  @HiveField(8) DateTime? lastRefreshAt;
  @HiveField(9) String lastRefreshStatus; // ok|stale|offline|auth_required|error
  @HiveField(10) Map<String, dynamic> extras;
}

enum WidgetKind { channelFeed, unreadBadge, dmList, voiceStatus, nowPlaying }
enum WidgetSize { small, medium, large }
```

### 3.2 `widget_cache.box`

```dart
@HiveType(typeId: 81)
class WidgetSnapshot extends HiveObject {
  @HiveField(0) String cacheKey;        // "channel_feed:{channelId}"
  @HiveField(1) DateTime fetchedAt;
  @HiveField(2) int ttlSeconds;
  @HiveField(3) String payloadJson;     // raw JSON, native code parses it
  @HiveField(4) int unreadCount;
  @HiveField(5) String? avatarThumbB64; // small base64 PNG, max 8 KB
}
```

### 3.3 `widget_jobs.box`

Tracks queued refresh jobs and rate-limit windows.

```dart
@HiveType(typeId: 82)
class WidgetRefreshJob {
  @HiveField(0) String widgetId;
  @HiveField(1) DateTime scheduledFor;
  @HiveField(2) int attempts;
  @HiveField(3) String? lastError;
}
```

## 4. Native Side Storage

### 4.1 iOS - App Group `group.io.flicko.widgets`

`UserDefaults(suiteName: "group.io.flicko.widgets")` keys:

| Key                          | Type   | Purpose                                  |
|------------------------------|--------|------------------------------------------|
| `auth_token`                 | String | short-lived JWT for snapshot endpoint    |
| `snapshot.{cacheKey}`        | Data   | gzipped JSON snapshot                    |
| `snapshot.{cacheKey}.fetchedAt` | Date | last successful fetch                    |
| `unread.{channelId}`         | Int    | quick badge count                        |
| `theme`                      | String | system theme override                    |

Files copied to App Group container:
- `widget_avatars/{userId}.png` - 64x64 thumbnails for medium/large widgets.

### 4.2 Android - SharedPreferences `flicko_widgets`

Same key shape as iOS. Avatars stored under `getDir("widget_avatars", Context.MODE_PRIVATE)`.

## 5. Redis Keys (Backend Refresh Coalescing)

Ephemeral only. No persistence assumed.

| Key                                               | Type | TTL  | Purpose                       |
|---------------------------------------------------|------|------|-------------------------------|
| `widget:snapshot:{userId}:{cacheKey}`             | str  | 60s  | last computed snapshot JSON   |
| `widget:rate:{userId}`                            | str  | 60s  | sliding-window counter        |
| `widget:lock:{userId}:{cacheKey}`                 | str  | 5s   | dedupe concurrent fetches     |

## 6. Indexes and Query Patterns

```sql
-- Sync widgets for a device on app launch
SELECT * FROM widget_configs
 WHERE user_id = $1 AND device_id = $2 AND deleted_at IS NULL;

-- Mark widgets dangling when channel deleted (trigger or app-level cascade)
UPDATE widget_configs SET extras = extras || '{"dangling":true}'::jsonb,
                          updated_at = NOW()
 WHERE channel_id = $1 AND deleted_at IS NULL;
```

## 7. Data Volume Estimates

- 1 user averages 1.4 widgets, 30 KB per snapshot, refreshed every 15 min.
- 100k DAU = 140k widget rows, ~4 GB Redis snapshot churn / day, well within free-tier headroom (we use existing self-hosted Redis, $0 added).
- Hive on device: 5 widgets x 50 KB cache = 250 KB worst case.

## 8. Privacy and Retention

- Snapshots never include message bodies older than 24 h on device. We trim at refresh time.
- Soft delete via `widget_configs.deleted_at`; purged after 90 days by the existing `cleanup_soft_deletes` cron.
- App Group container is excluded from iCloud backup (`isExcludedFromBackup = true`) to avoid leaking auth tokens.
