# Esports Integration — SCHEMA

```sql
CREATE TABLE esports_games (
  slug    TEXT PRIMARY KEY,
  name    TEXT NOT NULL,
  icon    TEXT,
  enabled BOOLEAN NOT NULL DEFAULT true
);
INSERT INTO esports_games VALUES
  ('lol','League of Legends','/icons/lol.png',true),
  ('csgo','Counter-Strike','/icons/cs.png',true),
  ('dota2','Dota 2','/icons/dota2.png',true),
  ('valorant','Valorant','/icons/val.png',true),
  ('r6siege','Rainbow Six Siege','/icons/r6.png',true),
  ('overwatch','Overwatch','/icons/ow.png',true);

CREATE TABLE esports_events (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  provider      TEXT NOT NULL DEFAULT 'pandascore',
  external_id   TEXT NOT NULL,
  game_slug     TEXT NOT NULL REFERENCES esports_games(slug),
  league_id     TEXT,
  league_name   TEXT,
  team_a        TEXT,
  team_b        TEXT,
  team_a_id     TEXT,
  team_b_id     TEXT,
  status        TEXT NOT NULL CHECK (status IN ('upcoming','live','finished','canceled')),
  score_a       INT,
  score_b       INT,
  start_at      TIMESTAMPTZ,
  end_at        TIMESTAMPTZ,
  stream_url    TEXT,
  raw           JSONB,
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (provider, external_id)
);
CREATE INDEX idx_ee_status_start ON esports_events(status, start_at);
CREATE INDEX idx_ee_game         ON esports_events(game_slug);

CREATE TABLE esports_subscriptions (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id   UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  channel_id  UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  game_slug   TEXT NOT NULL REFERENCES esports_games(slug),
  team_id     TEXT,
  league_id   TEXT,
  kind        TEXT NOT NULL CHECK (kind IN ('live','schedule')),
  created_by  UUID NOT NULL REFERENCES users(id),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_es_channel ON esports_subscriptions(channel_id);

CREATE TABLE esports_event_messages (
  event_id    UUID NOT NULL REFERENCES esports_events(id) ON DELETE CASCADE,
  channel_id  UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  message_id  UUID NOT NULL,
  posted_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (event_id, channel_id)
);
```

## RLS
```sql
ALTER TABLE esports_subscriptions ENABLE ROW LEVEL SECURITY;
CREATE POLICY es_read ON esports_subscriptions FOR SELECT
  USING (server_id IN (SELECT server_id FROM server_members WHERE user_id=auth.uid()));
CREATE POLICY es_write ON esports_subscriptions FOR ALL
  USING (server_id IN (SELECT server_id FROM server_members WHERE user_id=auth.uid() AND has_perm('MANAGE_CHANNELS')))
  WITH CHECK (created_by = auth.uid());
```

## Cache
| Key | Value | TTL |
|-----|-------|-----|
| `esp:event:<external>` | event JSON | 30s |
| `esp:list:<game>:upcoming` | list | 5m |

## Migration: `supabase/migrations/154_esports.up.sql`
