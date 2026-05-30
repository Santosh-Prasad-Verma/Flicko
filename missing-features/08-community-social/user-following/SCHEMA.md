# User Following — Backend Schema

## 1. Tables

### `follows`

```sql
CREATE TABLE follows (
  follower_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  followee_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  status        TEXT NOT NULL DEFAULT 'accepted'
                  CHECK (status IN ('pending','accepted','declined','blocked')),
  notify_level  TEXT NOT NULL DEFAULT 'highlights'
                  CHECK (notify_level IN ('all','highlights','none')),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  accepted_at   TIMESTAMPTZ,
  PRIMARY KEY (follower_id, followee_id),
  CHECK (follower_id <> followee_id)
);

CREATE INDEX idx_follows_followee ON follows(followee_id, created_at DESC) WHERE status = 'accepted';
CREATE INDEX idx_follows_follower ON follows(follower_id, created_at DESC) WHERE status = 'accepted';
CREATE INDEX idx_follows_pending  ON follows(followee_id) WHERE status = 'pending';
```

### `follow_settings`

```sql
CREATE TABLE follow_settings (
  user_id            UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  followable         BOOLEAN NOT NULL DEFAULT true,
  require_approval   BOOLEAN NOT NULL DEFAULT false,
  show_following     BOOLEAN NOT NULL DEFAULT true,
  show_followers     BOOLEAN NOT NULL DEFAULT true,
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### `follow_counts`

```sql
CREATE TABLE follow_counts (
  user_id          UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  followers_count  INTEGER NOT NULL DEFAULT 0,
  following_count  INTEGER NOT NULL DEFAULT 0,
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### `home_feed_items`

```sql
CREATE TABLE home_feed_items (
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  item_id     UUID NOT NULL,
  kind        TEXT NOT NULL CHECK (kind IN ('blog_post','top_message','forum_post','event_rsvp')),
  source_user UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  inserted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  score       DOUBLE PRECISION NOT NULL DEFAULT 0,
  read_at     TIMESTAMPTZ,
  PRIMARY KEY (user_id, item_id, kind)
);

CREATE INDEX idx_home_feed_user_score ON home_feed_items(user_id, score DESC, inserted_at DESC);
CREATE INDEX idx_home_feed_unread     ON home_feed_items(user_id) WHERE read_at IS NULL;
```

## 2. RLS Policies

```sql
ALTER TABLE follows         ENABLE ROW LEVEL SECURITY;
ALTER TABLE follow_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE follow_counts   ENABLE ROW LEVEL SECURITY;
ALTER TABLE home_feed_items ENABLE ROW LEVEL SECURITY;

-- Self read for follows
CREATE POLICY "Self read follows"
  ON follows FOR SELECT
  USING (follower_id = auth.uid() OR followee_id = auth.uid());

-- Public read of accepted follows when both parties allow
CREATE POLICY "Public follower list when allowed"
  ON follows FOR SELECT
  USING (
    status = 'accepted'
    AND EXISTS (SELECT 1 FROM follow_settings WHERE user_id = follows.followee_id AND show_followers)
    AND EXISTS (SELECT 1 FROM follow_settings WHERE user_id = follows.follower_id AND show_following)
  );

-- Only follower can write/update own follow row
CREATE POLICY "Self insert follow"
  ON follows FOR INSERT
  WITH CHECK (
    follower_id = auth.uid()
    AND NOT EXISTS (
      SELECT 1 FROM user_blocks
      WHERE blocker_id = followee_id AND blocked_id = follower_id
    )
    AND EXISTS (
      SELECT 1 FROM follow_settings
      WHERE user_id = follows.followee_id AND followable = true
    )
  );

CREATE POLICY "Followee accepts/declines"
  ON follows FOR UPDATE
  USING (followee_id = auth.uid() AND status = 'pending');

CREATE POLICY "Either party deletes"
  ON follows FOR DELETE
  USING (follower_id = auth.uid() OR followee_id = auth.uid());

CREATE POLICY "Self read settings"
  ON follow_settings FOR ALL
  USING (user_id = auth.uid());

CREATE POLICY "Public read counts when allowed"
  ON follow_counts FOR SELECT
  USING (
    user_id = auth.uid()
    OR EXISTS (SELECT 1 FROM follow_settings WHERE user_id = follow_counts.user_id AND show_followers)
  );

CREATE POLICY "Self read home feed"
  ON home_feed_items FOR ALL
  USING (user_id = auth.uid());
```

## 3. Triggers

```sql
CREATE OR REPLACE FUNCTION follows_apply_count() RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' AND NEW.status = 'accepted' THEN
    INSERT INTO follow_counts (user_id, followers_count) VALUES (NEW.followee_id, 1)
    ON CONFLICT (user_id) DO UPDATE SET followers_count = follow_counts.followers_count + 1, updated_at = now();
    INSERT INTO follow_counts (user_id, following_count) VALUES (NEW.follower_id, 1)
    ON CONFLICT (user_id) DO UPDATE SET following_count = follow_counts.following_count + 1, updated_at = now();
  ELSIF TG_OP = 'UPDATE' AND OLD.status = 'pending' AND NEW.status = 'accepted' THEN
    -- accept transition
    INSERT INTO follow_counts (user_id, followers_count) VALUES (NEW.followee_id, 1)
    ON CONFLICT (user_id) DO UPDATE SET followers_count = follow_counts.followers_count + 1;
    INSERT INTO follow_counts (user_id, following_count) VALUES (NEW.follower_id, 1)
    ON CONFLICT (user_id) DO UPDATE SET following_count = follow_counts.following_count + 1;
  ELSIF TG_OP = 'DELETE' AND OLD.status = 'accepted' THEN
    UPDATE follow_counts SET followers_count = GREATEST(0, followers_count - 1) WHERE user_id = OLD.followee_id;
    UPDATE follow_counts SET following_count = GREATEST(0, following_count - 1) WHERE user_id = OLD.follower_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER follows_count_apply
  AFTER INSERT OR UPDATE OR DELETE ON follows
  FOR EACH ROW EXECUTE FUNCTION follows_apply_count();
```

## 4. Migration File

Path: `supabase/migrations/193_user_following.up.sql`

```sql
-- up
BEGIN;
  CREATE TABLE follows (...);
  CREATE TABLE follow_settings (...);
  CREATE TABLE follow_counts (...);
  CREATE TABLE home_feed_items (...);
  -- indexes, triggers, RLS, grants
  GRANT SELECT, INSERT, UPDATE, DELETE ON follows TO authenticated;
  GRANT SELECT, INSERT, UPDATE         ON follow_settings TO authenticated;
  GRANT SELECT                         ON follow_counts   TO authenticated;
  GRANT SELECT, UPDATE                 ON home_feed_items TO authenticated;
COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `follows:user:<u>:following` | UUID set | 5m |
| `follows:user:<u>:followers` | UUID set | 5m |
| `follow_counts:<u>` | { fans, following } | 5m |
| `home_feed:<u>:p<n>` | JSON list | 60s |

## 6. Search Index (Meilisearch)

Not used.

## 7. Vector Index (Qdrant)

Not used (friend-suggestions uses Qdrant; this feature does not).

## 8. Object Storage (Appwrite)

Not used.

## 9. Data Retention

- Follows persist for life of accounts
- Home feed items pruned after 30 days
- GDPR delete: cascade

## 10. Sample Queries

```sql
-- Am I following X?
SELECT 1 FROM follows
WHERE follower_id = $1 AND followee_id = $2 AND status = 'accepted';

-- Mutual?
SELECT
  EXISTS (SELECT 1 FROM follows WHERE follower_id=$1 AND followee_id=$2 AND status='accepted') AS i_follow,
  EXISTS (SELECT 1 FROM follows WHERE follower_id=$2 AND followee_id=$1 AND status='accepted') AS they_follow;

-- Home feed page
SELECT * FROM home_feed_items
WHERE user_id = $1
ORDER BY score DESC, inserted_at DESC
LIMIT 20;
```
