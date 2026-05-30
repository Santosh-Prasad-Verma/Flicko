# Auto-Translate — Inline Per-Message Translation — Backend Schema

## 1. Tables

### `translations_cache`

```sql
-- Persistent cache (Redis is hot path; this is durability + analytics)
CREATE TABLE translations_cache (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  text_sha256     TEXT NOT NULL,
  src_lang        CHAR(2) NOT NULL,
  tgt_lang        CHAR(2) NOT NULL,
  translated_text TEXT NOT NULL,
  provider        TEXT NOT NULL CHECK (provider IN ('libre','deepl')),
  glossary_version INT NOT NULL DEFAULT 0,
  hit_count       INT NOT NULL DEFAULT 0,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_seen_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (text_sha256, src_lang, tgt_lang, glossary_version)
);

CREATE INDEX idx_trans_cache_pair ON translations_cache(src_lang, tgt_lang);
CREATE INDEX idx_trans_cache_lastseen ON translations_cache(last_seen_at);
```

### `translations_log`

```sql
-- Per-request log for analytics + abuse + GDPR delete
CREATE TABLE translations_log (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  requested_by    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  server_id       UUID REFERENCES servers(id) ON DELETE CASCADE,
  channel_id      UUID REFERENCES channels(id) ON DELETE CASCADE,
  message_id      UUID REFERENCES messages(id) ON DELETE SET NULL,
  text_sha256     TEXT NOT NULL,
  src_lang        CHAR(2) NOT NULL,
  tgt_lang        CHAR(2) NOT NULL,
  provider        TEXT NOT NULL,
  cached          BOOLEAN NOT NULL,
  latency_ms      INT NOT NULL,
  char_count      INT NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_trans_log_user_day ON translations_log(requested_by, created_at);
CREATE INDEX idx_trans_log_server   ON translations_log(server_id, created_at);
```

### `translate_user_settings`

