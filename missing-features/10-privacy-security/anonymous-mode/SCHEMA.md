# Anonymous Mode — Backend Schema

## 1. Tables

### `server_anon_settings`

```sql
CREATE TABLE server_anon_settings (
  server_id            UUID PRIMARY KEY REFERENCES servers(id) ON DELETE CASCADE,
  allow_anon_joins     BOOLEAN NOT NULL DEFAULT FALSE,
  min_account_age_days INT NOT NULL DEFAULT 14,
  require_email_verified BOOLEAN NOT NULL DEFAULT TRUE,
  exclude_from_xp      BOOLEAN NOT NULL DEFAULT TRUE,
  exclude_from_search  BOOLEAN NOT NULL DEFAULT TRUE,
  created_at           TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### `server_anon_members`

```sql
CREATE TABLE server_anon_members (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id       UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  internal_hash   BYTEA NOT NULL,           -- hmac_sha256(key, server_id||user_id)
  anon_handle     TEXT NOT NULL,            -- e.g. "QuietFox4218"
  anon_avatar_url TEXT NOT NULL,
  hmac_key_version INT NOT NULL DEFAULT 1,  -- for key rotation
  is_revealed     BOOLEAN NOT NULL DEFAULT FALSE,
  revealed_at     TIMESTAMPTZ,
  joined_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  left_at         TIMESTAMPTZ,
  CONSTRAINT uniq_handle_per_server UNIQUE (server_id, anon_handle),
  CONSTRAINT uniq_hash_per_server UNIQUE (server_id, internal_hash),
  CONSTRAINT uniq_user_per_server UNIQUE (server_id, user_id)
);

CREATE INDEX idx_anon_members_server   ON server_anon_members(server_id) WHERE left_at IS NULL;
CREATE INDEX idx_anon_members_hash     ON server_anon_members(server_id, internal_hash);
CREATE INDEX idx_anon_members_user     ON server_anon_members(user_id) WHERE left_at IS NULL;
```

### `server_anon_bans`

```sql
CREATE TABLE server_anon_bans (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id       UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  internal_hash   BYTEA NOT NULL,
  reason          TEXT,
  banned_by       UUID NOT NULL REFERENCES users(id),
  expires_at      TIMESTAMPTZ,            -- NULL = permanent
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  CONSTRAINT uniq_ban UNIQUE (server_id, internal_hash)
);

CREATE INDEX idx_anon_bans_server ON server_anon_bans(server_id);
```

## 2. RLS Policies

```sql
ALTER TABLE server_anon_members ENABLE ROW LEVEL SECURITY;

-- Members can read only their own row
CREATE POLICY "self read"
  ON server_anon_members FOR SELECT
  USING (user_id = auth.uid());

-- Mods read via security-definer function (defined below) — direct table read denied
-- so we add NO mod policy here. The function bypasses RLS as table owner.

CREATE POLICY "self insert via service role"
  ON server_anon_members FOR INSERT
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "self soft-delete"
  ON server_anon_members FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

ALTER TABLE server_anon_bans ENABLE ROW LEVEL SECURITY;

CREATE POLICY "mods of server can read"
  ON server_anon_bans FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM server_members sm
      WHERE sm.server_id = server_anon_bans.server_id
        AND sm.user_id = auth.uid()
        AND sm.role_flags & 2 = 2  -- mod bit
    )
  );

CREATE POLICY "mods of server can ban"
  ON server_anon_bans FOR INSERT
  WITH CHECK (
    banned_by = auth.uid()
    AND EXISTS (
      SELECT 1 FROM server_members sm
      WHERE sm.server_id = server_anon_bans.server_id
        AND sm.user_id = auth.uid()
        AND sm.role_flags & 2 = 2
    )
  );
```

### Mod-view security-definer function

```sql
CREATE OR REPLACE FUNCTION mod_anon_member_view(p_server_id UUID)
RETURNS TABLE (
  anon_handle     TEXT,
  internal_hash   BYTEA,
  joined_at       TIMESTAMPTZ,
  is_revealed     BOOLEAN
)
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM server_members
    WHERE server_id = p_server_id
      AND user_id = auth.uid()
      AND role_flags & 2 = 2
  ) THEN
    RAISE EXCEPTION 'not a mod of this server';
  END IF;

  RETURN QUERY
    SELECT m.anon_handle, m.internal_hash, m.joined_at, m.is_revealed
    FROM server_anon_members m
    WHERE m.server_id = p_server_id
      AND m.left_at IS NULL;
