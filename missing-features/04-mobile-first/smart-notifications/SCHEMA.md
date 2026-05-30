# Smart Notifications - SCHEMA

## 1. Storage Strategy

Most state is **on-device** for privacy: classification artifacts, bias weights, digest queue, and inbox cache live in Hive. The backend stores only user preferences (overrides, quiet hours, digest schedule) so they sync across devices. The classifier never persists message text on the server.

## 2. Backend Schema

### 2.1 Migration `144_create_notification_priorities.up.sql`

```sql
-- Per-user notification preferences. JSON-backed for flexibility; values
-- are mirrored to the device on app launch.
CREATE TABLE IF NOT EXISTS notification_priorities (
    user_id        UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
    enabled        BOOLEAN NOT NULL DEFAULT TRUE,
    quiet_hours    JSONB NOT NULL DEFAULT '{}'::jsonb,
        -- shape: {"start":"22:00","end":"07:00","tz":"Asia/Kolkata","min_tier":"urgent"}
    digest_times   TEXT[] NOT NULL DEFAULT ARRAY['09:00','13:00','18:00']::TEXT[],
    bypass_dnd     BOOLEAN NOT NULL DEFAULT FALSE,
    server_overrides   JSONB NOT NULL DEFAULT '[]'::jsonb,
        -- shape: [{"server_id":"...","boost_tier":1}]
    channel_overrides  JSONB NOT NULL DEFAULT '[]'::jsonb,
        -- shape: [{"channel_id":"...","min_tier":"urgent","max_tier":null,"bypass_dnd":true}]
    created_at     TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at     TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_notification_priorities_updated
    ON notification_priorities(updated_at);
```

### 2.2 Migration `144_create_notification_priorities.down.sql`

```sql
DROP INDEX IF EXISTS idx_notification_priorities_updated;
DROP TABLE IF EXISTS notification_priorities;
```

### 2.3 Validation (server-side, no logic)

The server validates JSON shape via Go struct tags + `validator` package. Tiers are constrained to `{urgent, relevant, social, noise}`. `tz` must be a valid IANA zone.

## 3. On-Device Schema (Hive)

### 3.1 `notif_priorities.box`

```dart
@HiveType(typeId: 100)
class NotifPrefs extends HiveObject {
  @HiveField(0) bool enabled;
  @HiveField(1) QuietHours? quietHours;
  @HiveField(2) List<String> digestTimes;       // "HH:mm"
  @HiveField(3) bool bypassDnd;
  @HiveField(4) List<ServerOverride> serverOverrides;
  @HiveField(5) List<ChannelOverride> channelOverrides;
  @HiveField(6) DateTime lastSyncedAt;
}

@HiveType(typeId: 101)
class QuietHours {
  @HiveField(0) String start;        // "22:00"
  @HiveField(1) String end;          // "07:00"
  @HiveField(2) String tz;           // "Asia/Kolkata"
  @HiveField(3) String minTier;      // "urgent"
}

@HiveType(typeId: 102)
class ChannelOverride {
  @HiveField(0) String channelId;
  @HiveField(1) String? minTier;
  @HiveField(2) String? maxTier;
  @HiveField(3) bool bypassDnd;
}

@HiveType(typeId: 103)
class ServerOverride {
  @HiveField(0) String serverId;
  @HiveField(1) int boostTier;       // -1 .. +2
}
```

### 3.2 `notif_inbox.box` (capped 1000 entries, FIFO)

```dart
@HiveType(typeId: 110)
class NotifInboxEntry extends HiveObject {
  @HiveField(0) String messageId;
  @HiveField(1) String channelId;
  @HiveField(2) String authorId;
  @HiveField(3) String preview;       // truncated 140 chars
  @HiveField(4) DateTime ts;
  @HiveField(5) String tier;          // urgent|relevant|social|noise
  @HiveField(6) String reason;        // <= 60 chars
  @HiveField(7) String source;        // llm|heuristic
  @HiveField(8) int latencyMs;
  @HiveField(9) bool delivered;       // already shown via OS notification?
  @HiveField(10) String route;        // buzz|silent|digest|dnd_bypass
  @HiveField(11) bool readByUser;
}
```

### 3.3 `notif_bias.box` (personalization)

