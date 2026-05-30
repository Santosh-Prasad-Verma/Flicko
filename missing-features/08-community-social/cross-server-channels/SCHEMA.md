# Cross-Server Channels — Backend Schema

## 1. Tables

### `cross_server_links`

A logical link grouping N channels.

```sql
CREATE TABLE cross_server_links (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name          TEXT NOT NULL CHECK (length(name) BETWEEN 1 AND 80),
  status        TEXT NOT NULL DEFAULT 'active'
                  CHECK (status IN ('active','paused','dissolved')),
  proposer_id   UUID NOT NULL REFERENCES users(id),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  dissolved_at  TIMESTAMPTZ
);
```

### `cross_server_link_members`

Many-to-many of channels participating in the link.

```sql
CREATE TABLE cross_server_link_members (
  link_id      UUID NOT NULL REFERENCES cross_server_links(id) ON DELETE CASCADE,
  channel_id   UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  server_id    UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  joined_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  left_at      TIMESTAMPTZ,
  status       TEXT NOT NULL DEFAULT 'active'
                  CHECK (status IN ('pending','active','left','removed')),
  PRIMARY KEY (link_id, channel_id)
);

CREATE INDEX idx_cslm_channel ON cross_server_link_members(channel_id) WHERE status = 'active';
CREATE INDEX idx_cslm_server  ON cross_server_link_members(server_id);
```

### `messages` extension

```sql
ALTER TABLE messages ADD COLUMN link_id UUID REFERENCES cross_server_links(id);
CREATE INDEX idx_messages_link_created ON messages(link_id, created_at DESC) WHERE link_id IS NOT NULL;
```

The original `channel_id` on a linked message records the *primary* channel where it was posted; rendering occurs via the link.

### `channel_message_views`

Materialized per-channel view of messages. Implemented as a SQL view backed by a join, not a separate table for v1.

```sql
CREATE OR REPLACE VIEW channel_message_views AS
SELECT
  cslm.channel_id  AS channel_id,
  m.*
FROM messages m
JOIN cross_server_link_members cslm ON cslm.link_id = m.link_id AND cslm.status = 'active'
WHERE m.link_id IS NOT NULL
UNION ALL
SELECT
  m.channel_id,
  m.*
FROM messages m
WHERE m.link_id IS NULL;
```

### `cross_server_local_mod_actions`

Per-server local moderation overlay.

```sql
CREATE TABLE cross_server_local_mod_actions (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id  UUID NOT NULL REFERENCES messages(id) ON DELETE CASCADE,
  server_id   UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  action      TEXT NOT NULL CHECK (action IN ('hide','warn','remove_locally')),
  reason      TEXT,
  by_user_id  UUID NOT NULL REFERENCES users(id),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (message_id, server_id)
);
```

## 2. RLS Policies

```sql
ALTER TABLE cross_server_links            ENABLE ROW LEVEL SECURITY;
ALTER TABLE cross_server_link_members     ENABLE ROW LEVEL SECURITY;
ALTER TABLE cross_server_local_mod_actions ENABLE ROW LEVEL SECURITY;

-- Read link if member of any participating server
CREATE POLICY "Member read link"
  ON cross_server_links FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM cross_server_link_members cslm
      JOIN server_members sm ON sm.server_id = cslm.server_id AND sm.user_id = auth.uid()
      WHERE cslm.link_id = cross_server_links.id AND cslm.status = 'active'
    )
  );

-- Manage link requires MANAGE_CHANNEL on the channel being added/removed
CREATE POLICY "Manage link"
  ON cross_server_link_members FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1 FROM channel_member_perms cmp
      WHERE cmp.channel_id = cross_server_link_members.channel_id
        AND cmp.user_id = auth.uid() AND (cmp.perms & 4) = 4
    )
  );

CREATE POLICY "Local mod actions"
  ON cross_server_local_mod_actions FOR ALL
  USING (
    server_id IN (
      SELECT server_id FROM server_member_perms
      WHERE user_id = auth.uid() AND (perms & 64) = 64
    )
  );

-- Visibility of messages via link extends existing message RLS through the union view
```

## 3. Triggers

```sql
-- When a member leaves the link, cascade-hide existing visible message rows
CREATE OR REPLACE FUNCTION cslm_on_leave() RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status IN ('left','removed') AND OLD.status = 'active' THEN
    INSERT INTO cross_server_local_mod_actions (message_id, server_id, action, reason, by_user_id)
    SELECT m.id, NEW.server_id, 'hide', 'channel_left_link', NEW.server_id
    FROM messages m WHERE m.link_id = NEW.link_id
    ON CONFLICT (message_id, server_id) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER cslm_leave AFTER UPDATE ON cross_server_link_members
  FOR EACH ROW EXECUTE FUNCTION cslm_on_leave();
```

## 4. Migration File

Path: `supabase/migrations/197_cross_server_channels.up.sql`

```sql
-- up
BEGIN;
  CREATE TABLE cross_server_links (...);
  CREATE TABLE cross_server_link_members (...);
  ALTER TABLE messages ADD COLUMN link_id UUID;
  CREATE INDEX idx_messages_link_created ...;
  CREATE OR REPLACE VIEW channel_message_views AS ...;
  CREATE TABLE cross_server_local_mod_actions (...);
  -- triggers, RLS, grants
COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `link:<id>:members` | UUID set | 5m |
| `link:<id>:perms` | bitmap | 1m |
| `channel_link:<channel_id>` | link_id | 10m |
| `link:msg:<msg_id>:hidden:<server>` | bool | 60s |

## 6. Search Index (Meilisearch)

Linked messages indexed once with `link_id`; query layer joins to filterable `server_id` via channel_member_views.

## 7. Vector Index

Not used.

## 8. Object Storage

Not used.

## 9. Data Retention

- Messages retained per channel policy of any participating server
- Local mod actions kept for 365 days
- Links survive owner change

## 10. Sample Queries

```sql
-- All visible messages for member of channel C
SELECT v.* FROM channel_message_views v
LEFT JOIN cross_server_local_mod_actions a
  ON a.message_id = v.id AND a.server_id = (SELECT server_id FROM channels WHERE id = v.channel_id)
WHERE v.channel_id = $1 AND a.id IS NULL
ORDER BY v.created_at DESC LIMIT 50;

-- Permission intersection: can post if all participating channels allow
SELECT NOT EXISTS (
  SELECT 1 FROM cross_server_link_members cslm
  WHERE cslm.link_id = $1 AND cslm.status = 'active'
    AND NOT EXISTS (
      SELECT 1 FROM channel_member_perms cmp
      WHERE cmp.channel_id = cslm.channel_id AND cmp.user_id = $2 AND (cmp.perms & 2) = 2
    )
) AS can_post;
```
