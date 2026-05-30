# Server Reviews — Backend Schema

## 1. Tables

### `server_reviews`

```sql
CREATE TABLE server_reviews (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id       UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  rating          SMALLINT NOT NULL CHECK (rating BETWEEN 1 AND 5),
  body            TEXT CHECK (length(body) <= 1000),
  helpful_count   INTEGER NOT NULL DEFAULT 0,
  report_count    INTEGER NOT NULL DEFAULT 0,
  status          TEXT NOT NULL DEFAULT 'visible' CHECK (status IN ('visible','hidden','removed')),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  edited_at       TIMESTAMPTZ,
  edit_locked_at  TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '30 days'),
  UNIQUE (server_id, user_id)
);

CREATE INDEX idx_server_reviews_server_helpful  ON server_reviews(server_id, helpful_count DESC, created_at DESC) WHERE status = 'visible';
CREATE INDEX idx_server_reviews_server_recent   ON server_reviews(server_id, created_at DESC) WHERE status = 'visible';
CREATE INDEX idx_server_reviews_server_lowest   ON server_reviews(server_id, rating ASC, created_at DESC) WHERE status = 'visible';
CREATE INDEX idx_server_reviews_user            ON server_reviews(user_id);
```

### `server_review_replies`

```sql
CREATE TABLE server_review_replies (
  review_id   UUID PRIMARY KEY REFERENCES server_reviews(id) ON DELETE CASCADE,
  author_id   UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  body        TEXT NOT NULL CHECK (length(body) <= 600),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  edited_at   TIMESTAMPTZ
);
```

### `server_review_helpful`

```sql
CREATE TABLE server_review_helpful (
  review_id   UUID NOT NULL REFERENCES server_reviews(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (review_id, user_id)
);
```

### `server_review_reports`

```sql
CREATE TABLE server_review_reports (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  review_id   UUID NOT NULL REFERENCES server_reviews(id) ON DELETE CASCADE,
  reporter_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  reason      TEXT NOT NULL CHECK (reason IN ('hateful','spam','off_topic','personal_info','other')),
  notes       TEXT,
  status      TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','resolved','dismissed')),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  resolved_at TIMESTAMPTZ,
  UNIQUE (review_id, reporter_id)
);
```

### `server_review_aggs` (materialized)

```sql
CREATE MATERIALIZED VIEW server_review_aggs AS
SELECT
  server_id,
  count(*)                                            AS total_count,
  avg(rating)::numeric(3,2)                           AS avg_rating,
  count(*) FILTER (WHERE rating = 5)                  AS count_5,
  count(*) FILTER (WHERE rating = 4)                  AS count_4,
  count(*) FILTER (WHERE rating = 3)                  AS count_3,
  count(*) FILTER (WHERE rating = 2)                  AS count_2,
  count(*) FILTER (WHERE rating = 1)                  AS count_1,
  max(created_at)                                     AS last_review_at
FROM server_reviews
WHERE status = 'visible'
GROUP BY server_id;

CREATE UNIQUE INDEX idx_server_review_aggs_server ON server_review_aggs(server_id);
```

## 2. RLS Policies

