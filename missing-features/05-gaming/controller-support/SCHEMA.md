# Controller Support — SCHEMA

Mostly client-only. Server stores user controller preferences.

```sql
ALTER TABLE user_settings
  ADD COLUMN IF NOT EXISTS controller JSONB NOT NULL DEFAULT '{
    "enabled": true,
    "preset": "default",
    "vibration": true,
    "showHints": true,
    "rebinds": {}
  }'::jsonb;
```

No migration is strictly required if client-stored, but adding a server-side mirror lets the user switch devices without re-configuring:

```sql
CREATE TABLE controller_profiles (
  user_id     UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  preset      TEXT NOT NULL DEFAULT 'default',
  rebinds     JSONB NOT NULL DEFAULT '{}',
  vibration   BOOLEAN NOT NULL DEFAULT true,
  show_hints  BOOLEAN NOT NULL DEFAULT true,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
ALTER TABLE controller_profiles ENABLE ROW LEVEL SECURITY;
CREATE POLICY cp_self ON controller_profiles FOR ALL
  USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
```

Migration: `supabase/migrations/156_controller_profiles.up.sql`

## Cache
None server-side. Local Hive box `controller_state` ties last device + last battery seen.
