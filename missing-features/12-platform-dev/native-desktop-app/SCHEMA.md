# Native Desktop App — Schema

Backend tables for releases, telemetry, and updates:

```sql
CREATE TABLE desktop_releases (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  channel      TEXT NOT NULL CHECK (channel IN ('stable','beta','nightly')),
  version      TEXT NOT NULL,
  os           TEXT NOT NULL CHECK (os IN ('macos','windows','linux')),
  arch         TEXT NOT NULL CHECK (arch IN ('x86_64','arm64')),
  artifact_url TEXT NOT NULL,
  signature    TEXT NOT NULL,
  notes        TEXT,
  released_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  rollout_pct  INT NOT NULL DEFAULT 100 CHECK (rollout_pct BETWEEN 0 AND 100),
  UNIQUE (channel, version, os, arch)
);
CREATE INDEX idx_desktop_releases_active ON desktop_releases(channel, os, arch, released_at DESC);

CREATE TABLE desktop_install_telemetry (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  install_id    UUID NOT NULL,
  user_id       UUID REFERENCES users(id),
  version       TEXT NOT NULL,
  os            TEXT NOT NULL,
  arch          TEXT NOT NULL,
  event         TEXT NOT NULL CHECK (event IN ('install','update','crash','launch','uninstall')),
  metadata      JSONB DEFAULT '{}',
  occurred_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_dit_install ON desktop_install_telemetry(install_id, occurred_at DESC);
CREATE INDEX idx_dit_event   ON desktop_install_telemetry(event, occurred_at DESC);
```

## RLS
```sql
ALTER TABLE desktop_releases ENABLE ROW LEVEL SECURITY;
CREATE POLICY desktop_releases_read ON desktop_releases FOR SELECT USING (true); -- public catalog

ALTER TABLE desktop_install_telemetry ENABLE ROW LEVEL SECURITY;
CREATE POLICY dit_insert_self ON desktop_install_telemetry FOR INSERT
  WITH CHECK (user_id IS NULL OR user_id = auth.uid());
CREATE POLICY dit_read_admin ON desktop_install_telemetry FOR SELECT
  USING (auth.jwt() ->> 'role' = 'service_role');
```

## Cache
| Key | Value | TTL |
|-----|-------|-----|
| `desktop:latest:<channel>:<os>:<arch>` | release JSON | 5m |

## Migration: `supabase/migrations/248_desktop_releases.up.sql`

## Auto-update Manifest
GET `/api/v1/desktop/update?channel=stable&os=macos&arch=arm64&current=1.2.3` →
```json
{
  "available": true,
  "version": "1.2.4",
  "url": "https://cdn.flicko.app/desktop/1.2.4/Flicko-1.2.4-arm64.dmg",
  "signature": "sha256:…",
  "notes": "fixes & improvements",
  "must_update": false
}
```
Tauri Updater consumes this directly.