```sql
ALTER TABLE server_reviews          ENABLE ROW LEVEL SECURITY;
ALTER TABLE server_review_replies   ENABLE ROW LEVEL SECURITY;
ALTER TABLE server_review_helpful   ENABLE ROW LEVEL SECURITY;
ALTER TABLE server_review_reports   ENABLE ROW LEVEL SECURITY;

-- Public read for visible reviews on public servers
CREATE POLICY "Public read visible"
  ON server_reviews FOR SELECT
  USING (
    status = 'visible'
    AND server_id IN (SELECT id FROM servers WHERE visibility = 'public')
  );

-- Eligibility-gated insert
CREATE POLICY "Eligible members write"
  ON server_reviews FOR INSERT
  WITH CHECK (
    user_id = auth.uid()
    AND server_id IN (
      SELECT sm.server_id FROM server_members sm
      WHERE sm.user_id = auth.uid()
        AND sm.joined_at <= now() - interval '14 days'
    )
    AND (
      SELECT count(*) FROM messages m
      WHERE m.author_id = auth.uid() AND m.server_id = server_reviews.server_id
    ) >= 20
  );

-- Self update inside edit window only
CREATE POLICY "Self edit window"
  ON server_reviews FOR UPDATE
  USING (user_id = auth.uid() AND now() < edit_locked_at);

CREATE POLICY "Owner reply"
  ON server_review_replies FOR INSERT
  WITH CHECK (
    author_id = auth.uid()
    AND author_id IN (
      SELECT owner_id FROM servers
      WHERE id = (SELECT server_id FROM server_reviews WHERE id = server_review_replies.review_id)
    )
  );

CREATE POLICY "Helpful self"
  ON server_review_helpful FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Reports by reporter or mods"
  ON server_review_reports FOR SELECT
  USING (
    reporter_id = auth.uid()
    OR EXISTS (SELECT 1 FROM server_reviews sr
               JOIN server_member_perms p ON p.server_id = sr.server_id
               WHERE sr.id = server_review_reports.review_id
               AND p.user_id = auth.uid() AND (p.perms & 64) = 64)
  );
```

## 3. Triggers

```sql
CREATE TRIGGER server_reviews_set_edited_at
  BEFORE UPDATE ON server_reviews
  FOR EACH ROW WHEN (OLD.body IS DISTINCT FROM NEW.body OR OLD.rating IS DISTINCT FROM NEW.rating)
  EXECUTE FUNCTION set_edited_at();

CREATE OR REPLACE FUNCTION refresh_server_review_aggs() RETURNS TRIGGER AS $$
BEGIN
  REFRESH MATERIALIZED VIEW CONCURRENTLY server_review_aggs;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

-- Async via NATS in production; the trigger is dev-only fallback
```

## 4. Migration File

Path: `supabase/migrations/192_server_reviews.up.sql`
Down: `supabase/migrations/192_server_reviews.down.sql`

```sql
-- up
BEGIN;
  CREATE TABLE server_reviews (...);
  CREATE TABLE server_review_replies (...);
  CREATE TABLE server_review_helpful (...);
  CREATE TABLE server_review_reports (...);
  CREATE MATERIALIZED VIEW server_review_aggs AS ...;
  -- indexes, triggers, RLS, grants
COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `reviews:<server_id>:p<n>:<sort>` | JSON list | 60s |
| `reviews_agg:<server_id>` | JSON | 300s |
| `reviews_eligibility:<user_id>:<server_id>` | bool+meta | 600s |

## 6. Search Index (Meilisearch)

```jsonc
{
  "uid": "server_reviews",
  "primaryKey": "id",
  "searchableAttributes": ["body"],
  "filterableAttributes": ["server_id","rating","status","created_at"],
  "sortableAttributes": ["created_at","helpful_count","rating"]
}
```

## 7. Vector Index (Qdrant)

Not used.

## 8. Object Storage (Appwrite)

Not used.

## 9. Data Retention

- Reviews retained for the lifetime of the server
- On user delete: cascade -> review removed; replies preserved with `[user removed]` marker
- On server delete: cascade

## 10. Sample Queries

```sql
-- Helpful sort
SELECT * FROM server_reviews
WHERE server_id = $1 AND status = 'visible'
ORDER BY helpful_count DESC, created_at DESC
LIMIT 20;

-- Aggregates
SELECT * FROM server_review_aggs WHERE server_id = $1;

-- Eligibility
SELECT
  (sm.joined_at <= now() - interval '14 days') AS age_ok,
  (SELECT count(*) FROM messages m WHERE m.author_id = $1 AND m.server_id = $2) AS msg_count
FROM server_members sm
WHERE sm.user_id = $1 AND sm.server_id = $2;
```
