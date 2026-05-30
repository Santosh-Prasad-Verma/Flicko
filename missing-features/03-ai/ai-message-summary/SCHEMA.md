# Catch-Me-Up — AI Channel Summary — Backend Schema

## 1. Tables

### `ai_summaries`

```sql
CREATE TABLE ai_summaries (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  request_id        UUID NOT NULL UNIQUE,
  server_id         UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  channel_id        UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  requested_by      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  anchor_msg_id     UUID,                                -- last_read at request time
  latest_msg_id     UUID,                                -- most recent message in window
  window_start      TIMESTAMPTZ NOT NULL,
  window_end        TIMESTAMPTZ NOT NULL,
  message_count     INT NOT NULL,
  bullets           JSONB NOT NULL DEFAULT '[]'::jsonb,
                    -- [{idx, text, citations: [msg_id…]}]
  participants      TEXT[] NOT NULL DEFAULT '{}',
  sentiment         TEXT,                                -- positive|focused|mixed|tense
  model_used        TEXT NOT NULL,
  tokens_in         INT,
  tokens_out        INT,
  ttfb_ms           INT,
  total_ms          INT,
  outcome           TEXT NOT NULL DEFAULT 'pending'
                    CHECK (outcome IN ('pending','done','refused','error','rate_limited')),
  refusal_reason    TEXT,
  cache_key         TEXT NOT NULL,
  cached_hit        BOOLEAN NOT NULL DEFAULT false,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  finished_at       TIMESTAMPTZ
);

CREATE INDEX idx_summaries_channel    ON ai_summaries(channel_id, created_at DESC);
CREATE INDEX idx_summaries_user       ON ai_summaries(requested_by, created_at DESC);
CREATE INDEX idx_summaries_cache_key  ON ai_summaries(cache_key);
CREATE INDEX idx_summaries_outcome    ON ai_summaries(outcome);
```

### `ai_summary_feedback`

```sql
CREATE TABLE ai_summary_feedback (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  summary_id   UUID NOT NULL REFERENCES ai_summaries(id) ON DELETE CASCADE,
  user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  rating       SMALLINT NOT NULL CHECK (rating IN (-1, 1)),
  reason       TEXT,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (summary_id, user_id)
);
```

### `ai_summary_anchors`

```sql
-- Per-user last-read anchor per channel; supplements existing read_state
-- Used to compute the default since_ts when a user opens a channel.
-- NOTE: duplicates existing read_state but adds per-user "last summary" timestamp
-- so we can show the pill only when there's NEW activity since the LAST summary.
CREATE TABLE ai_summary_anchors (
  user_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  channel_id     UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  last_summary_at TIMESTAMPTZ,
  last_summary_anchor UUID,
  PRIMARY KEY (user_id, channel_id)
);
```

## 2. RLS Policies

```sql
ALTER TABLE ai_summaries          ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_summary_feedback   ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_summary_anchors    ENABLE ROW LEVEL SECURITY;

-- Summaries are private to the requester.
CREATE POLICY summaries_owner_read ON ai_summaries
  FOR SELECT USING (requested_by = auth.uid());

CREATE POLICY summaries_self_insert ON ai_summaries
  FOR INSERT WITH CHECK (requested_by = auth.uid());

-- Feedback only by self
CREATE POLICY summary_feedback_self ON ai_summary_feedback
  FOR ALL USING (user_id = auth.uid());

-- Anchors only by self
CREATE POLICY summary_anchors_self ON ai_summary_anchors
  FOR ALL USING (user_id = auth.uid());
```

## 3. Triggers

```sql
-- Update anchor on summary done
CREATE OR REPLACE FUNCTION update_summary_anchor() RETURNS trigger AS $$
BEGIN
  IF NEW.outcome = 'done' THEN
    INSERT INTO ai_summary_anchors (user_id, channel_id, last_summary_at, last_summary_anchor)
    VALUES (NEW.requested_by, NEW.channel_id, NEW.window_end, NEW.latest_msg_id)
    ON CONFLICT (user_id, channel_id)
    DO UPDATE SET last_summary_at = EXCLUDED.last_summary_at,
                  last_summary_anchor = EXCLUDED.last_summary_anchor;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER summaries_update_anchor
  AFTER UPDATE OF outcome ON ai_summaries
  FOR EACH ROW EXECUTE FUNCTION update_summary_anchor();
```

