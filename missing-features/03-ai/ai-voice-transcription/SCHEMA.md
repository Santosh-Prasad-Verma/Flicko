# Live Voice Captions — Whisper.cpp Transcription — Backend Schema

## 1. Tables

### `voice_caption_settings`

```sql
CREATE TABLE voice_caption_settings (
  channel_id      UUID PRIMARY KEY REFERENCES channels(id) ON DELETE CASCADE,
  enabled         BOOLEAN NOT NULL DEFAULT false,
  model           TEXT NOT NULL DEFAULT 'small.en'
                  CHECK (model IN ('tiny.en','small.en','small','medium')),
  language        TEXT NOT NULL DEFAULT 'auto',
  default_visible BOOLEAN NOT NULL DEFAULT true,
  retention_days  INT NOT NULL DEFAULT 30,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### `voice_caption_user_prefs`

```sql
CREATE TABLE voice_caption_user_prefs (
  user_id            UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  visible            BOOLEAN NOT NULL DEFAULT true,
  font_size          TEXT NOT NULL DEFAULT 'M' CHECK (font_size IN ('S','M','L','XL')),
  position           TEXT NOT NULL DEFAULT 'bottom' CHECK (position IN ('top','bottom')),
  opacity            REAL NOT NULL DEFAULT 0.85,
  speaker_color      BOOLEAN NOT NULL DEFAULT true,
  reduce_profanity   BOOLEAN NOT NULL DEFAULT false,
  late_join_replay   BOOLEAN NOT NULL DEFAULT true,
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### `voice_caption_sessions`

```sql
CREATE TABLE voice_caption_sessions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  channel_id      UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  server_id       UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  azure_acs_room    TEXT NOT NULL,
  started_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  ended_at        TIMESTAMPTZ,
  worker_id       TEXT,
  model_used      TEXT NOT NULL,
  participant_count INT NOT NULL DEFAULT 0,
  segment_count   INT NOT NULL DEFAULT 0,
  total_speech_ms BIGINT NOT NULL DEFAULT 0,
  ended_reason    TEXT
);

CREATE INDEX idx_caption_sessions_channel ON voice_caption_sessions(channel_id, started_at DESC);
CREATE INDEX idx_caption_sessions_server  ON voice_caption_sessions(server_id, started_at DESC);
```

### `voice_transcripts`

```sql
CREATE TABLE voice_transcripts (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  session_id        UUID NOT NULL REFERENCES voice_caption_sessions(id) ON DELETE CASCADE,
  channel_id        UUID NOT NULL,
  server_id         UUID NOT NULL,
  speaker_user_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  speaker_name      TEXT NOT NULL,
  t_start_ms        BIGINT NOT NULL,    -- ms since session start
  t_end_ms          BIGINT NOT NULL,
  text              TEXT NOT NULL,
  confidence        REAL,
  language          CHAR(2),
  is_final          BOOLEAN NOT NULL DEFAULT true,
  superseded_by     UUID REFERENCES voice_transcripts(id),  -- partial->final chain
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_voice_transcripts_session_time
  ON voice_transcripts(session_id, t_start_ms);
CREATE INDEX idx_voice_transcripts_channel_time
  ON voice_transcripts(channel_id, created_at DESC);
CREATE INDEX idx_voice_transcripts_speaker
  ON voice_transcripts(speaker_user_id, created_at DESC);
```

## 2. RLS Policies

```sql
ALTER TABLE voice_caption_settings   ENABLE ROW LEVEL SECURITY;
ALTER TABLE voice_caption_user_prefs ENABLE ROW LEVEL SECURITY;
ALTER TABLE voice_caption_sessions   ENABLE ROW LEVEL SECURITY;
ALTER TABLE voice_transcripts        ENABLE ROW LEVEL SECURITY;

-- channel admins write settings; members read
CREATE POLICY caption_settings_member_read ON voice_caption_settings
  FOR SELECT USING (
    channel_id IN (
      SELECT id FROM channels c
      JOIN server_members sm ON sm.server_id = c.server_id
      WHERE sm.user_id = auth.uid()
    )
  );
CREATE POLICY caption_settings_admin_write ON voice_caption_settings
  FOR ALL USING (
    channel_id IN (
      SELECT id FROM channels c
      JOIN server_members sm ON sm.server_id = c.server_id
      WHERE sm.user_id = auth.uid() AND sm.role IN ('owner','admin')
    )
  );

-- prefs are personal
CREATE POLICY caption_prefs_self ON voice_caption_user_prefs
  FOR ALL USING (user_id = auth.uid());

-- sessions/transcripts: server members read
CREATE POLICY caption_sessions_member_read ON voice_caption_sessions
  FOR SELECT USING (
    server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid())
  );

CREATE POLICY voice_transcripts_member_read ON voice_transcripts
  FOR SELECT USING (
    server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid())
  );
```

## 3. Triggers

```sql
CREATE TRIGGER caption_settings_set_updated_at
  BEFORE UPDATE ON voice_caption_settings
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- finalize session counters at end
CREATE OR REPLACE FUNCTION finalize_caption_session() RETURNS trigger AS $$
BEGIN
  IF NEW.ended_at IS NOT NULL AND OLD.ended_at IS NULL THEN
    UPDATE voice_caption_sessions s
    SET segment_count = (SELECT COUNT(*) FROM voice_transcripts t WHERE t.session_id = s.id AND t.is_final),
        total_speech_ms = (SELECT COALESCE(SUM(t.t_end_ms - t.t_start_ms),0)
                           FROM voice_transcripts t
                           WHERE t.session_id = s.id AND t.is_final)
    WHERE s.id = NEW.id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER caption_session_finalize
  AFTER UPDATE OF ended_at ON voice_caption_sessions
  FOR EACH ROW EXECUTE FUNCTION finalize_caption_session();
```

## 4. Migration File

Path: `supabase/migrations/133_ai_voice_captions.up.sql`
Down: `supabase/migrations/133_ai_voice_captions.down.sql`

```sql
-- 133_ai_voice_captions.up.sql
BEGIN;
CREATE TABLE voice_caption_settings   (...);
CREATE TABLE voice_caption_user_prefs (...);
CREATE TABLE voice_caption_sessions   (...);
CREATE TABLE voice_transcripts        (...);
-- indexes
ALTER TABLE voice_caption_settings   ENABLE ROW LEVEL SECURITY;
ALTER TABLE voice_caption_user_prefs ENABLE ROW LEVEL SECURITY;
ALTER TABLE voice_caption_sessions   ENABLE ROW LEVEL SECURITY;
ALTER TABLE voice_transcripts        ENABLE ROW LEVEL SECURITY;
-- policies, triggers
GRANT SELECT, INSERT, UPDATE, DELETE ON voice_caption_settings, voice_caption_user_prefs,
      voice_caption_sessions, voice_transcripts TO authenticated;
COMMIT;
```

```sql
-- 133_ai_voice_captions.down.sql
BEGIN;
DROP TABLE IF EXISTS voice_transcripts        CASCADE;
DROP TABLE IF EXISTS voice_caption_sessions   CASCADE;
DROP TABLE IF EXISTS voice_caption_user_prefs CASCADE;
DROP TABLE IF EXISTS voice_caption_settings   CASCADE;
DROP FUNCTION IF EXISTS finalize_caption_session();
COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `captions:rolling:<channel_id>` | LIST of last 30 finals (JSON) | 5m |
| `captions:session:active:<channel_id>` | session_id | session lifetime |
| `captions:health:worker:<worker_id>` | "ok" | 30s |

## 6. Search Index (Meilisearch)

Optional v2: index `voice_transcripts.text` so users can search "what did alice say last week".

## 7. Vector Index (Qdrant)

Not used in v1.

## 8. Object Storage

- R2 bucket `flicko-ai-archive`
  - `transcripts/<yyyymm>/<channel_id>/<session_id>.parquet`
  - Lifecycle: 12 months then Glacier

## 9. Data Retention

- `voice_transcripts`: hot 30d (configurable per channel via `retention_days`)
- Archive: nightly to R2
- GDPR delete: cascade by `speaker_user_id` (transcripts only have *that* user's words)
- Channel delete cascades all transcripts

## 10. Sample Queries

```sql
-- Late-join: last 5 min of session
SELECT speaker_name, text, t_start_ms
FROM voice_transcripts
WHERE session_id = $1
  AND is_final = true
  AND t_start_ms > $now_ms - 300000
ORDER BY t_start_ms;

-- Per-speaker word count last 30 days
SELECT speaker_user_id, SUM(array_length(string_to_array(text,' '),1)) AS words
FROM voice_transcripts
WHERE channel_id = $1 AND created_at > now() - interval '30 days' AND is_final
GROUP BY speaker_user_id
ORDER BY words DESC;

-- Session export ordered
SELECT t_start_ms, speaker_name, text
FROM voice_transcripts
WHERE session_id = $1 AND is_final
ORDER BY t_start_ms;

-- Active sessions
SELECT s.id, s.channel_id, s.started_at,
       (now() - s.started_at) AS dur
FROM voice_caption_sessions s
WHERE s.ended_at IS NULL;
```
