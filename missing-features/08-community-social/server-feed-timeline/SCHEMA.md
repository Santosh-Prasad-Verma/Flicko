# Server Feed Timeline — Backend Schema

## 1. Tables

### `feed_items`

```sql
CREATE TABLE feed_items (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id         UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  kind              TEXT NOT NULL CHECK (kind IN ('announcement','forum_post','event','top_message','owner_pin')),
  source_id         UUID NOT NULL,
  source_channel_id UUID REFERENCES channels(id) ON DELETE CASCADE,
  author_id         UUID REFERENCES users(id) ON DELETE SET NULL,
  title             TEXT,
  preview           TEXT CHECK (length(preview) <= 280),
  media_urls        TEXT[] NOT NULL DEFAULT '{}',
  vote_score        INTEGER NOT NULL DEFAULT 0,
  reply_count       INTEGER NOT NULL DEFAULT 0,
  view_count        INTEGER NOT NULL DEFAULT 0,
  click_count       INTEGER NOT NULL DEFAULT 0,
  score             DOUBLE PRECISION NOT NULL DEFAULT 0,
  pinned            BOOLEAN NOT NULL DEFAULT false,
  pinned_order      INTEGER,
  pinned_by         UUID REFERENCES users(id),
  hidden_by_owner   BOOLEAN NOT NULL DEFAULT false,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at        TIMESTAMPTZ,
  UNIQUE (server_id, kind, source_id)
);

CREATE INDEX idx_feed_items_server_score    ON feed_items(server_id, score DESC) WHERE NOT hidden_by_owner;
CREATE INDEX idx_feed_items_server_created  ON feed_items(server_id, created_at DESC) WHERE NOT hidden_by_owner;
CREATE INDEX idx_feed_items_pinned          ON feed_items(server_id, pinned_order) WHERE pinned;
CREATE INDEX idx_feed_items_author          ON feed_items(author_id);
CREATE INDEX idx_feed_items_expires         ON feed_items(expires_at) WHERE expires_at IS NOT NULL;
```

### `feed_user_state`

Tracks last-read timestamps and per-user hides.

```sql
CREATE TABLE feed_user_state (
  user_id        UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  server_id      UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  last_read_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  hidden_items   UUID[] NOT NULL DEFAULT '{}',
  PRIMARY KEY (user_id, server_id)
);

CREATE INDEX idx_feed_user_state_user ON feed_user_state(user_id);
```

### `feed_views`

Lightweight impression log for analytics; partitioned monthly.

```sql
CREATE TABLE feed_views (
  id          BIGSERIAL,
  feed_item_id UUID NOT NULL,
  user_id     UUID NOT NULL,
  server_id   UUID NOT NULL,
  dwell_ms    INTEGER NOT NULL,
  clicked     BOOLEAN NOT NULL DEFAULT false,
  viewed_at   TIMESTAMPTZ NOT NULL DEFAULT now()
) PARTITION BY RANGE (viewed_at);

CREATE INDEX idx_feed_views_item   ON feed_views(feed_item_id);
CREATE INDEX idx_feed_views_server ON feed_views(server_id, viewed_at DESC);
```

## 2. RLS Policies

```sql
ALTER TABLE feed_items      ENABLE ROW LEVEL SECURITY;
ALTER TABLE feed_user_state ENABLE ROW LEVEL SECURITY;
ALTER TABLE feed_views      ENABLE ROW LEVEL SECURITY;

-- Members of the server can read non-hidden items, and only when they have access to the source channel
CREATE POLICY "Members read feed"
  ON feed_items FOR SELECT
  USING (
    NOT hidden_by_owner
    AND server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid())
    AND (
      source_channel_id IS NULL
      OR source_channel_id IN (
        SELECT channel_id FROM channel_visibility WHERE user_id = auth.uid()
      )
    )
  );

-- Pinning requires MANAGE_FEED
CREATE POLICY "Managers can pin"
  ON feed_items FOR UPDATE
  USING (
    server_id IN (
      SELECT server_id FROM server_member_perms
      WHERE user_id = auth.uid() AND (perms & 32) = 32
    )
  );

-- Owner-only insert (worker uses service role bypassing RLS)
CREATE POLICY "Owner pin insert"
  ON feed_items FOR INSERT
  WITH CHECK (
    kind = 'owner_pin'
    AND server_id IN (
      SELECT server_id FROM server_member_perms
      WHERE user_id = auth.uid() AND (perms & 32) = 32
    )
  );

CREATE POLICY "User reads own state"
  ON feed_user_state FOR ALL
  USING (user_id = auth.uid());

CREATE POLICY "Server staff read views"
  ON feed_views FOR SELECT
  USING (
    server_id IN (
      SELECT server_id FROM server_member_perms
      WHERE user_id = auth.uid() AND (perms & 64) = 64
    )
  );
```

