# Audio Descriptions — Backend Schema

## 1. Tables

### `audio_desc_cache` (new)

Persistent cache keyed by image SHA-256 so repeated uploads of the same image incur only one LLM call.

```sql
CREATE TABLE audio_desc_cache (
  sha256        TEXT PRIMARY KEY,
  text          TEXT NOT NULL,
  source        TEXT NOT NULL CHECK (source IN ('ai', 'manual', 'ai_then_manual')),
  language      TEXT NOT NULL DEFAULT 'en',
  ocr           TEXT,
  nsfw          BOOLEAN NOT NULL DEFAULT FALSE,
  model         TEXT,
  model_version TEXT,
  generated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  hits          BIGINT NOT NULL DEFAULT 1,
  last_used_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_audio_desc_cache_last_used ON audio_desc_cache(last_used_at DESC);
CREATE INDEX idx_audio_desc_cache_nsfw      ON audio_desc_cache(nsfw) WHERE nsfw = TRUE;
```

### `attachments` (existing — extended)

Add four columns to the existing `attachments` table:

```sql
ALTER TABLE attachments
  ADD COLUMN IF NOT EXISTS manual_alt        TEXT,
  ADD COLUMN IF NOT EXISTS ai_alt            TEXT,
  ADD COLUMN IF NOT EXISTS audio_desc_status TEXT NOT NULL DEFAULT 'queued'
    CHECK (audio_desc_status IN ('queued','running','ready','error','nsfw_blocked')),
  ADD COLUMN IF NOT EXISTS audio_desc_at     TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_attachments_audio_desc_status
  ON attachments(audio_desc_status) WHERE audio_desc_status IN ('queued','running','error');
```

### `audio_desc_reports` (new)

Tiny table where viewers can flag bad descriptions (low volume, queryable for QA).

```sql
CREATE TABLE audio_desc_reports (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  attachment_id UUID NOT NULL REFERENCES attachments(id) ON DELETE CASCADE,
  reporter_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reason        TEXT NOT NULL CHECK (reason IN ('inaccurate','offensive','privacy','other')),
  detail        TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_audio_desc_reports_attachment ON audio_desc_reports(attachment_id);
CREATE INDEX idx_audio_desc_reports_recent     ON audio_desc_reports(created_at DESC);
```

## 2. RLS Policies

```sql
ALTER TABLE audio_desc_cache ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone authenticated can read cache"
  ON audio_desc_cache FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY "Only service role can write cache"
  ON audio_desc_cache FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

ALTER TABLE audio_desc_reports ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Reporter can write"
  ON audio_desc_reports FOR INSERT
  WITH CHECK (reporter_id = auth.uid());

CREATE POLICY "Staff can read all"
  ON audio_desc_reports FOR SELECT
  USING (EXISTS (SELECT 1 FROM staff_users s WHERE s.user_id = auth.uid()));
```

The `attachments` table reuses its existing policies.

## 3. Triggers

```sql
CREATE OR REPLACE FUNCTION audio_desc_bump_hits()
RETURNS TRIGGER AS $$
BEGIN
  NEW.hits := OLD.hits + 1;
  NEW.last_used_at := now();
  RETURN NEW;
END $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_audio_desc_bump_hits
  BEFORE UPDATE ON audio_desc_cache
  FOR EACH ROW WHEN (OLD.text = NEW.text)
  EXECUTE FUNCTION audio_desc_bump_hits();
```

## 4. Migration File

Path: `supabase/migrations/255_audio_descriptions.up.sql`
Down: `supabase/migrations/255_audio_descriptions.down.sql`

