# Smartwatch Support - SCHEMA

## 1. Storage Strategy

The watch is **client-only** for persistence. The phone holds all auth and message data; the watch holds a small working set so it can launch instantly. The backend gets one extension to track watch presence for analytics and to power smarter notifications.

## 2. Backend Schema

### 2.1 Migration `143_create_watch_devices.up.sql`

```sql
-- Tracks paired watch devices for delivery routing and analytics.
CREATE TABLE IF NOT EXISTS watch_devices (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    phone_device_id TEXT NOT NULL,
    platform        TEXT NOT NULL CHECK (platform IN ('wearos', 'watchos')),
    model           TEXT NULL,                -- e.g. "Pixel Watch 2", "Apple Watch Series 9"
    os_version      TEXT NULL,
    app_version     TEXT NOT NULL,
    last_seen_at    TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    notif_pref      TEXT NOT NULL DEFAULT 'mirror'
                       CHECK (notif_pref IN ('mirror', 'priority_only', 'off')),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_watch_devices_user ON watch_devices(user_id);
CREATE INDEX idx_watch_devices_phone ON watch_devices(phone_device_id);
CREATE UNIQUE INDEX uq_watch_devices_user_phone_platform
    ON watch_devices(user_id, phone_device_id, platform);
```

### 2.2 Migration `143_create_watch_devices.down.sql`

```sql
DROP INDEX IF EXISTS uq_watch_devices_user_phone_platform;
DROP INDEX IF EXISTS idx_watch_devices_phone;
DROP INDEX IF EXISTS idx_watch_devices_user;
DROP TABLE IF EXISTS watch_devices;
```

### 2.3 Reused Tables

- `messages` - read-only on the watch path.
- `reactions` - one row inserted per `/react` action via existing handler.
- `notification_queue` (existing) gains a `surfaces TEXT[]` column populated when a notification was also sent to the watch.

```sql
ALTER TABLE notification_queue
    ADD COLUMN IF NOT EXISTS surfaces TEXT[] NOT NULL DEFAULT ARRAY[]::TEXT[];

CREATE INDEX IF NOT EXISTS idx_notification_queue_surfaces
    ON notification_queue USING GIN (surfaces);
```

This is a low-risk, additive change; rolled into the same migration to keep the bundle atomic.

## 3. On-Device Schema (Phone, Hive)

`mobile/lib/features/smartwatch_support/data/`:

```dart
@HiveType(typeId: 90)
class WatchDevice extends HiveObject {
  @HiveField(0) String id;            // device-local id
  @HiveField(1) WatchPlatform platform;
  @HiveField(2) String? model;
  @HiveField(3) String osVersion;
  @HiveField(4) DateTime lastSeenAt;
  @HiveField(5) bool reachable;
  @HiveField(6) String notifPref;
}

@HiveType(typeId: 91)
class WatchActionQueueItem extends HiveObject {
  @HiveField(0) String idempotencyKey;
  @HiveField(1) String path;          // "/reply", "/react", "/mark-read"
  @HiveField(2) String payloadJson;
  @HiveField(3) DateTime queuedAt;
  @HiveField(4) int attempts;
  @HiveField(5) String? lastError;
}
```

## 4. WearOS - Local Storage

### 4.1 DataStore (`flicko_watch.preferences_pb`)

| Key              | Type    | Purpose                              |
|------------------|---------|--------------------------------------|
| `digest_json`    | String  | last digest payload                  |
| `digest_at`      | Long    | epoch ms                             |
| `pending_actions`| String  | JSON array of queued actions         |
| `theme`          | String  | "dark" / "system"                    |
| `last_version`   | String  | last seen phone app version          |

### 4.2 Files (Wear app cache dir)

- `avatars/{userId}.png` - 64x64 thumbnails.
- `notifications/recent.bin` - last 30 notification entries (Protobuf, ~50 KB).

## 5. watchOS - Local Storage

### 5.1 `UserDefaults(suiteName: "group.io.flicko.watch")`

| Key                | Type   | Purpose                              |
|--------------------|--------|--------------------------------------|
| `digestJSON`       | Data   | gzipped digest                       |
| `digestAt`         | Date   | last sync                            |
| `pendingActions`   | Data   | encoded `[QueuedAction]`             |
| `themeOverride`    | String | optional override                    |
| `lastBridgeVersion`| String | for compatibility check              |

### 5.2 FileManager (`Application Support/`)

- `digest.bin` (CBOR) - durable copy used for complications when not signed-in to defaults.
- `avatars/{userId}.png`
- `notifications.cbor` - rolling buffer.

### 5.3 ClockKit Timeline Cache

watchOS automatically persists the last `CLKComplicationTimelineEntry` set; we just feed it from `digest.bin`.

## 6. Redis Keys (Backend, Ephemeral)

| Key                                       | TTL  | Purpose                                  |
|-------------------------------------------|------|------------------------------------------|
| `watch:reachable:{user_id}`               | 60s  | last heartbeat from phone bridge         |
| `watch:notify:rate:{user_id}`             | 30s  | rate limit for watch-bound notifications |
| `watch:idem:{idempotency_key}`            | 24h  | dedupe replays                            |

## 7. Query Patterns

```sql
-- On phone bridge connect, upsert presence
INSERT INTO watch_devices (user_id, phone_device_id, platform, model, os_version, app_version)
VALUES ($1, $2, $3, $4, $5, $6)
ON CONFLICT (user_id, phone_device_id, platform)
DO UPDATE SET last_seen_at = NOW(),
              app_version  = EXCLUDED.app_version,
              updated_at   = NOW();

-- For analytics: how many users actively use the watch in last 7 days
SELECT COUNT(DISTINCT user_id)
  FROM watch_devices
 WHERE last_seen_at > NOW() - INTERVAL '7 days';
```

## 8. Retention

- `watch_devices` rows older than 90 days with no recent presence are pruned by the existing `cleanup_stale_devices` cron.
- Action queue on phone caps at 100 items; oldest evicted.
- Watch-side notification cache caps at 30 entries.

## 9. Privacy

- We never persist message bodies on the watch beyond 30 entries or 24 h, whichever is sooner.
- Voice audio recorded on watch lives in cache only and is purged on app suspend.
- All transit between phone and watch uses platform-encrypted channels.
- Telemetry is aggregated; no PII fields are sent in analytics events.

## 10. Justification for Mostly Client-Only

The watch is a peripheral. Centralizing schema would force the watch to authenticate, refresh tokens, and handle outages independently - which costs battery and engineering time for v1. Keeping persistence on phone + light backend tracking buys us 80% of the value at 20% of the complexity, with a clean upgrade path to standalone watch login in v2.
