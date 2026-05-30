# Voice Message Transcription - SCHEMA

## 1. Storage Strategy

Transcripts have two homes:
- **On-device** (Hive) for every message a user views, so the next view is instant and works offline.
- **Backend** for messages a user authored, so they're searchable by anyone in the conversation and survive device wipes.

Audio itself is already stored by the existing media subsystem; we add nothing to that layer.

## 2. Backend Schema

### 2.1 Migration `145_create_voice_transcripts.up.sql`

```sql
-- Authoritative transcript for messages where the sender opted to attach one.
CREATE TABLE IF NOT EXISTS voice_transcripts (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id      UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    lang            TEXT NOT NULL,
    engine          TEXT NOT NULL,           -- "whisper.cpp:tiny.en" / "whisper.cpp:base.q5_1" / "server:base.q5_1"
    duration_ms     INT NOT NULL,
    text            TEXT NOT NULL,           -- concatenated transcript
    segments        JSONB NOT NULL DEFAULT '[]'::jsonb,
        -- shape: [{"start_ms":0,"end_ms":1840,"text":"...","conf":0.94}]
    confidence      REAL NULL,               -- aggregate 0..1
    fts             TSVECTOR
                    GENERATED ALWAYS AS (to_tsvector('simple', text)) STORED,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX uq_voice_transcripts_message
    ON voice_transcripts(message_id);
CREATE INDEX idx_voice_transcripts_user
    ON voice_transcripts(user_id);
CREATE INDEX idx_voice_transcripts_fts
    ON voice_transcripts USING GIN (fts);

-- Extend messages.fts to include voice transcripts via trigger
CREATE OR REPLACE FUNCTION messages_fts_with_voice() RETURNS trigger AS $$
BEGIN
  NEW.fts := setweight(to_tsvector('simple', COALESCE(NEW.body, '')), 'A')
          || COALESCE(
              (SELECT setweight(fts, 'B') FROM voice_transcripts WHERE message_id = NEW.id),
              ''::tsvector);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_messages_fts_voice ON messages;
CREATE TRIGGER trg_messages_fts_voice
BEFORE INSERT OR UPDATE OF body ON messages
FOR EACH ROW EXECUTE FUNCTION messages_fts_with_voice();
```

### 2.2 Migration `145_create_voice_transcripts.down.sql`

```sql
DROP TRIGGER IF EXISTS trg_messages_fts_voice ON messages;
DROP FUNCTION IF EXISTS messages_fts_with_voice();
DROP INDEX IF EXISTS idx_voice_transcripts_fts;
DROP INDEX IF EXISTS idx_voice_transcripts_user;
DROP INDEX IF EXISTS uq_voice_transcripts_message;
DROP TABLE IF EXISTS voice_transcripts;
```

## 3. On-Device Schema (Hive)

`mobile/lib/features/voice_message_transcription/data/`:

```dart
@HiveType(typeId: 120)
class CachedTranscript extends HiveObject {
  @HiveField(0) String messageId;
  @HiveField(1) String lang;
  @HiveField(2) String engine;
  @HiveField(3) int durationMs;
  @HiveField(4) String text;
  @HiveField(5) List<TranscriptSegment> segments;
  @HiveField(6) double confidence;
  @HiveField(7) DateTime createdAt;
  @HiveField(8) DateTime lastViewedAt;
  @HiveField(9) bool fromServer;
}

@HiveType(typeId: 121)
class TranscriptSegment {
  @HiveField(0) int startMs;
  @HiveField(1) int endMs;
  @HiveField(2) String text;
  @HiveField(3) double conf;
  @HiveField(4) String? lang;     // for code-switched segments
}

@HiveType(typeId: 122)
class TranscriptCacheStats extends HiveObject {
  @HiveField(0) int totalEntries;
  @HiveField(1) int totalBytes;
  @HiveField(2) DateTime lastEvictionAt;
}
```

Box `voice_transcripts.box`. LRU eviction when size > 200 MB or count > 5000.

