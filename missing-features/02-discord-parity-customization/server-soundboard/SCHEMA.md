# Server Soundboard — Backend Schema

## 1. Tables

### `soundboard_clips`

```sql
CREATE TABLE soundboard_clips (
  id                 UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id          UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  uploader_id        UUID NOT NULL REFERENCES users(id) ON DELETE SET NULL,

  name               TEXT NOT NULL CHECK (length(name) BETWEEN 1 AND 32),
  emoji              TEXT,
  position           INTEGER NOT NULL DEFAULT 0,

  file_id_original   TEXT NOT NULL,
  file_id_opus       TEXT,
  duration_ms        INTEGER NOT NULL CHECK (duration_ms BETWEEN 200 AND 5000),
  bytes_original     INTEGER NOT NULL,
  bytes_opus         INTEGER,
  mime_type          TEXT NOT NULL CHECK (mime_type IN ('audio/mpeg','audio/mp4','audio/ogg','audio/wav')),
  sha256             TEXT NOT NULL,
  loudness_lufs      REAL,

  status             TEXT NOT NULL DEFAULT 'processing'
                       CHECK (status IN ('processing','ready','disabled','failed')),
  reports_24h        INTEGER NOT NULL DEFAULT 0,

  created_at         TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_sbc_server      ON soundboard_clips(server_id, position);
CREATE INDEX idx_sbc_status      ON soundboard_clips(status) WHERE status <> 'ready';
CREATE INDEX idx_sbc_sha256      ON soundboard_clips(sha256);
CREATE UNIQUE INDEX uq_sbc_server_position
  ON soundboard_clips(server_id, position)
  WHERE status IN ('ready','disabled');
```

### `soundboard_default_clips`

Curated by Flicko, attached to every server by reference.

```sql
CREATE TABLE soundboard_default_clips (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name            TEXT NOT NULL,
  emoji           TEXT NOT NULL,
  file_id_opus    TEXT NOT NULL,
  duration_ms     INTEGER NOT NULL,
  category        TEXT NOT NULL,
  position        INTEGER NOT NULL,
  enabled         BOOLEAN NOT NULL DEFAULT TRUE,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_sb_default_position ON soundboard_default_clips(position) WHERE enabled;
```

### `soundboard_settings`

Per-server config.

```sql
CREATE TABLE soundboard_settings (
  server_id            UUID PRIMARY KEY REFERENCES servers(id) ON DELETE CASCADE,
  cooldown_seconds     INTEGER NOT NULL DEFAULT 5 CHECK (cooldown_seconds BETWEEN 1 AND 60),
  global_play_rate     INTEGER NOT NULL DEFAULT 10 CHECK (global_play_rate BETWEEN 1 AND 30),
  slot_limit           INTEGER NOT NULL DEFAULT 48 CHECK (slot_limit IN (48, 96)),
  show_visual_indicator BOOLEAN NOT NULL DEFAULT TRUE,
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### `soundboard_role_permissions`

Three perms × N roles.

```sql
CREATE TABLE soundboard_role_permissions (
  server_id   UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  role_id     UUID NOT NULL REFERENCES roles(id) ON DELETE CASCADE,
  can_play    BOOLEAN NOT NULL DEFAULT TRUE,
  can_upload  BOOLEAN NOT NULL DEFAULT FALSE,
  can_manage  BOOLEAN NOT NULL DEFAULT FALSE,
  PRIMARY KEY (server_id, role_id)
);

CREATE INDEX idx_sb_role_perms_role ON soundboard_role_permissions(role_id);
```

### `soundboard_play_log`

Sliding-window record for analytics + auto-disable trigger. 30-day retention.

```sql
CREATE TABLE soundboard_play_log (
  id          BIGSERIAL PRIMARY KEY,
  clip_id     UUID NOT NULL REFERENCES soundboard_clips(id) ON DELETE CASCADE,
  server_id   UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  room_sid    TEXT NOT NULL,
  played_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_sb_play_log_clip_time ON soundboard_play_log(clip_id, played_at DESC);
CREATE INDEX idx_sb_play_log_server    ON soundboard_play_log(server_id, played_at DESC);
```

### `soundboard_clip_reports`

```sql
CREATE TABLE soundboard_clip_reports (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  clip_id     UUID NOT NULL REFERENCES soundboard_clips(id) ON DELETE CASCADE,
  reporter_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reason      TEXT NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (clip_id, reporter_id)
);

CREATE INDEX idx_sb_reports_clip_time ON soundboard_clip_reports(clip_id, created_at DESC);
```

## 2. RLS Policies

```sql
ALTER TABLE soundboard_clips ENABLE ROW LEVEL SECURITY;

CREATE POLICY "members can read clips"
  ON soundboard_clips FOR SELECT
  USING (server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid()));

