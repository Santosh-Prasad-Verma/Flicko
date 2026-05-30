# Private Vaults — Backend Schema

## 1. Tables

### `vaults`

One row per user who has enabled a vault.

```sql
CREATE TABLE vaults (
  user_id              UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  setup_at             TIMESTAMPTZ NOT NULL DEFAULT now(),
  kdf_version          INT NOT NULL DEFAULT 1,
  kdf_memory_kib       INT NOT NULL DEFAULT 262144,   -- 256 MiB
  kdf_iterations       INT NOT NULL DEFAULT 3,
  kdf_parallelism      INT NOT NULL DEFAULT 1,
  argon_salt           BYTEA NOT NULL,                -- random per user; 16B
  recovery_seed_set    BOOLEAN NOT NULL DEFAULT FALSE,
  quota_bytes          BIGINT NOT NULL DEFAULT 5368709120,  -- 5 GiB
  used_bytes           BIGINT NOT NULL DEFAULT 0,
  manifest_version     INT NOT NULL DEFAULT 0,
  manifest_ciphertext  BYTEA,                         -- serialized + encrypted on client
  manifest_updated_at  TIMESTAMPTZ
);
```

**Important:** `argon_salt` is the one server-side artifact tied to the user's KDF. It is not the key, but it is required to re-derive the key on a new device alongside the passphrase. Storing it server-side is a deliberate trade-off: clients on a fresh device can fetch salt + KDF params without first decrypting anything. Without the salt, the user could not unlock on a new device unless they remembered both passphrase and salt.

### `vault_objects`

```sql
CREATE TABLE vault_objects (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  appwrite_id     TEXT NOT NULL,           -- opaque storage handle
  ciphertext_size BIGINT NOT NULL,
  ciphertext_sha256 BYTEA NOT NULL,        -- integrity verification
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at      TIMESTAMPTZ,
  CONSTRAINT vault_objects_owner_unique UNIQUE (user_id, appwrite_id)
);

CREATE INDEX idx_vault_objects_user ON vault_objects(user_id) WHERE deleted_at IS NULL;
```

The table is intentionally thin — no filename, no mime type, no folder path. Those live in the encrypted manifest only.

### `vault_recovery_seeds`

We never store the seed itself. We store an HMAC of it to let the user verify they have the correct seed when re-entering it.

```sql
CREATE TABLE vault_recovery_seeds (
  user_id          UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  seed_check_hmac  BYTEA NOT NULL,    -- hmac_sha256(seed, fixed_label) — verifies correctness
  set_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

## 2. RLS Policies

```sql
ALTER TABLE vaults ENABLE ROW LEVEL SECURITY;

CREATE POLICY "self all"
  ON vaults FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

ALTER TABLE vault_objects ENABLE ROW LEVEL SECURITY;

CREATE POLICY "self all"
  ON vault_objects FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

ALTER TABLE vault_recovery_seeds ENABLE ROW LEVEL SECURITY;

CREATE POLICY "self all"
  ON vault_recovery_seeds FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());
```

No mod/admin policy. By design.

## 3. Triggers

```sql
-- maintain used_bytes counter
CREATE OR REPLACE FUNCTION update_vault_used_bytes()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF TG_OP = 'INSERT' AND NEW.deleted_at IS NULL THEN
    UPDATE vaults SET used_bytes = used_bytes + NEW.ciphertext_size WHERE user_id = NEW.user_id;
  ELSIF TG_OP = 'UPDATE' AND OLD.deleted_at IS NULL AND NEW.deleted_at IS NOT NULL THEN
    UPDATE vaults SET used_bytes = used_bytes - OLD.ciphertext_size WHERE user_id = OLD.user_id;
  ELSIF TG_OP = 'DELETE' AND OLD.deleted_at IS NULL THEN
    UPDATE vaults SET used_bytes = used_bytes - OLD.ciphertext_size WHERE user_id = OLD.user_id;
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE TRIGGER vault_object_size_track
  AFTER INSERT OR UPDATE OR DELETE ON vault_objects
  FOR EACH ROW EXECUTE FUNCTION update_vault_used_bytes();
```

## 4. Migration File

Path: `supabase/migrations/220_private_vaults.up.sql`

```sql
BEGIN;

CREATE TABLE vaults (...);
CREATE TABLE vault_objects (...);
CREATE TABLE vault_recovery_seeds (...);

CREATE FUNCTION update_vault_used_bytes() ...;
CREATE TRIGGER vault_object_size_track ...;

ALTER TABLE vaults ENABLE ROW LEVEL SECURITY;
ALTER TABLE vault_objects ENABLE ROW LEVEL SECURITY;
ALTER TABLE vault_recovery_seeds ENABLE ROW LEVEL SECURITY;
-- policies ...

COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `vault:quota:<user_id>` | `{used, limit}` | 5m |

The manifest itself is *not* cached server-side because it is encrypted and the server has no reason to handle it beyond pass-through.

## 6. Search Index

Not applicable. Plaintext content is unavailable to the server. Searchable client-side.

## 7. Vector Index

Not applicable.

## 8. Object Storage (Appwrite)

- Bucket: `user-vault`
- Per-user prefix: `vault/<user_id>/`
- Allowed MIME: `application/octet-stream` only — clients upload opaque ciphertext.
- Max file size: 250 MB per object.
- Permissions: `read("user:{uid}")`, `write("user:{uid}")`.
- Server never enumerates the bucket without scoping to a user.

## 9. Data Retention

- Active vault: indefinite while user account exists.
- Soft-deleted objects (`deleted_at IS NOT NULL`): purged from Appwrite + DB after 7 days.
- GDPR delete: cascade on `users.id` purges all vault data within 24h.
- No PITR for vault tables — backup snapshots include only ciphertext, which is useless.

## 10. Sample Queries

```sql
-- request upload slot
INSERT INTO vault_objects (user_id, appwrite_id, ciphertext_size, ciphertext_sha256)
VALUES ($1, $2, $3, $4)
RETURNING id;

-- check quota
SELECT used_bytes, quota_bytes FROM vaults WHERE user_id = $1;

-- list active objects
SELECT id, appwrite_id, ciphertext_size, created_at
FROM vault_objects
WHERE user_id = auth.uid() AND deleted_at IS NULL
ORDER BY created_at DESC;

-- save manifest version
UPDATE vaults
SET manifest_version = manifest_version + 1,
    manifest_ciphertext = $1,
    manifest_updated_at = now()
WHERE user_id = auth.uid();
```