```dart
@HiveType(typeId: 123)
class TranscribeQueueItem extends HiveObject {
  @HiveField(0) String messageId;
  @HiveField(1) String audioPath;
  @HiveField(2) String? lang;
  @HiveField(3) String preferredEngine;       // "ondevice" | "server"
  @HiveField(4) DateTime queuedAt;
  @HiveField(5) int attempts;
  @HiveField(6) String? lastError;
}
```

## 4. Native Side

### 4.1 Model Files

| Model              | Location                                     | Source            |
|--------------------|----------------------------------------------|-------------------|
| `ggml-tiny.en.bin` | bundled at `Resources/whisper/tiny.en.bin`   | shipped with app   |
| `ggml-base.q5_1.bin` | downloaded to app support dir              | Flicko CDN        |

Hash + size are validated on load (SHA-256 stored alongside file as `.sha256`).

### 4.2 SharedPreferences / UserDefaults

| Key                     | Purpose                            |
|-------------------------|------------------------------------|
| `transcribe.engine`     | user-chosen engine preference      |
| `transcribe.fallback`   | bool                                |
| `transcribe.show_default` | bool, default true                |
| `transcribe.model_path` | absolute path to multilingual model |

## 5. Redis Keys (Backend)

| Key                                       | TTL  | Purpose                                    |
|-------------------------------------------|------|--------------------------------------------|
| `transcribe:idem:{client_hash}:{user}`    | 24 h | dedupe identical audio retries              |
| `transcribe:progress:{transcript_id}`     | 10 m | async progress percentage                   |
| `transcribe:rate:{user_id}`               | 60 s | rate limiter                                |
| `transcribe:result:{transcript_id}`       | 5 m  | cached completed result                     |

## 6. Query Patterns

```sql
-- Look up transcript for a message
SELECT lang, engine, duration_ms, text, segments, confidence
  FROM voice_transcripts
 WHERE message_id = $1;

-- Search in a server, including voice transcripts
SELECT m.id, m.created_at, m.body,
       v.text AS transcript,
       ts_rank(m.fts, q) AS rank
  FROM messages m
  LEFT JOIN voice_transcripts v ON v.message_id = m.id,
       to_tsquery('simple', $2) q
 WHERE m.server_id = $1
   AND m.fts @@ q
 ORDER BY rank DESC
 LIMIT 50;
```

## 7. Indexes

- `uq_voice_transcripts_message` - one transcript per message.
- `idx_voice_transcripts_fts` - GIN over the auto-generated `fts` column.
- `idx_voice_transcripts_user` - user-scoped lookups.

## 8. Capacity Planning

- Average transcript: ~120 chars, ~6 segments, ~1.2 KB JSON. 100k DAU x 5 voice notes / day = 500k rows / day = ~600 MB / day. After 90 days TTL on auxiliary data, steady-state ~50 GB. Within existing Postgres budget.
- Hive on-device: 5000 cached entries x ~1.5 KB = 7.5 MB. Plus segment metadata, ~25 MB worst case. Hard cap 200 MB.
- Redis: ~5 MB peak for in-flight progress.

## 9. Privacy & Retention

- Audio is never written to disk on the backend worker. Held in memory only during decode.
- `voice_transcripts` rows are deleted via the existing message cascade (`ON DELETE CASCADE`).
- On-device cache evicts entries for messages no longer visible after 30 days.
- We never log transcript text to backend logs; only counts and bucketed metrics.

## 10. Migration Order

`145_create_voice_transcripts` runs after `144_create_notification_priorities`. The trigger relies on the existing `messages.fts` column (added in an earlier migration). If `messages.fts` does not exist on a target environment, the migration adds it before defining the trigger.

## 11. Backward Compatibility

- Older clients without transcript support continue to send and receive voice messages normally; they simply won't contribute or display transcripts.
- The trigger on `messages` is additive: insertions without a transcript still produce a valid `tsvector` from body alone.