```sql
CREATE TABLE translate_user_settings (
  user_id            UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  target_lang        CHAR(2) NOT NULL DEFAULT 'en',
  fluent_langs       TEXT[] NOT NULL DEFAULT '{en}',
  behavior           TEXT NOT NULL DEFAULT 'ask'
                     CHECK (behavior IN ('always','ask','never')),
  show_provider_chip BOOLEAN NOT NULL DEFAULT true,
  daily_used         INT NOT NULL DEFAULT 0,
  daily_reset_at     TIMESTAMPTZ NOT NULL DEFAULT date_trunc('day', now()) + interval '1 day',
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### `translate_server_settings`

```sql
CREATE TABLE translate_server_settings (
  server_id          UUID PRIMARY KEY REFERENCES servers(id) ON DELETE CASCADE,
  enabled            BOOLEAN NOT NULL DEFAULT false,
  auto_translate     BOOLEAN NOT NULL DEFAULT false,  -- override user "ask"
  channel_allowlist  UUID[] DEFAULT NULL,             -- null = all
  glossary_version   INT NOT NULL DEFAULT 0,
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### `translate_glossary`

```sql
CREATE TABLE translate_glossary (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id       UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  term            TEXT NOT NULL,
  case_sensitive  BOOLEAN NOT NULL DEFAULT true,
  created_by      UUID NOT NULL REFERENCES users(id),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (server_id, term, case_sensitive)
);

CREATE INDEX idx_glossary_server ON translate_glossary(server_id);
```

## 2. RLS Policies

```sql
ALTER TABLE translations_cache         ENABLE ROW LEVEL SECURITY;
ALTER TABLE translations_log           ENABLE ROW LEVEL SECURITY;
ALTER TABLE translate_user_settings    ENABLE ROW LEVEL SECURITY;
ALTER TABLE translate_server_settings  ENABLE ROW LEVEL SECURITY;
ALTER TABLE translate_glossary         ENABLE ROW LEVEL SECURITY;

-- cache is public-readable to all authenticated (it's just hashes); writes via service-role
CREATE POLICY trans_cache_read ON translations_cache
  FOR SELECT USING (auth.role() = 'authenticated');

-- per-user log
CREATE POLICY trans_log_self ON translations_log
  FOR SELECT USING (requested_by = auth.uid());
CREATE POLICY trans_log_self_insert ON translations_log
  FOR INSERT WITH CHECK (requested_by = auth.uid());

-- per-user settings
CREATE POLICY trans_user_settings_self ON translate_user_settings
  FOR ALL USING (user_id = auth.uid());

-- server settings: admin only
CREATE POLICY trans_server_settings_admin ON translate_server_settings
  FOR ALL USING (
    server_id IN (SELECT server_id FROM server_members
                  WHERE user_id = auth.uid() AND role IN ('owner','admin'))
  );

-- glossary: admin write, member read
CREATE POLICY glossary_member_read ON translate_glossary
  FOR SELECT USING (
    server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid())
  );
CREATE POLICY glossary_admin_write ON translate_glossary
  FOR ALL USING (
    server_id IN (SELECT server_id FROM server_members
                  WHERE user_id = auth.uid() AND role IN ('owner','admin'))
  );
```

## 3. Triggers

```sql
-- bump glossary_version on any change → invalidates cache
CREATE OR REPLACE FUNCTION bump_glossary_version() RETURNS trigger AS $$
BEGIN
  UPDATE translate_server_settings
  SET glossary_version = glossary_version + 1, updated_at = now()
  WHERE server_id = COALESCE(NEW.server_id, OLD.server_id);
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER glossary_bump
  AFTER INSERT OR UPDATE OR DELETE ON translate_glossary
  FOR EACH ROW EXECUTE FUNCTION bump_glossary_version();

-- daily quota reset
CREATE OR REPLACE FUNCTION reset_daily_translation_quota() RETURNS void AS $$
BEGIN
  UPDATE translate_user_settings
  SET daily_used = 0,
      daily_reset_at = date_trunc('day', now()) + interval '1 day'
  WHERE daily_reset_at <= now();
END;
$$ LANGUAGE plpgsql;
-- scheduled by pg_cron at 00:01 UTC daily
```

## 4. Migration File

Path: `supabase/migrations/132_ai_translate.up.sql`
Down: `supabase/migrations/132_ai_translate.down.sql`

```sql
-- 132_ai_translate.up.sql
BEGIN;
CREATE TABLE translations_cache         (...);
CREATE TABLE translations_log           (...);
CREATE TABLE translate_user_settings    (...);
CREATE TABLE translate_server_settings  (...);
CREATE TABLE translate_glossary         (...);
-- indexes, policies, triggers
GRANT SELECT, INSERT, UPDATE, DELETE ON translations_cache, translations_log,
      translate_user_settings, translate_server_settings, translate_glossary
  TO authenticated;
SELECT cron.schedule('reset-translate-quota', '1 0 * * *',
                     $$SELECT reset_daily_translation_quota()$$);
COMMIT;
```

```sql
-- 132_ai_translate.down.sql
BEGIN;
SELECT cron.unschedule('reset-translate-quota');
DROP TABLE IF EXISTS translate_glossary         CASCADE;
DROP TABLE IF EXISTS translate_server_settings  CASCADE;
DROP TABLE IF EXISTS translate_user_settings    CASCADE;
DROP TABLE IF EXISTS translations_log           CASCADE;
DROP TABLE IF EXISTS translations_cache         CASCADE;
DROP FUNCTION IF EXISTS bump_glossary_version();
DROP FUNCTION IF EXISTS reset_daily_translation_quota();
COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `translate:rate:<user_id>` | ZSET of timestamps | 86400s |
| `translate:cache:<sha>:<src>:<tgt>:<gver>` | translated text | 30d |
| `translate:lid:<sha>` | "<lang>:<conf>" | 7d |
| `translate:deepl:quota:<yyyymmdd>` | INT chars used | 86400s |
| `translate:libre:health` | "ok" / "down" | 60s |

## 6. Search Index (Meilisearch)

Not used.

## 7. Vector Index (Qdrant)

Not used.

## 8. Object Storage

Not used.

## 9. Data Retention

- `translations_cache`: 30d sliding (LRU-style via `last_seen_at`)
- `translations_log`: 7d hot, then archive to R2 monthly
- GDPR delete: cascade `translations_log` by `requested_by`; cache rows are anonymized (only sha256), kept

## 10. Sample Queries

```sql
-- Daily usage per user
SELECT requested_by, COUNT(*) AS calls, SUM(char_count) AS chars
FROM translations_log
WHERE created_at > now() - interval '24 hours'
GROUP BY requested_by;

-- Cache hit ratio last hour
SELECT
  AVG(cached::int)::numeric(4,3) AS hit_ratio
FROM translations_log
WHERE created_at > now() - interval '1 hour';

-- Top language pairs
SELECT src_lang, tgt_lang, COUNT(*) AS n
FROM translations_log
WHERE created_at > now() - interval '7 days'
GROUP BY src_lang, tgt_lang
ORDER BY n DESC LIMIT 20;

-- Provider mix
SELECT provider, COUNT(*) FROM translations_log
WHERE created_at > now() - interval '24 hours'
GROUP BY provider;

-- Cache eviction candidates
DELETE FROM translations_cache
WHERE last_seen_at < now() - interval '30 days';
```
