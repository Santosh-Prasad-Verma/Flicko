# Screen Capture Protection — Backend Schema

## 1. Tables

### `channels` (extension)

```sql
ALTER TABLE channels
  ADD COLUMN screen_capture_protected BOOLEAN NOT NULL DEFAULT FALSE,
  ADD COLUMN screen_capture_protection_set_by UUID REFERENCES users(id),
  ADD COLUMN screen_capture_protection_set_at TIMESTAMPTZ;
```

### `dms` (extension)

```sql
ALTER TABLE dms
  ADD COLUMN screen_capture_protected BOOLEAN NOT NULL DEFAULT FALSE;
```

### `dm_protection_consents`

Both DM participants must consent before protection is active. One toggles, the other receives a consent request.

```sql
CREATE TABLE dm_protection_consents (
  dm_id        UUID NOT NULL REFERENCES dms(id) ON DELETE CASCADE,
  user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  consented    BOOLEAN NOT NULL DEFAULT FALSE,
  consented_at TIMESTAMPTZ,
  PRIMARY KEY (dm_id, user_id)
);
```

### `screen_capture_recording_events`

Audit log of recording-detected events reported by clients. Used for moderation, transparency reports, and "your friend recorded the screen" notifications.

```sql
CREATE TABLE screen_capture_recording_events (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  scope_type   TEXT NOT NULL CHECK (scope_type IN ('channel', 'dm')),
  scope_id     UUID NOT NULL,
  platform     TEXT NOT NULL CHECK (platform IN ('ios', 'android', 'web')),
  started_at   TIMESTAMPTZ NOT NULL,
  stopped_at   TIMESTAMPTZ,
  reported_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_screen_capture_events_scope
  ON screen_capture_recording_events(scope_type, scope_id, started_at DESC);
```

## 2. RLS Policies

```sql
ALTER TABLE dm_protection_consents ENABLE ROW LEVEL SECURITY;

CREATE POLICY "self read/write consent"
  ON dm_protection_consents FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY "dm partner read consent"
  ON dm_protection_consents FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM dm_members
      WHERE dm_id = dm_protection_consents.dm_id
        AND user_id = auth.uid()
    )
  );

ALTER TABLE screen_capture_recording_events ENABLE ROW LEVEL SECURITY;

CREATE POLICY "scope participants can read events"
  ON screen_capture_recording_events FOR SELECT
  USING (
    (scope_type = 'channel' AND EXISTS (
       SELECT 1 FROM channel_members
       WHERE channel_id = screen_capture_recording_events.scope_id
         AND user_id = auth.uid()
     ))
    OR
    (scope_type = 'dm' AND EXISTS (
       SELECT 1 FROM dm_members
       WHERE dm_id = screen_capture_recording_events.scope_id
         AND user_id = auth.uid()
     ))
  );

CREATE POLICY "self insert events"
  ON screen_capture_recording_events FOR INSERT
  WITH CHECK (user_id = auth.uid());
```

## 3. Triggers

```sql
-- A protection-active flag derived from both-party consent in DMs
CREATE OR REPLACE FUNCTION recompute_dm_protection()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  UPDATE dms d
     SET screen_capture_protected = (
       (SELECT COUNT(*) FROM dm_protection_consents
         WHERE dm_id = d.id AND consented = TRUE)
       =
       (SELECT COUNT(*) FROM dm_members WHERE dm_id = d.id)
     )
  WHERE d.id = COALESCE(NEW.dm_id, OLD.dm_id);
  RETURN COALESCE(NEW, OLD);
END;
$$;

CREATE TRIGGER dm_protection_consent_recompute
  AFTER INSERT OR UPDATE OR DELETE ON dm_protection_consents
  FOR EACH ROW EXECUTE FUNCTION recompute_dm_protection();
```

## 4. Migration File

Path: `supabase/migrations/218_screen_capture_protection.up.sql`

```sql
BEGIN;
ALTER TABLE channels ADD COLUMN screen_capture_protected BOOLEAN NOT NULL DEFAULT FALSE;
ALTER TABLE channels ADD COLUMN screen_capture_protection_set_by UUID REFERENCES users(id);
ALTER TABLE channels ADD COLUMN screen_capture_protection_set_at TIMESTAMPTZ;
ALTER TABLE dms ADD COLUMN screen_capture_protected BOOLEAN NOT NULL DEFAULT FALSE;

CREATE TABLE dm_protection_consents (...);
CREATE TABLE screen_capture_recording_events (...);

CREATE FUNCTION recompute_dm_protection() ...;
CREATE TRIGGER dm_protection_consent_recompute ...;

ALTER TABLE dm_protection_consents ENABLE ROW LEVEL SECURITY;
ALTER TABLE screen_capture_recording_events ENABLE ROW LEVEL SECURITY;
-- policies...

COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `screen_cap:channel:<id>` | bool | 5m |
| `screen_cap:dm:<id>` | bool | 5m |

Invalidate on protection change.

## 6. Search Index

Not applicable.

## 7. Vector Index

Not applicable.

## 8. Object Storage

Not applicable. Recording events are metadata only.

## 9. Data Retention

- Recording events: retained 90d for in-product "history" surface, then archived 1 year, then deleted.
- Protection-on/off transitions: kept in audit log indefinitely (small).

## 10. Sample Queries

```sql
-- check if a DM is currently protected
SELECT screen_capture_protected FROM dms WHERE id = $1;

-- recent recording events for a channel
SELECT user_id, started_at, stopped_at, platform
FROM screen_capture_recording_events
WHERE scope_type = 'channel' AND scope_id = $1
ORDER BY started_at DESC
LIMIT 50;

-- consent state
SELECT user_id, consented FROM dm_protection_consents WHERE dm_id = $1;
```