## 3. Triggers

```sql
CREATE TRIGGER feed_items_set_updated_at
  BEFORE UPDATE ON feed_items
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Recompute score when vote_score or reply_count changes
CREATE OR REPLACE FUNCTION feed_items_score_recalc() RETURNS TRIGGER AS $$
BEGIN
  NEW.score := (NEW.vote_score::float * 2)
             + (NEW.reply_count::float * 3)
             - GREATEST(0, EXTRACT(EPOCH FROM (now() - NEW.created_at)) / 86400.0);
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER feed_items_score
  BEFORE INSERT OR UPDATE OF vote_score, reply_count ON feed_items
  FOR EACH ROW EXECUTE FUNCTION feed_items_score_recalc();
```

## 4. Migration File

Path: `supabase/migrations/190_server_feed_timeline.up.sql`
Down: `supabase/migrations/190_server_feed_timeline.down.sql`

```sql
-- up
BEGIN;

CREATE TABLE feed_items (...);
CREATE TABLE feed_user_state (...);
CREATE TABLE feed_views (...) PARTITION BY RANGE (viewed_at);
CREATE TABLE feed_views_2026_05 PARTITION OF feed_views
  FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');

-- indexes
-- triggers
-- RLS

GRANT SELECT, INSERT, UPDATE ON feed_items      TO authenticated;
GRANT SELECT, INSERT, UPDATE ON feed_user_state TO authenticated;
GRANT INSERT                  ON feed_views     TO authenticated;
GRANT SELECT                  ON feed_views     TO server_staff_role;

COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `feed:<server_id>:page:<n>:<tab>` | JSON list | 60s |
| `feed:unread:<user_id>:<server_id>` | int | 24h |
| `feed:item:<item_id>` | JSON | 5m |

Cache invalidation: NATS subscriber clears `feed:<server_id>:page:*` on every `flicko.feed.*` event.

## 6. Search Index (Meilisearch)

```jsonc
{
  "uid": "feed_items",
  "primaryKey": "id",
  "searchableAttributes": ["title", "preview"],
  "filterableAttributes": ["server_id", "kind", "author_id", "created_at", "pinned"],
  "sortableAttributes": ["created_at", "score", "vote_score"]
}
```

## 7. Vector Index (Qdrant)

Not used in v1. The "For you" tab uses simple recency-plus-vote ranking.

## 8. Object Storage (Appwrite)

- Bucket: not used directly. `media_urls` reference existing bucket entries from messages, forum, events.

## 9. Data Retention

- Hot rows: 60 days in primary
- Cold archive: dump to R2 monthly via `feed_archive` worker
- GDPR delete: cascades on `users.delete`; per-user state cascades on `users.delete` and `servers.delete`

## 10. Sample Queries

```sql
-- Top tab
SELECT * FROM feed_items
WHERE server_id = $1
  AND NOT hidden_by_owner
ORDER BY pinned DESC, pinned_order ASC, score DESC
LIMIT 20;

-- New tab
SELECT * FROM feed_items
WHERE server_id = $1
  AND created_at > $2  -- cursor
  AND NOT hidden_by_owner
ORDER BY created_at DESC
LIMIT 20;

-- Unread count
SELECT count(*) FROM feed_items fi
JOIN feed_user_state s ON s.server_id = fi.server_id AND s.user_id = $1
WHERE fi.server_id = $2
  AND fi.created_at > s.last_read_at
  AND fi.id <> ALL (s.hidden_items);
```