```sql
-- up
BEGIN;

CREATE TABLE IF NOT EXISTS audio_desc_cache (
  sha256        TEXT PRIMARY KEY,
  text          TEXT NOT NULL,
  source        TEXT NOT NULL CHECK (source IN ('ai','manual','ai_then_manual')),
  language      TEXT NOT NULL DEFAULT 'en',
  ocr           TEXT,
  nsfw          BOOLEAN NOT NULL DEFAULT FALSE,
  model         TEXT,
  model_version TEXT,
  generated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  hits          BIGINT NOT NULL DEFAULT 1,
  last_used_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_audio_desc_cache_last_used ON audio_desc_cache(last_used_at DESC);
CREATE INDEX IF NOT EXISTS idx_audio_desc_cache_nsfw      ON audio_desc_cache(nsfw) WHERE nsfw = TRUE;

ALTER TABLE attachments
  ADD COLUMN IF NOT EXISTS manual_alt        TEXT,
  ADD COLUMN IF NOT EXISTS ai_alt            TEXT,
  ADD COLUMN IF NOT EXISTS audio_desc_status TEXT NOT NULL DEFAULT 'queued'
    CHECK (audio_desc_status IN ('queued','running','ready','error','nsfw_blocked')),
  ADD COLUMN IF NOT EXISTS audio_desc_at     TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_attachments_audio_desc_status
  ON attachments(audio_desc_status) WHERE audio_desc_status IN ('queued','running','error');

CREATE TABLE IF NOT EXISTS audio_desc_reports (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  attachment_id UUID NOT NULL REFERENCES attachments(id) ON DELETE CASCADE,
  reporter_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reason        TEXT NOT NULL CHECK (reason IN ('inaccurate','offensive','privacy','other')),
  detail        TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_audio_desc_reports_attachment ON audio_desc_reports(attachment_id);
CREATE INDEX IF NOT EXISTS idx_audio_desc_reports_recent     ON audio_desc_reports(created_at DESC);

ALTER TABLE audio_desc_cache    ENABLE ROW LEVEL SECURITY;
ALTER TABLE audio_desc_reports  ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Anyone authenticated can read cache"
  ON audio_desc_cache FOR SELECT
  USING (auth.role() = 'authenticated');

CREATE POLICY "Only service role can write cache"
  ON audio_desc_cache FOR ALL
  USING (auth.role() = 'service_role')
  WITH CHECK (auth.role() = 'service_role');

CREATE POLICY "Reporter can write"
  ON audio_desc_reports FOR INSERT
  WITH CHECK (reporter_id = auth.uid());

CREATE POLICY "Staff can read all"
  ON audio_desc_reports FOR SELECT
  USING (EXISTS (SELECT 1 FROM staff_users s WHERE s.user_id = auth.uid()));

CREATE OR REPLACE FUNCTION audio_desc_bump_hits()
RETURNS TRIGGER AS $$
BEGIN
  NEW.hits := OLD.hits + 1;
  NEW.last_used_at := now();
  RETURN NEW;
END $$ LANGUAGE plpgsql;

CREATE TRIGGER trg_audio_desc_bump_hits
  BEFORE UPDATE ON audio_desc_cache
  FOR EACH ROW WHEN (OLD.text = NEW.text)
  EXECUTE FUNCTION audio_desc_bump_hits();

COMMIT;
```

```sql
-- down
BEGIN;
DROP TRIGGER IF EXISTS trg_audio_desc_bump_hits ON audio_desc_cache;
DROP FUNCTION IF EXISTS audio_desc_bump_hits();
DROP TABLE IF EXISTS audio_desc_reports;
DROP TABLE IF EXISTS audio_desc_cache;
ALTER TABLE attachments
  DROP COLUMN IF EXISTS audio_desc_at,
  DROP COLUMN IF EXISTS audio_desc_status,
  DROP COLUMN IF EXISTS ai_alt,
  DROP COLUMN IF EXISTS manual_alt;
COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `audio_desc:<sha256>` | description text | 7 days |
| `audio_desc:rate:<server_id>:<bucket>` | call count | 1 day |
| `audio_desc:cost:<bucket>` | running cost float | 1 day |

## 6. Search Index (Meilisearch)

We index AI-generated alt-text into the existing `attachments` Meili index `searchableAttributes` so users can search for "cat photos" in chat history.

## 7. Vector Index (Qdrant)

Optional v2: embed each description into the `attachments` Qdrant collection for semantic search. Out of scope for v1.

## 8. Object Storage (Appwrite)

No changes; descriptions are text-only and live in Postgres.

## 9. Data Retention

- `audio_desc_cache` rows kept 90 days past `last_used_at`; janitor job evicts older entries.
- `audio_desc_reports` kept indefinitely (low volume, audit value).
- GDPR delete: cascade via `attachments` and `users` deletion.

## 10. Sample Queries

```sql
-- Read description for an attachment (manual takes precedence)
SELECT
  COALESCE(manual_alt, ai_alt) AS text,
  CASE
    WHEN manual_alt IS NOT NULL AND ai_alt IS NOT NULL THEN 'ai_then_manual'
    WHEN manual_alt IS NOT NULL THEN 'manual'
    ELSE 'ai'
  END AS source,
  audio_desc_status, audio_desc_at
FROM attachments
WHERE id = $1;

-- Cache hit
SELECT text, source, language FROM audio_desc_cache WHERE sha256 = $1;

-- Coverage rate per server (last 7 days)
SELECT
  s.id AS server_id,
  COUNT(*) FILTER (WHERE COALESCE(a.manual_alt, a.ai_alt) IS NOT NULL)::float
    / NULLIF(COUNT(*),0) AS coverage
FROM servers s
JOIN messages m ON m.server_id = s.id AND m.created_at > now() - interval '7 days'
JOIN attachments a ON a.message_id = m.id AND a.mime_type LIKE 'image/%'
GROUP BY s.id;
```