## 4. Migration File

Path: `supabase/migrations/131_ai_summaries.up.sql`
Down: `supabase/migrations/131_ai_summaries.down.sql`

```sql
-- 131_ai_summaries.up.sql
BEGIN;
CREATE TABLE ai_summaries          (...);
CREATE TABLE ai_summary_feedback   (...);
CREATE TABLE ai_summary_anchors    (...);
-- indexes
ALTER TABLE ai_summaries          ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_summary_feedback   ENABLE ROW LEVEL SECURITY;
ALTER TABLE ai_summary_anchors    ENABLE ROW LEVEL SECURITY;
-- policies, triggers
GRANT SELECT, INSERT, UPDATE, DELETE ON ai_summaries, ai_summary_feedback, ai_summary_anchors
  TO authenticated;
COMMIT;
```

```sql
-- 131_ai_summaries.down.sql
BEGIN;
DROP TABLE IF EXISTS ai_summary_anchors  CASCADE;
DROP TABLE IF EXISTS ai_summary_feedback CASCADE;
DROP TABLE IF EXISTS ai_summaries        CASCADE;
DROP FUNCTION IF EXISTS update_summary_anchor();
COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `summary:ratelimit:<user_id>` | ZSET of timestamps | 86400s |
| `summary:answer:<channel_id>:<anchor_msg_id>:<latest_msg_id>:<model>` | JSON {bullets, meta, tokens} | 3600s |
| `summary:warm:<channel_id>:<bucket5m>` | "1" idempotency lock | 600s |
| `summary:request:<request_id>` | JSON state | 600s |

## 6. Search Index (Meilisearch)

Not used. Summaries are not user-searchable in v1.

## 7. Vector Index (Qdrant)

Not used. Compression keeps the window inside Groq's 8k context.

## 8. Object Storage

- R2 archive bucket: `flicko-ai-archive`
  - Path: `summaries/<yyyymm>/<server_id>.parquet`
  - Lifecycle: written nightly; kept 12 months then `Glacier Deep Archive`

## 9. Data Retention

- Hot rows: 30 days in primary
- Cold archive: monthly Parquet to R2
- GDPR delete: cascade on `users.delete` for `requested_by`; channel deletion cascades all summaries

## 10. Sample Queries

```sql
-- Adoption: % DAU clicking summary at least once in last 7d
SELECT COUNT(DISTINCT requested_by)::float
       / NULLIF((SELECT COUNT(DISTINCT user_id) FROM dau WHERE day > now() - interval '7 days'), 0)
FROM ai_summaries
WHERE created_at > now() - interval '7 days';

-- Top channels by summary volume
SELECT channel_id, COUNT(*) AS n, AVG(message_count) AS avg_window
FROM ai_summaries
WHERE created_at > now() - interval '24 hours' AND outcome = 'done'
GROUP BY channel_id
ORDER BY n DESC
LIMIT 20;

-- Cache hit ratio
SELECT
  AVG((cached_hit)::int)::numeric(4,3) AS hit_ratio
FROM ai_summaries
WHERE created_at > now() - interval '1 hour';

-- Refusal share
SELECT outcome, COUNT(*)
FROM ai_summaries
WHERE created_at > now() - interval '24 hours'
GROUP BY outcome;

-- Find broken citations (audit job)
SELECT s.id, b->>'idx' AS bullet_idx, c::uuid AS missing_msg
FROM ai_summaries s,
     jsonb_array_elements(s.bullets) b,
     jsonb_array_elements_text(b->'citations') c
WHERE s.outcome = 'done'
  AND NOT EXISTS (SELECT 1 FROM messages m WHERE m.id = c::uuid);
```
