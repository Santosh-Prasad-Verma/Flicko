# [Feature Name] — Backend Schema

## 1. Tables

### `<feature>_main`

```sql
CREATE TABLE <feature>_main (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id   UUID REFERENCES servers(id) ON DELETE CASCADE,
  user_id     UUID REFERENCES users(id) ON DELETE CASCADE,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  -- columns...
);

CREATE INDEX idx_<feature>_main_server ON <feature>_main(server_id);
CREATE INDEX idx_<feature>_main_user   ON <feature>_main(user_id);
```

### `<feature>_aux`

```sql
CREATE TABLE <feature>_aux (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  parent_id   UUID NOT NULL REFERENCES <feature>_main(id) ON DELETE CASCADE,
  -- columns...
);
```

## 2. RLS Policies

```sql
ALTER TABLE <feature>_main ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Members can read"
  ON <feature>_main FOR SELECT
  USING (server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid()));

CREATE POLICY "Owners can write"
  ON <feature>_main FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "Owners can update"
  ON <feature>_main FOR UPDATE
  USING (user_id = auth.uid());
```

## 3. Triggers

```sql
CREATE TRIGGER <feature>_set_updated_at
  BEFORE UPDATE ON <feature>_main
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();
```

## 4. Migration File

Path: `supabase/migrations/<NNN>_<feature>.up.sql`
Down: `supabase/migrations/<NNN>_<feature>.down.sql`

```sql
-- up
BEGIN;
-- create tables
-- create indexes
-- enable RLS
-- create policies
-- grants
COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `<feature>:<id>` | JSON | 5m |
| `<feature>:list:<server_id>` | JSON list | 1m |

## 6. Search Index (Meilisearch)

```jsonc
{
  "uid": "<feature>",
  "primaryKey": "id",
  "searchableAttributes": ["title", "content"],
  "filterableAttributes": ["server_id", "user_id", "created_at"],
  "sortableAttributes": ["created_at"]
}
```

## 7. Vector Index (Qdrant) — if applicable

```jsonc
{
  "collection": "<feature>",
  "vectors": { "size": 768, "distance": "Cosine" },
  "payload_schema": { "server_id": "keyword", "type": "keyword" }
}
```

## 8. Object Storage (Appwrite)

- Bucket: `<feature>`
- Allowed MIME: __
- Max file size: __
- Permission: `read("user:{userId}")`, `write("user:{userId}")`

## 9. Data Retention

- Hot rows: 90d in primary
- Cold archive: dump to R2 monthly
- GDPR delete: cascade on `users.delete`

## 10. Sample Queries

```sql
-- top __
SELECT * FROM <feature>_main
WHERE server_id = $1
ORDER BY created_at DESC
LIMIT 50;
```