```dart
@HiveType(typeId: 111)
class AuthorBias extends HiveObject {
  @HiveField(0) String authorId;
  @HiveField(1) double score;         // -1.0 .. 1.0
  @HiveField(2) int sampleCount;
  @HiveField(3) DateTime updatedAt;
}

@HiveType(typeId: 112)
class ChannelBias extends HiveObject {
  @HiveField(0) String channelId;
  @HiveField(1) double score;
  @HiveField(2) int sampleCount;
  @HiveField(3) DateTime updatedAt;
}
```

Score deltas are clamped to `+/- 0.05` per feedback event; saturate at `+/- 1.0`. Decay: each entry loses 1% magnitude every 7 days to avoid stale lock-in.

### 3.4 `notif_digest_queue.box`

```dart
@HiveType(typeId: 113)
class DigestEntry extends HiveObject {
  @HiveField(0) String messageId;
  @HiveField(1) String channelId;
  @HiveField(2) String tier;
  @HiveField(3) DateTime queuedAt;
}
```

Capped at 500 entries. Older entries dropped on overflow with a counter incremented.

### 3.5 `notif_classification_log.box` (debug ring buffer)

200 most recent classifications including raw LLM JSON output for the "Why this?" screen. Entries older than 72 h purged.

## 4. Native Side

### 4.1 iOS Notification Service Extension App Group

Stores model warm-load handle and last 50 classification results so the extension can run without spinning up Flutter.

`UserDefaults(suiteName: "group.io.flicko.notifications")`:

| Key                       | Purpose                                       |
|---------------------------|-----------------------------------------------|
| `model_path`              | absolute path to bundled Phi-3 model           |
| `recent_results.{id}`     | per-message classification result (24 h TTL)  |
| `prefs_blob`              | encoded NotifPrefs                             |

### 4.2 Android

Background isolate writes through Hive + the existing `home_widget` SharedPreferences bridge for read by Glance widgets.

## 5. Redis Keys (Backend)

| Key                                | TTL  | Purpose                                  |
|------------------------------------|------|------------------------------------------|
| `notif:prefs:{user_id}`            | 5 m  | cached preferences blob                   |
| `notif:rate:{user_id}`             | 60 s | rate limiter on `/preferences` PUT        |

No per-message keys; the backend is unaware of classification outputs.

## 6. Query Patterns

```sql
-- App launch sync
SELECT enabled, quiet_hours, digest_times, bypass_dnd,
       server_overrides, channel_overrides, updated_at
  FROM notification_priorities
 WHERE user_id = $1;

-- Idempotent upsert
INSERT INTO notification_priorities (user_id, enabled, quiet_hours, digest_times,
                                     bypass_dnd, server_overrides, channel_overrides)
VALUES ($1, $2, $3, $4, $5, $6, $7)
ON CONFLICT (user_id)
DO UPDATE SET enabled = EXCLUDED.enabled,
              quiet_hours = EXCLUDED.quiet_hours,
              digest_times = EXCLUDED.digest_times,
              bypass_dnd = EXCLUDED.bypass_dnd,
              server_overrides = EXCLUDED.server_overrides,
              channel_overrides = EXCLUDED.channel_overrides,
              updated_at = NOW();
```

## 7. Privacy & Retention

- Inbox bodies stored on device only. No server upload.
- Classification log purged after 72 h.
- Bias scores never leave the device.
- Telemetry events contain bucketed metadata only.
- Backend prefs row purged on user delete via the existing cascade.

## 8. Capacity Planning

- 100k DAU x ~600 KB Hive footprint per user worst-case = no backend impact.
- Backend table at 100k users x ~2 KB row = 200 MB. Trivial.
- Redis prefs cache: ~200 MB peak. Within free-tier headroom on existing Redis.

## 9. Migration Order

`144_create_notification_priorities` runs after `143_create_watch_devices`. No data backfill needed; missing rows mean "use defaults".

## 10. Justification for Mostly Client-Side

We treat classification as inherently personal. Putting it on-device aligns the privacy story ("your messages never leave the phone for ranking") with the implementation. The backend stores only the small set of preferences that need cross-device parity, and even those are JSON-shaped to keep schema migrations rare.
