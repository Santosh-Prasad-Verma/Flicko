# Captions for Voice/Video — Backend Schema

## 1. Tables

### `caption_segments` (new)

Persists finalised caption segments only when participant consent is recorded. Time-partitioned for cheap eviction.

```sql
CREATE TABLE caption_segments (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  channel_id    UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  call_id       UUID NOT NULL,
  speaker_id    UUID REFERENCES users(id) ON DELETE SET NULL,
  speaker_label TEXT,                          -- e.g. "Guest 1" if no user
  text          TEXT NOT NULL,
  language      TEXT NOT NULL DEFAULT 'en',
  t_start_ms    BIGINT NOT NULL,
  t_end_ms      BIGINT NOT NULL,
  is_final      BOOLEAN NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
) PARTITION BY RANGE (created_at);

-- 7 day partitions; janitor handles drop
CREATE INDEX idx_caption_segments_call ON caption_segments(call_id, t_start_ms);
CREATE INDEX idx_caption_segments_channel ON caption_segments(channel_id, created_at DESC);
```

### `caption_consents` (new)

Per-call ledger. A row per consenting participant.

```sql
CREATE TABLE caption_consents (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  call_id     UUID NOT NULL,
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  consented   BOOLEAN NOT NULL,
  consent_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  withdrawn_at TIMESTAMPTZ,
  UNIQUE (call_id, user_id)
);

CREATE INDEX idx_caption_consents_call ON caption_consents(call_id);
```

### `caption_server_settings` (new)

Per-server toggle.

```sql
CREATE TABLE caption_server_settings (
  server_id        UUID PRIMARY KEY REFERENCES servers(id) ON DELETE CASCADE,
  enabled          BOOLEAN NOT NULL DEFAULT FALSE,
  default_language TEXT NOT NULL DEFAULT 'en',
  retain_segments  BOOLEAN NOT NULL DEFAULT FALSE,    -- if true, segments persisted with consent
  updated_by       UUID REFERENCES users(id) ON DELETE SET NULL,
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### `user_preferences.accessibility_json` (existing) — keys added

```jsonc
{
  "captions_enabled": true,
  "captions_size": "medium",            // small | medium | large
  "captions_position": "bottom",        // top | center | bottom
  "captions_opacity": 0.85,
  "captions_per_speaker_color": true,
  "captions_language": "en"
}
```

## 2. RLS Policies

```sql
ALTER TABLE caption_segments ENABLE ROW LEVEL SECURITY;
ALTER TABLE caption_consents ENABLE ROW LEVEL SECURITY;
ALTER TABLE caption_server_settings ENABLE ROW LEVEL SECURITY;

-- Members of the channel can read
CREATE POLICY "Channel members can read segments"
  ON caption_segments FOR SELECT
  USING (
    channel_id IN (
      SELECT c.id FROM channels c
      JOIN server_members m ON m.server_id = c.server_id
      WHERE m.user_id = auth.uid()
    )
  );

CREATE POLICY "Service role writes segments"
  ON caption_segments FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

CREATE POLICY "Self can manage consent"
  ON caption_consents FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Members can read server settings"
  ON caption_server_settings FOR SELECT
  USING (
    server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid())
  );

CREATE POLICY "Admins can write server settings"
  ON caption_server_settings FOR ALL
  USING (
    EXISTS (
      SELECT 1 FROM server_admins WHERE server_id = caption_server_settings.server_id AND user_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM server_admins WHERE server_id = caption_server_settings.server_id AND user_id = auth.uid()
    )
  );
```

## 3. Triggers

```sql
CREATE TRIGGER caption_server_settings_set_updated_at
  BEFORE UPDATE ON caption_server_settings
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
```

A janitor cron drops segment partitions older than 7 days.

## 4. Migration File

Path: `supabase/migrations/258_accessibility_captions.up.sql`
Down: `supabase/migrations/258_accessibility_captions.down.sql`

```sql
-- up
BEGIN;

CREATE TABLE IF NOT EXISTS caption_segments (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  channel_id    UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  call_id       UUID NOT NULL,
  speaker_id    UUID REFERENCES users(id) ON DELETE SET NULL,
  speaker_label TEXT,
  text          TEXT NOT NULL,
  language      TEXT NOT NULL DEFAULT 'en',
  t_start_ms    BIGINT NOT NULL,
  t_end_ms      BIGINT NOT NULL,
  is_final      BOOLEAN NOT NULL DEFAULT TRUE,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
) PARTITION BY RANGE (created_at);