CREATE POLICY "uploaders can write"
  ON soundboard_clips FOR INSERT
  WITH CHECK (has_server_permission(auth.uid(), server_id, 'SOUNDBOARD_UPLOAD'));

CREATE POLICY "managers can update"
  ON soundboard_clips FOR UPDATE
  USING (has_server_permission(auth.uid(), server_id, 'SOUNDBOARD_MANAGE'));

CREATE POLICY "managers can delete"
  ON soundboard_clips FOR DELETE
  USING (has_server_permission(auth.uid(), server_id, 'SOUNDBOARD_MANAGE'));

ALTER TABLE soundboard_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY "members read settings" ON soundboard_settings FOR SELECT
  USING (server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid()));
CREATE POLICY "managers update settings" ON soundboard_settings FOR UPDATE
  USING (has_server_permission(auth.uid(), server_id, 'SOUNDBOARD_MANAGE'));

ALTER TABLE soundboard_role_permissions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "managers manage role perms" ON soundboard_role_permissions FOR ALL
  USING (has_server_permission(auth.uid(), server_id, 'SOUNDBOARD_MANAGE'))
  WITH CHECK (has_server_permission(auth.uid(), server_id, 'SOUNDBOARD_MANAGE'));

ALTER TABLE soundboard_clip_reports ENABLE ROW LEVEL SECURITY;
CREATE POLICY "users insert reports" ON soundboard_clip_reports FOR INSERT
  WITH CHECK (reporter_id = auth.uid());
CREATE POLICY "managers see reports" ON soundboard_clip_reports FOR SELECT
  USING (
    EXISTS (SELECT 1 FROM soundboard_clips c
            WHERE c.id = soundboard_clip_reports.clip_id
              AND has_server_permission(auth.uid(), c.server_id, 'SOUNDBOARD_MANAGE'))
  );
```

## 3. Triggers

```sql
CREATE TRIGGER sbc_updated_at BEFORE UPDATE ON soundboard_clips
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER sb_settings_updated_at BEFORE UPDATE ON soundboard_settings
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Maintain reports_24h denormalized counter
CREATE OR REPLACE FUNCTION fn_sb_recount_reports() RETURNS TRIGGER AS $$
BEGIN
  UPDATE soundboard_clips
     SET reports_24h = (
       SELECT COUNT(*) FROM soundboard_clip_reports
       WHERE clip_id = NEW.clip_id
         AND created_at > now() - INTERVAL '24 hours'
     )
   WHERE id = NEW.clip_id;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER sb_reports_after_insert
  AFTER INSERT ON soundboard_clip_reports
  FOR EACH ROW EXECUTE FUNCTION fn_sb_recount_reports();

-- Enqueue blob deletion on clip removal
CREATE OR REPLACE FUNCTION fn_sb_enqueue_delete_blobs() RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO appwrite_blob_deletions(file_id) VALUES (OLD.file_id_original);
  IF OLD.file_id_opus IS NOT NULL THEN
    INSERT INTO appwrite_blob_deletions(file_id) VALUES (OLD.file_id_opus);
  END IF;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER sbc_after_delete AFTER DELETE ON soundboard_clips
  FOR EACH ROW EXECUTE FUNCTION fn_sb_enqueue_delete_blobs();
```

## 4. Migration File

Path: `supabase/migrations/127_server_soundboard.up.sql`
Down: `supabase/migrations/127_server_soundboard.down.sql`

```sql
-- 127_server_soundboard.up.sql
BEGIN;

CREATE TABLE soundboard_clips ( /* ...as above... */ );
CREATE TABLE soundboard_default_clips ( /* ...as above... */ );
CREATE TABLE soundboard_settings ( /* ...as above... */ );
CREATE TABLE soundboard_role_permissions ( /* ...as above... */ );
CREATE TABLE soundboard_play_log ( /* ...as above... */ );
CREATE TABLE soundboard_clip_reports ( /* ...as above... */ );

