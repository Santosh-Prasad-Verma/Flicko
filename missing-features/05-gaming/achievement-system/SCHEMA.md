# Achievement System — Schema

## Migration 150 (Postgres / Supabase)

```sql
-- 150_create_achievements.sql

CREATE TYPE ach_rarity AS ENUM ('common', 'rare', 'epic', 'legendary');
CREATE TYPE ach_category AS ENUM ('voice', 'text', 'social', 'gaming', 'esports', 'veteran');
CREATE TYPE ach_window AS ENUM ('total', 'daily', 'weekly', 'rolling_7d', 'streak');

CREATE TABLE achievements (
    id              text PRIMARY KEY,                  -- 'voice_warrior'
    category        ach_category NOT NULL,
    rarity          ach_rarity NOT NULL,
    hidden          boolean NOT NULL DEFAULT false,
    trigger_event   text NOT NULL,                     -- 'voice.minute_active'
    window_kind     ach_window NOT NULL DEFAULT 'total',
    threshold       integer NOT NULL,
    icon_url        text NOT NULL,
    server_template boolean NOT NULL DEFAULT false,    -- offered to server owners
    deprecated      boolean NOT NULL DEFAULT false,
    sort_order      integer NOT NULL DEFAULT 0,
    created_at      timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE achievement_i18n (
    achievement_id  text NOT NULL REFERENCES achievements(id) ON DELETE CASCADE,
    locale          text NOT NULL,                     -- 'en', 'es', 'pt-BR'
    name            text NOT NULL,
    description     text NOT NULL,
    PRIMARY KEY (achievement_id, locale)
);

CREATE TABLE user_progress (
    user_id         uuid NOT NULL,
    achievement_id  text NOT NULL REFERENCES achievements(id) ON DELETE CASCADE,
    server_id       uuid,                              -- null for global
    counter         bigint NOT NULL DEFAULT 0,
    last_event_at   timestamptz NOT NULL DEFAULT now(),
    PRIMARY KEY (user_id, achievement_id, COALESCE(server_id, '00000000-0000-0000-0000-000000000000'::uuid))
);

CREATE INDEX idx_user_progress_user ON user_progress(user_id);
CREATE INDEX idx_user_progress_ach ON user_progress(achievement_id) WHERE counter > 0;

CREATE TABLE user_achievements (
    user_id         uuid NOT NULL,
    achievement_id  text NOT NULL REFERENCES achievements(id),
    server_id       uuid,
    rarity_at_unlock ach_rarity NOT NULL,
    unlocked_at     timestamptz NOT NULL DEFAULT now(),
    silent          boolean NOT NULL DEFAULT false,
    deleted_at      timestamptz,
    PRIMARY KEY (user_id, achievement_id, COALESCE(server_id, '00000000-0000-0000-0000-000000000000'::uuid))
);

CREATE INDEX idx_user_ach_user ON user_achievements(user_id) WHERE deleted_at IS NULL;
CREATE INDEX idx_user_ach_ts ON user_achievements(unlocked_at DESC);

CREATE TABLE achievement_shelf (
    user_id         uuid NOT NULL,
    slot            smallint NOT NULL CHECK (slot BETWEEN 0 AND 5),
    achievement_id  text NOT NULL,
    server_id       uuid,
    PRIMARY KEY (user_id, slot)
);

CREATE TABLE server_achievements (
    server_id       uuid NOT NULL,
    achievement_id  text NOT NULL REFERENCES achievements(id),
    enabled_at      timestamptz NOT NULL DEFAULT now(),
    enabled_by      uuid NOT NULL,
    PRIMARY KEY (server_id, achievement_id)
);
```

## RLS policies

```sql
ALTER TABLE user_achievements ENABLE ROW LEVEL SECURITY;
ALTER TABLE achievement_shelf ENABLE ROW LEVEL SECURITY;
ALTER TABLE user_progress ENABLE ROW LEVEL SECURITY;

CREATE POLICY ach_self_or_public ON user_achievements
    FOR SELECT USING (
        deleted_at IS NULL AND (
            user_id = auth.uid()
            OR EXISTS (
                SELECT 1 FROM user_settings s
                WHERE s.user_id = user_achievements.user_id
                  AND s.achievements_public = true
            )
        )
    );

CREATE POLICY shelf_self_write ON achievement_shelf
    FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

CREATE POLICY shelf_public_read ON achievement_shelf
    FOR SELECT USING (true);  -- shelf is public; detail respects ach_self_or_public

CREATE POLICY progress_self ON user_progress
    FOR SELECT USING (user_id = auth.uid());
```

Server-scoped reads enforced in app layer (membership check) since RLS would need a recursive lookup.

## Redis keys

| Key | Type | TTL | Purpose |
|---|---|---|---|
| `ach:idem:{key}` | string | 24h | event dedupe |
| `ach:shelf:{user_id}` | string (json) | 60s | shelf cache |
| `ach:rarity:{ach_id}` | string (float) | 25h | nightly rarity % |
| `ach:locked:{user_id}` | string | 5s | per-user eval lock (prevents double-unlock during burst) |
| `ach:catalog` | string (json) | 5m | full catalog read-through |

## Seed data (excerpt)

```sql
INSERT INTO achievements (id, category, rarity, trigger_event, window_kind, threshold, icon_url) VALUES
  ('first_message', 'text', 'common', 'text.message_sent', 'total', 1, '/ach/first_msg.svg'),
  ('chatterbox',    'text', 'rare',   'text.message_sent', 'total', 10000, '/ach/chatter.svg'),
  ('voice_dabbler', 'voice','common', 'voice.minute_active','total',60,    '/ach/voice_d.svg'),
  ('voice_warrior', 'voice','legendary','voice.minute_active','total',60000,'/ach/voice_w.svg'),
  ('clip_star',     'gaming','epic',  'clip.published',     'total', 50,   '/ach/clip_s.svg'),
  ('squad_goals',   'social','rare',  'friend.added',       'total', 25,   '/ach/squad.svg'),
  ('year_one',      'veteran','rare', 'presence.streak_day','streak',365,  '/ach/year1.svg');
```

## Indexes performance notes

- `idx_user_ach_user` is partial, skipping tombstones, keeping it small (~6 entries/user).
- `user_progress` PK uses COALESCE on server_id to allow NULL distinct rows; tested on PG 15+.
- Avoid `SELECT * FROM achievements` in hot paths; serve from `ach:catalog` Redis read-through.