-- Today partition
DO $$
DECLARE start_d DATE := CURRENT_DATE; end_d DATE := CURRENT_DATE + 1;
BEGIN
  EXECUTE format(
    'CREATE TABLE IF NOT EXISTS caption_segments_%s PARTITION OF caption_segments FOR VALUES FROM (%L) TO (%L)',
    to_char(start_d, 'YYYYMMDD'), start_d, end_d
  );
END $$;

CREATE INDEX IF NOT EXISTS idx_caption_segments_call    ON caption_segments(call_id, t_start_ms);
CREATE INDEX IF NOT EXISTS idx_caption_segments_channel ON caption_segments(channel_id, created_at DESC);

CREATE TABLE IF NOT EXISTS caption_consents (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  call_id     UUID NOT NULL,
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  consented   BOOLEAN NOT NULL,
  consent_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  withdrawn_at TIMESTAMPTZ,
  UNIQUE (call_id, user_id)
);
CREATE INDEX IF NOT EXISTS idx_caption_consents_call ON caption_consents(call_id);

CREATE TABLE IF NOT EXISTS caption_server_settings (
  server_id        UUID PRIMARY KEY REFERENCES servers(id) ON DELETE CASCADE,
  enabled          BOOLEAN NOT NULL DEFAULT FALSE,
  default_language TEXT NOT NULL DEFAULT 'en',
  retain_segments  BOOLEAN NOT NULL DEFAULT FALSE,
  updated_by       UUID REFERENCES users(id) ON DELETE SET NULL,
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE caption_segments        ENABLE ROW LEVEL SECURITY;
ALTER TABLE caption_consents        ENABLE ROW LEVEL SECURITY;
ALTER TABLE caption_server_settings ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Channel members can read segments"
  ON caption_segments FOR SELECT
  USING (
    channel_id IN (
      SELECT c.id FROM channels c
      JOIN server_members m ON m.server_id = c.server_id
      WHERE m.user_id = auth.uid()
    )
  );

CREATE POLICY "Service role writes segments"
  ON caption_segments FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

CREATE POLICY "Self can manage consent"
  ON caption_consents FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Members can read server settings"
  ON caption_server_settings FOR SELECT
  USING (
    server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid())
  );

CREATE POLICY "Admins can write server settings"
  ON caption_server_settings FOR ALL
  USING (
    EXISTS (SELECT 1 FROM server_admins WHERE server_id = caption_server_settings.server_id AND user_id = auth.uid())
  )
  WITH CHECK (
    EXISTS (SELECT 1 FROM server_admins WHERE server_id = caption_server_settings.server_id AND user_id = auth.uid())
  );

CREATE TRIGGER caption_server_settings_set_updated_at
  BEFORE UPDATE ON caption_server_settings
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

COMMIT;
```

```sql
-- down
BEGIN;
DROP TRIGGER IF EXISTS caption_server_settings_set_updated_at ON caption_server_settings;
DROP TABLE IF EXISTS caption_consents;
DROP TABLE IF EXISTS caption_server_settings;
DROP TABLE IF EXISTS caption_segments;
COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `captions:live:<channel_id>` | rolling stream of last 50 segments | 30 min |
| `captions:settings:<server_id>` | server settings JSON | 5 min |
| `captions:lastseq:<channel_id>` | last published seq | session |

## 6. Search Index (Meilisearch)

Optional v2: index `caption_segments` with `channel_id`, `call_id`, `text`, `language` for searchable transcripts.

## 7. Vector Index (Qdrant)

Not applicable.

## 8. Object Storage (Appwrite)

- Bucket: `captions`
- Allowed MIME: `application/x-subrip`
- Max file size: 5 MB
- Permission: `read("user:{hostId}")`, `write("service_role")`
- TTL: 30 days

## 9. Data Retention

- Live caption stream (Redis): 30 min after call ends.
- `caption_segments`: dropped automatically after 7 days unless server has `retain_segments=true`.
- SRT exports: 30 days in Appwrite.
- GDPR delete: cascade via `users.delete`.

## 10. Sample Queries

```sql
-- Get all segments for SRT export, ordered by time
SELECT speaker_label, text, t_start_ms, t_end_ms
  FROM caption_segments
 WHERE call_id = $1
   AND is_final = TRUE
 ORDER BY t_start_ms;

-- Server toggle check
SELECT enabled, default_language
  FROM caption_server_settings
 WHERE server_id = $1;

-- Consent check
SELECT EXISTS (
  SELECT 1 FROM caption_consents
   WHERE call_id = $1 AND user_id = $2 AND consented = TRUE
);
```
