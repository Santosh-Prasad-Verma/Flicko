# Post Upvote/Downvote Global — Backend Schema

## 1. Tables

### `votes`

```sql
CREATE TABLE votes (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  target_kind  TEXT NOT NULL CHECK (target_kind IN ('message','forum_post')),
  target_id    UUID NOT NULL,
  channel_id   UUID REFERENCES channels(id) ON DELETE CASCADE,
  server_id    UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  value        SMALLINT NOT NULL CHECK (value IN (-1, 1)),
  suspect      BOOLEAN NOT NULL DEFAULT false,
  ip_hash      BYTEA,
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (user_id, target_kind, target_id)
);

CREATE INDEX idx_votes_target          ON votes(target_kind, target_id);
CREATE INDEX idx_votes_channel_created ON votes(channel_id, created_at DESC);
CREATE INDEX idx_votes_server_recent   ON votes(server_id, created_at DESC);
CREATE INDEX idx_votes_suspect         ON votes(server_id) WHERE suspect = true;
```

### `vote_counts`

Denormalized counts; updated by trigger and rebuilt by worker.

```sql
CREATE TABLE vote_counts (
  target_kind TEXT NOT NULL,
  target_id   UUID NOT NULL,
  up_count    INTEGER NOT NULL DEFAULT 0,
  down_count  INTEGER NOT NULL DEFAULT 0,
  net_score   INTEGER GENERATED ALWAYS AS (up_count - down_count) STORED,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (target_kind, target_id)
);

CREATE INDEX idx_vote_counts_score ON vote_counts(net_score DESC);
```

### `channel_settings` extension

```sql
ALTER TABLE channel_settings
  ADD COLUMN votes_enabled       BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN disable_downvote    BOOLEAN NOT NULL DEFAULT false,
  ADD COLUMN votes_min_age_hours INTEGER NOT NULL DEFAULT 24;
```

For forum channels we default `votes_enabled = true` via a one-time data migration.

## 2. RLS Policies

```sql
ALTER TABLE votes        ENABLE ROW LEVEL SECURITY;
ALTER TABLE vote_counts  ENABLE ROW LEVEL SECURITY;

-- A user can read their own votes
CREATE POLICY "Self read votes"
  ON votes FOR SELECT
  USING (user_id = auth.uid());

-- Mods of the server can read all votes for audit
CREATE POLICY "Mods read votes"
  ON votes FOR SELECT
  USING (
    server_id IN (
      SELECT server_id FROM server_member_perms
      WHERE user_id = auth.uid() AND (perms & 64) = 64
    )
  );

-- A user can insert/upsert their own vote, only on enabled channels
CREATE POLICY "Self write vote"
  ON votes FOR INSERT
  WITH CHECK (
    user_id = auth.uid()
    AND server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid())
    AND (
      target_kind = 'forum_post'
      OR EXISTS (
        SELECT 1 FROM channel_settings cs
        WHERE cs.channel_id = votes.channel_id AND cs.votes_enabled = true
      )
    )
    AND (now() - (SELECT created_at FROM users WHERE id = auth.uid()))
        >= make_interval(hours => COALESCE(
          (SELECT votes_min_age_hours FROM channel_settings WHERE channel_id = votes.channel_id),
          24
        ))
  );

-- Public read of counts for the visible target's channel
CREATE POLICY "Read counts visible"
  ON vote_counts FOR SELECT
  USING (true);
```

## 3. Triggers

```sql
CREATE OR REPLACE FUNCTION votes_apply_count() RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    INSERT INTO vote_counts (target_kind, target_id, up_count, down_count)
    VALUES (NEW.target_kind, NEW.target_id,
            CASE WHEN NEW.value = 1 THEN 1 ELSE 0 END,
            CASE WHEN NEW.value = -1 THEN 1 ELSE 0 END)
    ON CONFLICT (target_kind, target_id) DO UPDATE SET
      up_count   = vote_counts.up_count   + EXCLUDED.up_count,
      down_count = vote_counts.down_count + EXCLUDED.down_count,
      updated_at = now();
  ELSIF TG_OP = 'UPDATE' AND OLD.value <> NEW.value THEN
    UPDATE vote_counts SET
      up_count   = up_count   + (CASE WHEN NEW.value = 1 THEN 1 ELSE 0 END) - (CASE WHEN OLD.value = 1 THEN 1 ELSE 0 END),
      down_count = down_count + (CASE WHEN NEW.value = -1 THEN 1 ELSE 0 END) - (CASE WHEN OLD.value = -1 THEN 1 ELSE 0 END),
      updated_at = now()
    WHERE target_kind = NEW.target_kind AND target_id = NEW.target_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE vote_counts SET
      up_count   = GREATEST(0, up_count   - (CASE WHEN OLD.value = 1 THEN 1 ELSE 0 END)),
      down_count = GREATEST(0, down_count - (CASE WHEN OLD.value = -1 THEN 1 ELSE 0 END)),
      updated_at = now()
    WHERE target_kind = OLD.target_kind AND target_id = OLD.target_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER votes_count_apply
  AFTER INSERT OR UPDATE OR DELETE ON votes
  FOR EACH ROW EXECUTE FUNCTION votes_apply_count();
```

## 4. Migration File

Path: `supabase/migrations/191_votes_global.up.sql`
Down: `supabase/migrations/191_votes_global.down.sql`

```sql
-- up
BEGIN;
  CREATE TABLE votes (...);
  CREATE TABLE vote_counts (...);
  ALTER TABLE channel_settings ADD COLUMN votes_enabled ...;
  -- triggers
  -- RLS
  GRANT SELECT, INSERT, UPDATE, DELETE ON votes      TO authenticated;
  GRANT SELECT                          ON vote_counts TO authenticated;

  -- enable for forum channels
  UPDATE channel_settings SET votes_enabled = true
  WHERE channel_id IN (SELECT id FROM channels WHERE kind = 'forum');
COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `vote:user:<u>:tgt:<kind>:<id>` | -1/0/1 | 60s |
| `vote_count:<kind>:<id>` | int | 30s |
| `vote_rate:<u>:bucket` | tokens | rolling |
| `vote_dedup:<u>:<id>` | "" | 1s SETNX |

## 6. Search Index (Meilisearch)

Not used directly. Vote scores feed message search ranking.

## 7. Vector Index (Qdrant)

Not used.

## 8. Object Storage (Appwrite)

Not used.

## 9. Data Retention

- `votes` retained for 365 days then archived to R2
- `vote_counts` permanent
- GDPR: cascade on `users.delete`

## 10. Sample Queries

```sql
-- Top messages in a channel last 24h
SELECT m.*
FROM messages m
JOIN vote_counts vc ON vc.target_kind = 'message' AND vc.target_id = m.id
WHERE m.channel_id = $1 AND m.created_at > now() - interval '24 hours'
ORDER BY vc.net_score DESC
LIMIT 20;

-- Brigade detection: cluster of new accounts on one target
SELECT v.target_id, count(*) AS suspicious
FROM votes v
JOIN users u ON u.id = v.user_id
WHERE v.created_at > now() - interval '15 minutes'
  AND u.created_at > now() - interval '14 days'
GROUP BY v.target_id
HAVING count(*) >= 8;
```
