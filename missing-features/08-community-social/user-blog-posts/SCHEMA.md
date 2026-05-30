# User Blog Posts — Backend Schema

## 1. Tables

### `blog_posts`

```sql
CREATE TABLE blog_posts (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  author_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title         TEXT NOT NULL CHECK (length(title) BETWEEN 1 AND 200),
  slug          TEXT NOT NULL CHECK (slug ~ '^[a-z0-9-]+$' AND length(slug) <= 80),
  body_md       TEXT NOT NULL,
  body_html     TEXT NOT NULL DEFAULT '',
  excerpt       TEXT CHECK (length(excerpt) <= 280),
  cover_url     TEXT,
  tags          TEXT[] NOT NULL DEFAULT '{}',
  status        TEXT NOT NULL DEFAULT 'draft'
                  CHECK (status IN ('draft','published','unlisted','removed')),
  like_count    INTEGER NOT NULL DEFAULT 0,
  comment_count INTEGER NOT NULL DEFAULT 0,
  view_count    INTEGER NOT NULL DEFAULT 0,
  published_at  TIMESTAMPTZ,
  edited_at     TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (author_id, slug)
);

CREATE INDEX idx_blog_posts_author_pub  ON blog_posts(author_id, published_at DESC) WHERE status = 'published';
CREATE INDEX idx_blog_posts_pub_recent  ON blog_posts(published_at DESC) WHERE status = 'published';
CREATE INDEX idx_blog_posts_tags        ON blog_posts USING gin(tags) WHERE status = 'published';
```

### `blog_post_likes`

```sql
CREATE TABLE blog_post_likes (
  post_id    UUID NOT NULL REFERENCES blog_posts(id) ON DELETE CASCADE,
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (post_id, user_id)
);

CREATE INDEX idx_blog_post_likes_user ON blog_post_likes(user_id, created_at DESC);
```

### `blog_post_comments`

```sql
CREATE TABLE blog_post_comments (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id     UUID NOT NULL REFERENCES blog_posts(id) ON DELETE CASCADE,
  parent_id   UUID REFERENCES blog_post_comments(id) ON DELETE CASCADE,
  author_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  body        TEXT NOT NULL CHECK (length(body) BETWEEN 1 AND 2000),
  status      TEXT NOT NULL DEFAULT 'visible' CHECK (status IN ('visible','hidden','removed')),
  edited_at   TIMESTAMPTZ,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_blog_comments_post     ON blog_post_comments(post_id, created_at) WHERE status = 'visible';
CREATE INDEX idx_blog_comments_parent   ON blog_post_comments(parent_id) WHERE parent_id IS NOT NULL;
CREATE INDEX idx_blog_comments_author   ON blog_post_comments(author_id);
```

### `blog_post_views`

Sampled impressions for analytics; partitioned monthly.

```sql
CREATE TABLE blog_post_views (
  post_id    UUID NOT NULL,
  user_id    UUID,
  ip_hash    BYTEA,
  dwell_ms   INTEGER NOT NULL,
  viewed_at  TIMESTAMPTZ NOT NULL DEFAULT now()
) PARTITION BY RANGE (viewed_at);
```

## 2. RLS Policies

```sql
ALTER TABLE blog_posts          ENABLE ROW LEVEL SECURITY;
ALTER TABLE blog_post_likes     ENABLE ROW LEVEL SECURITY;
ALTER TABLE blog_post_comments  ENABLE ROW LEVEL SECURITY;

-- Public read of published; author reads own drafts
CREATE POLICY "Read published"
  ON blog_posts FOR SELECT
  USING (status IN ('published','unlisted') OR author_id = auth.uid());

-- Author writes own
CREATE POLICY "Author write"
  ON blog_posts FOR ALL
  USING (author_id = auth.uid())
  WITH CHECK (author_id = auth.uid());

CREATE POLICY "Likes self"
  ON blog_post_likes FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Comments readable when the post is readable
CREATE POLICY "Read visible comments"
  ON blog_post_comments FOR SELECT
  USING (
    status = 'visible'
    AND post_id IN (SELECT id FROM blog_posts WHERE status IN ('published','unlisted'))
  );

CREATE POLICY "Authored comments"
  ON blog_post_comments FOR INSERT
  WITH CHECK (
    author_id = auth.uid()
    AND post_id IN (SELECT id FROM blog_posts WHERE status = 'published')
  );

CREATE POLICY "Comment author or post author hide"
  ON blog_post_comments FOR UPDATE
  USING (
    author_id = auth.uid()
    OR EXISTS (SELECT 1 FROM blog_posts WHERE id = blog_post_comments.post_id AND author_id = auth.uid())
  );
```

## 3. Triggers

```sql
CREATE TRIGGER blog_posts_set_edited_at
  BEFORE UPDATE ON blog_posts
  FOR EACH ROW WHEN (OLD.body_md IS DISTINCT FROM NEW.body_md OR OLD.title IS DISTINCT FROM NEW.title)
  EXECUTE FUNCTION set_edited_at();

CREATE OR REPLACE FUNCTION blog_post_likes_count() RETURNS TRIGGER AS $$
BEGIN
  IF TG_OP = 'INSERT' THEN
    UPDATE blog_posts SET like_count = like_count + 1 WHERE id = NEW.post_id;
  ELSIF TG_OP = 'DELETE' THEN
    UPDATE blog_posts SET like_count = GREATEST(0, like_count - 1) WHERE id = OLD.post_id;
  END IF;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER blog_post_likes_apply
  AFTER INSERT OR DELETE ON blog_post_likes
  FOR EACH ROW EXECUTE FUNCTION blog_post_likes_count();
```

## 4. Migration File

Path: `supabase/migrations/194_user_blog_posts.up.sql`

```sql
-- up
BEGIN;
  CREATE TABLE blog_posts (...);
  CREATE TABLE blog_post_likes (...);
  CREATE TABLE blog_post_comments (...);
  CREATE TABLE blog_post_views (...) PARTITION BY RANGE (viewed_at);
  -- indexes, triggers, RLS, grants
COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `post:<id>` | rendered JSON | 5m |
| `post:profile:<u>:p<n>` | post list page | 60s |
| `post:slug:<u>:<slug>` | id | 1h |
| `post:like:<u>:<id>` | bool | 60s |

## 6. Search Index (Meilisearch)

```jsonc
{
  "uid": "blog_posts",
  "primaryKey": "id",
  "searchableAttributes": ["title","excerpt","body_md","tags"],
  "filterableAttributes": ["author_id","status","tags","published_at"],
  "sortableAttributes": ["published_at","like_count","view_count"]
}
```

## 7. Vector Index (Qdrant)

Optional v1.1: per-post embedding for "Related posts".

## 8. Object Storage (Appwrite)

- Bucket: `blog_covers`
- Allowed MIME: image/jpeg, image/png, image/webp
- Max file size: 4 MB
- Permission: read public, write `user:{author}`

## 9. Data Retention

- Posts retained for life of account
- View samples: 90 days hot, archived to R2
- GDPR delete: cascade

## 10. Sample Queries

```sql
-- Profile feed
SELECT * FROM blog_posts
WHERE author_id = $1 AND status = 'published'
ORDER BY published_at DESC
LIMIT 20;

-- Tag firehose
SELECT * FROM blog_posts
WHERE status = 'published' AND tags && $1::text[]
ORDER BY published_at DESC
LIMIT 50;

-- Comment thread
SELECT * FROM blog_post_comments
WHERE post_id = $1 AND status = 'visible'
ORDER BY parent_id NULLS FIRST, created_at;
```