END;
$$;
```

Notice: this function exposes `anon_handle` and `internal_hash` to mods, never `user_id`.

## 3. Triggers

```sql
CREATE TRIGGER anon_settings_updated_at
  BEFORE UPDATE ON server_anon_settings
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Audit any reveal
CREATE OR REPLACE FUNCTION log_anon_reveal()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF OLD.is_revealed = FALSE AND NEW.is_revealed = TRUE THEN
    INSERT INTO audit_log (action, server_id, user_id, metadata)
    VALUES ('anon.reveal', NEW.server_id, NEW.user_id,
            jsonb_build_object('anon_handle', NEW.anon_handle));
  END IF;
  RETURN NEW;
END;
$$;

CREATE TRIGGER anon_reveal_audit
  AFTER UPDATE ON server_anon_members
  FOR EACH ROW EXECUTE FUNCTION log_anon_reveal();
```

## 4. Migration File

Path: `supabase/migrations/215_anonymous_mode.up.sql`
Down: `supabase/migrations/215_anonymous_mode.down.sql`

```sql
-- 215_anonymous_mode.up.sql
BEGIN;

CREATE TABLE server_anon_settings (...);
CREATE TABLE server_anon_members (...);
CREATE TABLE server_anon_bans (...);

CREATE FUNCTION mod_anon_member_view(UUID) RETURNS TABLE(...) ...;
CREATE FUNCTION log_anon_reveal() RETURNS TRIGGER ...;

ALTER TABLE server_anon_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE server_anon_bans    ENABLE ROW LEVEL SECURITY;

-- policies + triggers ...

GRANT EXECUTE ON FUNCTION mod_anon_member_view(UUID) TO authenticated;

COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `anon:handle_taken:<server_id>:<handle>` | bool | 5m |
| `anon:settings:<server_id>` | JSON | 10m |
| `anon:ban:<server_id>:<hash_hex>` | bool | 30m |
| `anon:hmac_key:v<n>` | binary (sealed; only worker reads) | 1h |

## 6. Search Index (Meilisearch)

Anonymous members are **excluded** from the user search index. The membership-indexer worker filters `server_anon_members` rows out before pushing.

If a user later reveals identity, an `anon.member.revealed` event triggers a re-index that adds them with their real profile.

## 7. Vector Index

Not applicable for v1.

## 8. Object Storage (Appwrite)

- Bucket: `anon-avatars`
- Files: deterministic SVG generated server-side from the handle string seed
- Allowed MIME: `image/svg+xml` only (server-uploaded; users cannot upload)
- Max file size: 8 KB
- Permission: `read("any")` (public CDN), no write from clients

## 9. Data Retention

- Hot rows: indefinite while membership active (`left_at IS NULL`).
- On `left_at` set: row retained 30d, then `internal_hash` is preserved in `server_anon_bans` if banned, otherwise row hard-deleted.
- HMAC key versions: kept for 24 months for ban back-resolution; older versions cryptographically erased.
- GDPR delete: cascade on `users.id` removes `server_anon_members` row immediately. Ban record retains `internal_hash` only — not reversible to user without the HMAC key, which we will purge after 30d on user-deletion request to fully tombstone.

## 10. Sample Queries

```sql
-- list anon members (mod-only via security-definer)
SELECT * FROM mod_anon_member_view($1);

-- check ban during join
SELECT 1 FROM server_anon_bans
WHERE server_id = $1
  AND internal_hash = $2
  AND (expires_at IS NULL OR expires_at > now());

-- handle uniqueness check
SELECT 1 FROM server_anon_members
WHERE server_id = $1 AND anon_handle = $2 AND left_at IS NULL;

-- reveal identity (user-driven)
UPDATE server_anon_members
SET is_revealed = TRUE, revealed_at = now()
WHERE server_id = $1 AND user_id = auth.uid();
```
