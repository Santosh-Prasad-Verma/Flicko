# Read Receipts Control — Backend Schema

## 1. Tables

### `user_settings` (extension)

```sql
ALTER TABLE user_settings
  ADD COLUMN receipts_default_send BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN receipts_default_see  BOOLEAN NOT NULL DEFAULT FALSE;
```

Reciprocity is enforced in code: a user only "sees" if they "send."

### `user_friend_receipt_overrides`

```sql
CREATE TABLE user_friend_receipt_overrides (
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  friend_id  UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  send       BOOLEAN NOT NULL DEFAULT FALSE,
  see        BOOLEAN NOT NULL DEFAULT FALSE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, friend_id)
);
```

### `user_dm_receipt_overrides`

```sql
CREATE TABLE user_dm_receipt_overrides (
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  dm_id      UUID NOT NULL REFERENCES dms(id) ON DELETE CASCADE,
  send       BOOLEAN NOT NULL DEFAULT FALSE,
  see        BOOLEAN NOT NULL DEFAULT FALSE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, dm_id)
);
```

### `user_server_receipt_overrides`

```sql
CREATE TABLE user_server_receipt_overrides (
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  server_id  UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  send       BOOLEAN NOT NULL DEFAULT FALSE,
  see        BOOLEAN NOT NULL DEFAULT FALSE,
  updated_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, server_id)
);
```

## 2. RLS Policies

```sql
ALTER TABLE user_friend_receipt_overrides ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_dm_receipt_overrides     ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_server_receipt_overrides ENABLE ROW LEVEL SECURITY;

CREATE POLICY "self all" ON user_friend_receipt_overrides
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

CREATE POLICY "self all" ON user_dm_receipt_overrides
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

CREATE POLICY "self all" ON user_server_receipt_overrides
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
```

## 3. Resolver Function

```sql
CREATE OR REPLACE FUNCTION resolve_receipt_policy(
  p_user_id   UUID,
  p_scope_type TEXT,    -- 'dm' | 'server' | 'friend' | 'global'
  p_scope_id  UUID
) RETURNS TABLE (send BOOLEAN, see BOOLEAN)
LANGUAGE plpgsql STABLE
AS $$
BEGIN
  -- DM override wins
  IF p_scope_type = 'dm' THEN
    RETURN QUERY
      SELECT o.send, o.see FROM user_dm_receipt_overrides o
      WHERE o.user_id = p_user_id AND o.dm_id = p_scope_id;
    IF FOUND THEN RETURN; END IF;
  END IF;

  -- Friend override (used when DM has 2 participants)
  IF p_scope_type = 'friend' THEN
    RETURN QUERY
      SELECT o.send, o.see FROM user_friend_receipt_overrides o
      WHERE o.user_id = p_user_id AND o.friend_id = p_scope_id;
    IF FOUND THEN RETURN; END IF;
  END IF;

  -- Server override
  IF p_scope_type = 'server' THEN
    RETURN QUERY
      SELECT o.send, o.see FROM user_server_receipt_overrides o
      WHERE o.user_id = p_user_id AND o.server_id = p_scope_id;
    IF FOUND THEN RETURN; END IF;
  END IF;

  -- Global default
  RETURN QUERY
    SELECT s.receipts_default_send, s.receipts_default_see
    FROM user_settings s
    WHERE s.user_id = p_user_id;
END;
$$;
```

Reciprocity is enforced at the publisher layer: only emit `message.seen` when both sides' resolved policy includes `send=true` (sender-side) and the receiver's `see=true`.

## 4. Migration File

Path: `supabase/migrations/221_read_receipts_control.up.sql`

```sql
BEGIN;

ALTER TABLE user_settings
  ADD COLUMN receipts_default_send BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN receipts_default_see  BOOLEAN NOT NULL DEFAULT FALSE;

CREATE TABLE user_friend_receipt_overrides (...);
CREATE TABLE user_dm_receipt_overrides (...);
CREATE TABLE user_server_receipt_overrides (...);

CREATE FUNCTION resolve_receipt_policy(UUID, TEXT, UUID) ...;

ALTER TABLE user_friend_receipt_overrides ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_dm_receipt_overrides     ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_server_receipt_overrides ENABLE ROW LEVEL SECURITY;
-- policies ...

COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `receipts:dm:<user>:<dm>` | `{send, see}` | 5m |
| `receipts:friend:<user>:<friend>` | `{send, see}` | 5m |
| `receipts:server:<user>:<server>` | `{send, see}` | 5m |
| `receipts:global:<user>` | `{send, see}` | 5m |

Toggle write invalidates the relevant keys + parent.

## 6. Search / Vector / Storage

Not applicable.

## 9. Data Retention

- Override rows persist for the life of the relationship; cascade on delete.

## 10. Sample Queries

```sql
-- read effective DM policy for current user
SELECT * FROM resolve_receipt_policy(auth.uid(), 'dm', $1);

-- toggle on for a specific friend
INSERT INTO user_friend_receipt_overrides (user_id, friend_id, send, see)
VALUES (auth.uid(), $1, TRUE, TRUE)
ON CONFLICT (user_id, friend_id) DO UPDATE
  SET send = EXCLUDED.send, see = EXCLUDED.see, updated_at = now();
```
