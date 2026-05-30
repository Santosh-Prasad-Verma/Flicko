# Encrypted Voice — Backend Schema

## 1. Tables

### `voice_channels` (extension)

```sql
ALTER TABLE voice_channels
  ADD COLUMN e2ee_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN e2ee_min_client_version TEXT,
  ADD COLUMN e2ee_member_cap INT NOT NULL DEFAULT 30;
```

### `e2ee_voice_epochs`

Tracks the current group-key epoch per channel. Note: we never store the key itself, only the epoch number and metadata for distribution.

```sql
CREATE TABLE e2ee_voice_epochs (
  channel_id    UUID PRIMARY KEY REFERENCES voice_channels(id) ON DELETE CASCADE,
  epoch         INT NOT NULL DEFAULT 1,
  rotated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  rotated_by    UUID REFERENCES users(id),
  rotation_reason TEXT NOT NULL CHECK (rotation_reason IN ('init','member_joined','member_left','admin_force','schedule'))
);
```

### `e2ee_voice_envelopes`

A sealed group-key envelope per recipient per epoch. Sealed with the recipient's libsodium box public key — server cannot open it.

```sql
CREATE TABLE e2ee_voice_envelopes (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  channel_id      UUID NOT NULL REFERENCES voice_channels(id) ON DELETE CASCADE,
  epoch           INT NOT NULL,
  recipient_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  sealed_blob     BYTEA NOT NULL,    -- crypto_box_seal output
  sender_public_key BYTEA NOT NULL,  -- ephemeral; for ratcheting
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  consumed_at     TIMESTAMPTZ,
  CONSTRAINT uniq_envelope UNIQUE (channel_id, epoch, recipient_id)
);

CREATE INDEX idx_e2ee_envelopes_recipient
  ON e2ee_voice_envelopes(recipient_id, channel_id);
```

### `e2ee_voice_fingerprints`

Cached per-participant fingerprint for in-call verification UX. Derived from the participant's long-term identity key.

```sql
CREATE TABLE e2ee_voice_fingerprints (
  user_id      UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  fingerprint  TEXT NOT NULL,           -- e.g. "9c4f-3e8a-2d11-..."
  identity_key_pub BYTEA NOT NULL,
  updated_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

## 2. RLS Policies

```sql
ALTER TABLE e2ee_voice_envelopes ENABLE ROW LEVEL SECURITY;

-- A user can only ever read their own envelopes
CREATE POLICY "self read sealed envelope"
  ON e2ee_voice_envelopes FOR SELECT
  USING (recipient_id = auth.uid());

-- Service-role inserts only (key-rotation worker uses service role)
-- No INSERT policy for authenticated; explicit GRANT to service-role connection.

ALTER TABLE e2ee_voice_epochs ENABLE ROW LEVEL SECURITY;

CREATE POLICY "channel members read epoch"
  ON e2ee_voice_epochs FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM channel_members
      WHERE channel_id = e2ee_voice_epochs.channel_id
        AND user_id = auth.uid()
    )
  );

ALTER TABLE e2ee_voice_fingerprints ENABLE ROW LEVEL SECURITY;

CREATE POLICY "all authenticated read fingerprints"
  ON e2ee_voice_fingerprints FOR SELECT
  USING (auth.role() = 'authenticated');
```

## 3. Triggers

```sql
-- On member join/leave, bump epoch and clear envelopes for old epoch
CREATE OR REPLACE FUNCTION bump_e2ee_epoch_on_member_change()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF EXISTS (
    SELECT 1 FROM voice_channels
    WHERE id = COALESCE(NEW.channel_id, OLD.channel_id)
      AND e2ee_enabled = TRUE
  ) THEN
    UPDATE e2ee_voice_epochs
       SET epoch = epoch + 1,
           rotated_at = now(),
           rotation_reason = CASE TG_OP WHEN 'INSERT' THEN 'member_joined' ELSE 'member_left' END
     WHERE channel_id = COALESCE(NEW.channel_id, OLD.channel_id);

    PERFORM pg_notify(
      'e2ee_voice_rotate',
      COALESCE(NEW.channel_id, OLD.channel_id)::text
    );
  END IF;
  RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE TRIGGER channel_members_e2ee_rotate
  AFTER INSERT OR DELETE ON channel_members
  FOR EACH ROW EXECUTE FUNCTION bump_e2ee_epoch_on_member_change();
```

## 4. Migration File

Path: `supabase/migrations/217_encrypted_voice.up.sql`
Down: `supabase/migrations/217_encrypted_voice.down.sql`

```sql
-- 217_encrypted_voice.up.sql
BEGIN;

ALTER TABLE voice_channels
  ADD COLUMN e2ee_enabled BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN e2ee_min_client_version TEXT,
  ADD COLUMN e2ee_member_cap INT NOT NULL DEFAULT 30;

CREATE TABLE e2ee_voice_epochs (...);
CREATE TABLE e2ee_voice_envelopes (...);
CREATE TABLE e2ee_voice_fingerprints (...);

CREATE FUNCTION bump_e2ee_epoch_on_member_change() ...;
CREATE TRIGGER channel_members_e2ee_rotate ...;

ALTER TABLE e2ee_voice_envelopes ENABLE ROW LEVEL SECURITY;
ALTER TABLE e2ee_voice_epochs    ENABLE ROW LEVEL SECURITY;
ALTER TABLE e2ee_voice_fingerprints ENABLE ROW LEVEL SECURITY;

-- policies ...

COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `e2ee:voice:epoch:<channel_id>` | int | 1h |
| `e2ee:voice:fingerprint:<user_id>` | string | 24h |
| `e2ee:voice:livekit_token:<user_id>:<channel_id>` | JWT | 5m |

**Important:** keys themselves are *never* cached. Only metadata.

## 6. Search Index

Not applicable. E2EE channels are not searchable.

## 7. Vector Index

Not applicable.

## 8. Object Storage

No persistent media storage. LiveKit relays only. Recording bucket is explicitly *not* configured for E2EE channels.

## 9. Data Retention

- Sealed envelopes: retained until consumed by recipient + 24h (replay protection grace), then hard-deleted.
- Epoch records: retained 90d for debugging then archived.
- Fingerprints: retained as long as user account exists.
- LiveKit metadata (call duration, participant list): 90d.
- **Audio content: never stored.**

## 10. Sample Queries

```sql
-- get my envelope for a channel at the current epoch
SELECT v.epoch, e.sealed_blob, e.sender_public_key
FROM e2ee_voice_epochs v
JOIN e2ee_voice_envelopes e
  ON e.channel_id = v.channel_id
 AND e.epoch = v.epoch
 AND e.recipient_id = auth.uid()
WHERE v.channel_id = $1;

-- list participant fingerprints (for verification UI)
SELECT u.id, u.username, f.fingerprint
FROM channel_members cm
JOIN users u ON u.id = cm.user_id
JOIN e2ee_voice_fingerprints f ON f.user_id = u.id
WHERE cm.channel_id = $1;
```
