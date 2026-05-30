# Game Launcher — Schema

## Migration 151

```sql
-- 151_create_launcher.sql

CREATE TYPE library_visibility AS ENUM ('public', 'friends', 'off');
CREATE TYPE store_kind AS ENUM ('steam', 'epic', 'gog');

CREATE TABLE game_titles (
    id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
    canonical_name  text NOT NULL,
    icon_url        text NOT NULL,
    cover_url       text,
    publisher       text,
    genres          text[] NOT NULL DEFAULT '{}',
    pegi_age        smallint,
    created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE game_title_store_ids (
    title_id        uuid NOT NULL REFERENCES game_titles(id) ON DELETE CASCADE,
    store           store_kind NOT NULL,
    store_appid     text NOT NULL,
    launch_uri_tmpl text NOT NULL,            -- 'steam://rungameid/{appid}'
    PRIMARY KEY (store, store_appid)
);
CREATE INDEX idx_titles_store ON game_title_store_ids(title_id);

CREATE TABLE linked_library (
    user_id         uuid NOT NULL,
    title_id        uuid NOT NULL REFERENCES game_titles(id) ON DELETE CASCADE,
    store           store_kind NOT NULL,
    install_at      timestamptz NOT NULL DEFAULT now(),
    last_seen_at    timestamptz NOT NULL DEFAULT now(),
    miss_count      smallint NOT NULL DEFAULT 0,    -- consecutive scans not seen
    hidden          boolean NOT NULL DEFAULT false,
    PRIMARY KEY (user_id, title_id)
);
CREATE INDEX idx_lib_user ON linked_library(user_id) WHERE hidden = false;
CREATE INDEX idx_lib_title ON linked_library(title_id) WHERE hidden = false;

CREATE TABLE library_preferences (
    user_id         uuid PRIMARY KEY,
    visibility      library_visibility NOT NULL DEFAULT 'friends',
    hide_playtime   boolean NOT NULL DEFAULT false,
    auto_sync       boolean NOT NULL DEFAULT true,
    updated_at      timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE launch_log (
    id              bigserial PRIMARY KEY,
    user_id         uuid NOT NULL,
    title_id        uuid NOT NULL,
    server_id       uuid,
    voice_room_id   uuid,
    launched_at     timestamptz NOT NULL DEFAULT now(),
    ended_at        timestamptz,
    status          text NOT NULL DEFAULT 'dispatched'  -- dispatched|running|ended|failed
);
CREATE INDEX idx_launch_user_ts ON launch_log(user_id, launched_at DESC);

CREATE TABLE launcher_devices (
    device_id       uuid PRIMARY KEY,
    user_id         uuid NOT NULL,
    os              text NOT NULL,
    app_version     text NOT NULL,
    last_scan_at    timestamptz,
    last_seen_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX idx_devices_user ON launcher_devices(user_id);
```

## RLS

```sql
ALTER TABLE linked_library ENABLE ROW LEVEL SECURITY;
ALTER TABLE library_preferences ENABLE ROW LEVEL SECURITY;
ALTER TABLE launch_log ENABLE ROW LEVEL SECURITY;
ALTER TABLE launcher_devices ENABLE ROW LEVEL SECURITY;

CREATE POLICY library_self_or_visible ON linked_library
    FOR SELECT USING (
        hidden = false AND (
            user_id = auth.uid()
            OR EXISTS (
                SELECT 1 FROM library_preferences p
                WHERE p.user_id = linked_library.user_id
                  AND (p.visibility = 'public'
                       OR (p.visibility = 'friends' AND
                           EXISTS (SELECT 1 FROM friendships f
                                   WHERE f.a = auth.uid() AND f.b = linked_library.user_id)))
            )
        )
    );

CREATE POLICY library_self_write ON linked_library
    FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

CREATE POLICY prefs_self ON library_preferences
    FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

CREATE POLICY launch_self_write ON launch_log
    FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY launch_self_read ON launch_log
    FOR SELECT USING (user_id = auth.uid());

CREATE POLICY devices_self ON launcher_devices
    FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());
```

## Redis keys

| Key | Type | TTL | Purpose |
|---|---|---|---|
| `launcher:common:{voice_room}` | string (json) | 30s | room-common library set |
| `launcher:lib:{user_id}` | string (json) | 5m | per-user library snapshot for friends-of-friends fan-out |
| `launcher:launching:{user_id}:{title_id}` | string | 90s | dedupe launch logs |
| `launcher:scan_lock:{device_id}` | string | 60s | prevent overlapping scans |

## Title canonical seed

```sql
INSERT INTO game_titles (id, canonical_name, icon_url) VALUES
  (gen_random_uuid(), 'Valorant',                '/titles/val.svg'),
  (gen_random_uuid(), 'Counter-Strike 2',        '/titles/cs2.svg'),
  (gen_random_uuid(), 'Apex Legends',            '/titles/apex.svg'),
  (gen_random_uuid(), 'Dota 2',                  '/titles/dota.svg'),
  (gen_random_uuid(), 'League of Legends',       '/titles/lol.svg');
-- ... up to ~500
```

`game_title_store_ids` is populated alongside; e.g. CS2 -> (steam, "730", "steam://rungameid/730").

## Operational notes

- `linked_library.miss_count` increments each scan that doesn't see the title; at 3, UI hides it; at 7 backend marks uninstalled (separate column not shown).
- Indexes are partial on `hidden = false` to keep voice-room intersection fast.
- Friendship lookup in RLS is the hottest dependency; ensure `friendships(a, b)` is indexed `(a, b)`.
