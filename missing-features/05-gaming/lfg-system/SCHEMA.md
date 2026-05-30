# LFG System — Backend Schema

## 1. Tables

### `lfg_games_catalog`

Static-ish catalog seeded by migration; mods can add custom games per server later.

```sql
CREATE TABLE lfg_games_catalog (
  id            TEXT PRIMARY KEY,           -- 'valorant', 'lol', 'cs2', etc.
  display_name  TEXT NOT NULL,
  icon_url      TEXT,
  schema        JSONB NOT NULL,             -- per-game JSON Schema
  rank_tiers    JSONB NOT NULL DEFAULT '[]'::JSONB,
  regions       JSONB NOT NULL DEFAULT '[]'::JSONB,
  modes         JSONB NOT NULL DEFAULT '[]'::JSONB,
  enabled       BOOLEAN NOT NULL DEFAULT true,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### `lfg_posts`

```sql
CREATE TABLE lfg_posts (
  id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id         UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  author_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  game_id           TEXT NOT NULL REFERENCES lfg_games_catalog(id),
  title             TEXT NOT NULL CHECK (char_length(title) BETWEEN 1 AND 80),
  mode              TEXT NOT NULL,
  filters           JSONB NOT NULL DEFAULT '{}'::JSONB,
  slots_total       SMALLINT NOT NULL CHECK (slots_total BETWEEN 1 AND 16),
  slots_filled      SMALLINT NOT NULL DEFAULT 1,
  voice_channel_id  UUID REFERENCES channels(id) ON DELETE SET NULL,
  cross_server      BOOLEAN NOT NULL DEFAULT false,
  status            TEXT NOT NULL DEFAULT 'open'
    CHECK (status IN ('open','full','closed','expired')),
  expires_at        TIMESTAMPTZ NOT NULL,
  created_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now(),
  closed_at         TIMESTAMPTZ
);

CREATE INDEX idx_lfg_posts_server_status ON lfg_posts(server_id, status, created_at DESC)
  WHERE status IN ('open','full');
CREATE INDEX idx_lfg_posts_game_cross    ON lfg_posts(game_id, status, created_at DESC)
  WHERE cross_server = true AND status = 'open';
CREATE INDEX idx_lfg_posts_author        ON lfg_posts(author_id, created_at DESC);
CREATE INDEX idx_lfg_posts_expires       ON lfg_posts(expires_at) WHERE status = 'open';
CREATE INDEX idx_lfg_posts_filters_gin   ON lfg_posts USING GIN (filters jsonb_path_ops);
```

### `lfg_slots`

```sql
CREATE TABLE lfg_slots (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  post_id     UUID NOT NULL REFERENCES lfg_posts(id) ON DELETE CASCADE,
  position    SMALLINT NOT NULL,            -- 0..slots_total-1
  user_id     UUID REFERENCES users(id) ON DELETE SET NULL,
  role_label  TEXT,                         -- 'duelist','tank','support', etc.
  joined_at   TIMESTAMPTZ,
  left_at     TIMESTAMPTZ,
  UNIQUE (post_id, position)
);