-- indexes
-- RLS
-- triggers
-- functions

-- Seed soundboard_default_clips with 24 curated entries (loaded from
-- backend/migrations/data/sb_default_clips.json by app startup).

GRANT SELECT, INSERT, UPDATE, DELETE ON
  soundboard_clips, soundboard_settings, soundboard_role_permissions,
  soundboard_clip_reports
TO authenticated;
GRANT SELECT ON soundboard_default_clips, soundboard_play_log TO authenticated;
GRANT INSERT ON soundboard_play_log TO authenticated;

COMMIT;
```

```sql
-- 127_server_soundboard.down.sql
BEGIN;
DROP TRIGGER IF EXISTS sbc_after_delete ON soundboard_clips;
DROP TRIGGER IF EXISTS sb_reports_after_insert ON soundboard_clip_reports;
DROP TRIGGER IF EXISTS sbc_updated_at ON soundboard_clips;
DROP TRIGGER IF EXISTS sb_settings_updated_at ON soundboard_settings;
DROP FUNCTION IF EXISTS fn_sb_enqueue_delete_blobs;
DROP FUNCTION IF EXISTS fn_sb_recount_reports;

DROP TABLE IF EXISTS soundboard_clip_reports;
DROP TABLE IF EXISTS soundboard_play_log;
DROP TABLE IF EXISTS soundboard_role_permissions;
DROP TABLE IF EXISTS soundboard_settings;
DROP TABLE IF EXISTS soundboard_default_clips;
DROP TABLE IF EXISTS soundboard_clips;
COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `sb:lib:{server_id}` | JSON list of clips | 5m |
| `sb:cd:{server_id}:{user_id}` | INT plays this window | = cooldown_seconds |
| `sb:gr:{server_id}` | INT global plays this window | 1s (token bucket) |
| `sb:recent:{room_sid}` | LIST of last 10 play events | 10m |
| `sb:url:{file_id_opus}` | signed Appwrite URL | 50m |

## 6. Search Index (Meilisearch)

```jsonc
{
  "uid": "soundboard_clips",
  "primaryKey": "id",
  "searchableAttributes": ["name", "emoji"],
  "filterableAttributes": ["server_id", "status"],
  "sortableAttributes": ["position", "created_at"]
}
```

## 7. Vector Index (Qdrant)

Not applicable.

## 8. Object Storage (Appwrite)

- Bucket: `soundboard-clips`
- Allowed MIME: `audio/mpeg`, `audio/mp4`, `audio/ogg`, `audio/wav` (originals); `audio/ogg` for opus variants.
- Max file size: 512 KB.
- Permission: `read("any")` (public CDN, signed URLs); `write("role:flicko_backend")`.
- File-id pattern: `sb_{clip_id}_{variant}`.

## 9. Data Retention

- `soundboard_clips`: lifetime of server.
- `soundboard_play_log`: 30 days, then truncated by nightly job.
- `soundboard_clip_reports`: 90 days.
- GDPR delete: cascade on `users.delete` (uploader → SET NULL keeps clip; reporter → CASCADE removes report row).

## 10. Sample Queries

```sql
-- list clips for a server (handler hot path)
SELECT id, name, emoji, duration_ms, file_id_opus, status
FROM soundboard_clips
WHERE server_id = $1 AND status IN ('ready','disabled')
ORDER BY position ASC;

-- top 10 most-played clips this week
SELECT c.id, c.name, COUNT(*) AS plays
FROM soundboard_play_log p JOIN soundboard_clips c ON c.id = p.clip_id
WHERE p.played_at > now() - INTERVAL '7 days'
  AND p.server_id = $1
GROUP BY c.id, c.name
ORDER BY plays DESC LIMIT 10;

-- detect clips that should auto-disable
SELECT id FROM soundboard_clips
WHERE reports_24h >= 3 AND status = 'ready';

-- per-user cooldown bypass attempt logging
SELECT user_id, COUNT(*) AS hits
FROM soundboard_play_log
WHERE server_id = $1 AND played_at > now() - INTERVAL '1 hour'
GROUP BY user_id
HAVING COUNT(*) > 100;
```
