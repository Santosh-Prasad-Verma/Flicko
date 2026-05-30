# Game Stats Integration — SCHEMA

```sql
CREATE TABLE linked_game_accounts (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  provider      TEXT NOT NULL CHECK (provider IN ('riot','steam','xbox','psn','bnet')),
  external_id   TEXT NOT NULL,
  display_name  TEXT,
  region        TEXT,
  access_token  BYTEA,
  refresh_token BYTEA,
  expires_at    TIMESTAMPTZ,
  scope         TEXT[],
  visibility    TEXT NOT NULL DEFAULT 'public' CHECK (visibility IN ('public','friends','servers','private')),
  linked_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  unlinked_at   TIMESTAMPTZ,
  UNIQUE (user_id, provider, external_id)
);

CREATE TABLE game_stats_snapshots (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  account_id  UUID NOT NULL REFERENCES linked_game_accounts(id) ON DELETE CASCADE,
  game_slug   TEXT NOT NULL,
  metrics     JSONB NOT NULL,
  rank_label  TEXT,
  rank_tier   INT,
  fetched_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_gss_account ON game_stats_snapshots(account_id, fetched_at DESC);
CREATE INDEX idx_gss_game    ON game_stats_snapshots(game_slug, rank_tier DESC);

CREATE TABLE rank_role_rules (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id   UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  game_slug   TEXT NOT NULL,
  min_tier    INT NOT NULL,
  role_id     UUID NOT NULL REFERENCES roles(id),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

## RLS
```sql
ALTER TABLE linked_game_accounts ENABLE ROW LEVEL SECURITY;
CREATE POLICY lga_self ON linked_game_accounts FOR ALL
  USING (user_id=auth.uid()) WITH CHECK (user_id=auth.uid());

ALTER TABLE game_stats_snapshots ENABLE ROW LEVEL SECURITY;
CREATE POLICY gss_read ON game_stats_snapshots FOR SELECT
  USING (account_id IN (SELECT id FROM linked_game_accounts
                        WHERE user_id=auth.uid()
                           OR visibility='public'
                           OR (visibility='friends' AND user_id IN (SELECT friend_id FROM friends WHERE user_id=auth.uid()))));
```

## Cache
| Key | Value | TTL |
|-----|-------|-----|
| `stats:user:<uid>:<game>` | snapshot JSON | 6h |
| `stats:rate:<provider>` | token bucket | per provider window |

## Encryption
- `access_token`/`refresh_token` encrypted via libsodium with key `STATS_TOKENS_KEY` from Doppler.

## Migration: `supabase/migrations/152_game_stats.up.sql`