CREATE INDEX idx_lfg_slots_post  ON lfg_slots(post_id, position);
CREATE INDEX idx_lfg_slots_user  ON lfg_slots(user_id) WHERE user_id IS NOT NULL;
```

### `lfg_server_settings`

```sql
CREATE TABLE lfg_server_settings (
  server_id           UUID PRIMARY KEY REFERENCES servers(id) ON DELETE CASCADE,
  enabled             BOOLEAN NOT NULL DEFAULT true,
  cross_server_optin  BOOLEAN NOT NULL DEFAULT false,
  max_per_user_per_h  SMALLINT NOT NULL DEFAULT 3,
  default_voice_size  SMALLINT NOT NULL DEFAULT 5,
  allowed_games       TEXT[] NOT NULL DEFAULT '{}',
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

## 2. RLS Policies

```sql
ALTER TABLE lfg_posts          ENABLE ROW LEVEL SECURITY;
ALTER TABLE lfg_slots          ENABLE ROW LEVEL SECURITY;
ALTER TABLE lfg_server_settings ENABLE ROW LEVEL SECURITY;

-- Read: members of server, OR cross_server posts visible to anyone
CREATE POLICY "lfg_posts_select_members" ON lfg_posts FOR SELECT
  USING (
    cross_server = true
    OR server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid())
  );

CREATE POLICY "lfg_posts_insert_members" ON lfg_posts FOR INSERT
  WITH CHECK (
    author_id = auth.uid()
    AND server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid())
  );

CREATE POLICY "lfg_posts_update_owner" ON lfg_posts FOR UPDATE
  USING (author_id = auth.uid())
  WITH CHECK (author_id = auth.uid());

CREATE POLICY "lfg_posts_delete_owner_or_mod" ON lfg_posts FOR DELETE
  USING (
    author_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM server_members sm
      WHERE sm.server_id = lfg_posts.server_id AND sm.user_id = auth.uid()
        AND sm.role IN ('owner','admin','mod')
    )
  );

CREATE POLICY "lfg_slots_select" ON lfg_slots FOR SELECT
  USING (post_id IN (SELECT id FROM lfg_posts));

CREATE POLICY "lfg_slots_join_self" ON lfg_slots FOR UPDATE
  USING (user_id IS NULL OR user_id = auth.uid())
  WITH CHECK (user_id = auth.uid() OR user_id IS NULL);

CREATE POLICY "lfg_settings_select_members" ON lfg_server_settings FOR SELECT
  USING (server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid()));

CREATE POLICY "lfg_settings_admin_write" ON lfg_server_settings
  FOR ALL USING (
    server_id IN (
      SELECT server_id FROM server_members
      WHERE user_id = auth.uid() AND role IN ('owner','admin')
    )
  );
```

## 3. Triggers

```sql
CREATE TRIGGER lfg_posts_set_updated_at
  BEFORE UPDATE ON lfg_posts
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Auto-flip status to 'full' when slots_filled = slots_total
CREATE OR REPLACE FUNCTION lfg_post_status_check() RETURNS trigger AS $$
BEGIN
  IF NEW.slots_filled >= NEW.slots_total AND NEW.status = 'open' THEN
    NEW.status := 'full';
  ELSIF NEW.slots_filled < NEW.slots_total AND NEW.status = 'full' THEN
    NEW.status := 'open';
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER lfg_posts_status BEFORE UPDATE OF slots_filled ON lfg_posts
  FOR EACH ROW EXECUTE FUNCTION lfg_post_status_check();

-- Recompute slots_filled when a slot is taken/freed
CREATE OR REPLACE FUNCTION lfg_recompute_slots() RETURNS trigger AS $$
DECLARE pid UUID;
BEGIN
  pid := COALESCE(NEW.post_id, OLD.post_id);
  UPDATE lfg_posts SET
    slots_filled = (SELECT count(*) FROM lfg_slots WHERE post_id = pid AND user_id IS NOT NULL),
    updated_at   = now()
  WHERE id = pid;
  RETURN NULL;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER lfg_slots_recompute
  AFTER INSERT OR UPDATE OR DELETE ON lfg_slots
  FOR EACH ROW EXECUTE FUNCTION lfg_recompute_slots();
```

## 4. Migration File

Path: `supabase/migrations/150_lfg_system.up.sql`
Down: `supabase/migrations/150_lfg_system.down.sql`

```sql
-- up
BEGIN;
CREATE TABLE lfg_games_catalog (...);
CREATE TABLE lfg_posts (...);
CREATE TABLE lfg_slots (...);
CREATE TABLE lfg_server_settings (...);
-- indexes, RLS, triggers
-- seed catalog: valorant, lol, cs2, apex, fortnite, ow2, rl, ffxiv, wow, destiny2
INSERT INTO lfg_games_catalog (id, display_name, schema, rank_tiers, regions, modes) VALUES
  ('valorant', 'VALORANT', '{...}'::JSONB, '["iron1",...,"radiant"]'::JSONB,
    '["na-east","na-west","eu","apac","br","kr"]'::JSONB,
    '["unrated","competitive","spike-rush","custom"]'::JSONB);
COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `lfg:list:srv:<server_id>` | sorted IDs | 60s |
| `lfg:list:hub:<game_id>` | sorted IDs | 30s |
| `lfg:post:<id>` | full JSON post + slots | 30s |
| `lfg:rate:<user_id>:<game_id>` | token-bucket | 1h |
| `lfg:lock:slot:<post_id>:<position>` | redlock | 5s |

## 6. Search Index (Meilisearch)

```jsonc
{
  "uid": "lfg_posts",
  "primaryKey": "id",
  "searchableAttributes": ["title", "filters.notes"],
  "filterableAttributes": ["server_id", "game_id", "mode", "status",
    "filters.region", "filters.rank_min", "filters.mic_required"],
  "sortableAttributes": ["created_at", "slots_filled"]
}
```

## 7. Object Storage (Appwrite)

Not used (no media uploads in v1).

## 8. Data Retention

- Hot rows: 30d in primary, then archived to R2 monthly.
- Closed/expired rows: TTL via partition pruning every 30d.
- GDPR delete: cascade on `users.delete`; slots set `user_id = NULL`.

## 9. Sample Queries

```sql
-- Active posts on server, newest first, with author
SELECT p.*, u.display_name AS author_name, u.avatar_url
FROM lfg_posts p
JOIN users u ON u.id = p.author_id
WHERE p.server_id = $1 AND p.status IN ('open','full')
ORDER BY p.created_at DESC
LIMIT 50;

-- Cross-server hub for a game, filtered by rank tier
SELECT * FROM lfg_posts
WHERE game_id = $1
  AND cross_server = true
  AND status = 'open'
  AND filters @> jsonb_build_object('rank_min', $2)
ORDER BY created_at DESC
LIMIT 30;

-- Expirer sweep
UPDATE lfg_posts SET status='expired', closed_at=now()
WHERE status='open' AND expires_at < now();
```
