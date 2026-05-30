# Gaming Profiles Deep — SCHEMA

```sql
CREATE TABLE gaming_profile_settings (
  user_id            UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  enabled            BOOLEAN NOT NULL DEFAULT false,
  public_slug        TEXT UNIQUE,
  visible_sections   TEXT[] NOT NULL DEFAULT ARRAY['stats','achievements','clips','friend_codes','recent'],
  banner_url         TEXT,
  bio               TEXT,
  privacy           TEXT NOT NULL DEFAULT 'public' CHECK (privacy IN ('public','friends','servers','private')),
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE friend_codes (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  game_slug   TEXT NOT NULL,
  code        TEXT NOT NULL,
  label       TEXT,
  verified    BOOLEAN NOT NULL DEFAULT false,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_fc_user ON friend_codes(user_id);

CREATE TABLE recent_games_cache (
  user_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  game_slug    TEXT NOT NULL,
  played_at    TIMESTAMPTZ NOT NULL,
  metadata     JSONB DEFAULT '{}',
  PRIMARY KEY (user_id, game_slug, played_at)
);
CREATE INDEX idx_rgc_user_recent ON recent_games_cache(user_id, played_at DESC);
```

## RLS
```sql
ALTER TABLE gaming_profile_settings ENABLE ROW LEVEL SECURITY;
CREATE POLICY gps_self  ON gaming_profile_settings FOR ALL
  USING (user_id=auth.uid()) WITH CHECK (user_id=auth.uid());
CREATE POLICY gps_read_public ON gaming_profile_settings FOR SELECT
  USING (privacy='public' AND enabled=true);

ALTER TABLE friend_codes ENABLE ROW LEVEL SECURITY;
CREATE POLICY fc_self ON friend_codes FOR ALL
  USING (user_id=auth.uid()) WITH CHECK (user_id=auth.uid());
CREATE POLICY fc_read_public ON friend_codes FOR SELECT
  USING (user_id IN (SELECT user_id FROM gaming_profile_settings WHERE privacy='public' AND enabled=true));
```

## Cache
| Key | Value | TTL |
|-----|-------|-----|
| `gprofile:public:<slug>` | full HTML | 5m (purge on update) |
| `gprofile:user:<id>` | composed JSON | 60s |

## Migration: `supabase/migrations/157_gaming_profiles.up.sql`
