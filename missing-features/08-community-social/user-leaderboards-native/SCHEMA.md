# User Leaderboards Native — Backend Schema

## 1. Tables

### `xp_ledger`

Append-only event log; partitioned monthly.

```sql
CREATE TABLE xp_ledger (
  id          BIGSERIAL,
  server_id   UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  source      TEXT NOT NULL CHECK (source IN ('message','voice_minute','reaction_received','helpful_vote','event_attend','daily_login')),
  channel_id  UUID,
  amount      INTEGER NOT NULL,
  reason      TEXT,
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT now()
) PARTITION BY RANGE (occurred_at);

CREATE TABLE xp_ledger_2026_05 PARTITION OF xp_ledger FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');

CREATE INDEX idx_xp_ledger_server_user_time ON xp_ledger(server_id, user_id, occurred_at DESC);
```

### `xp_balances`

Per user/server, multiple windows.

```sql
CREATE TABLE xp_balances (
  server_id   UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  total_xp    BIGINT NOT NULL DEFAULT 0,
  xp_30d      BIGINT NOT NULL DEFAULT 0,
  xp_7d       BIGINT NOT NULL DEFAULT 0,
  xp_today    BIGINT NOT NULL DEFAULT 0,
  level       INTEGER NOT NULL DEFAULT 1,
  rank_30d    INTEGER,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (server_id, user_id)
);

CREATE INDEX idx_xp_balances_server_total ON xp_balances(server_id, total_xp DESC);
CREATE INDEX idx_xp_balances_server_30d   ON xp_balances(server_id, xp_30d DESC);
```

### `xp_rules`

```sql
CREATE TABLE xp_rules (
  server_id            UUID PRIMARY KEY REFERENCES servers(id) ON DELETE CASCADE,
  enabled              BOOLEAN NOT NULL DEFAULT true,
  weights              JSONB NOT NULL DEFAULT '{
    "message": 5,
    "voice_minute": 2,
    "reaction_received": 1,
    "helpful_vote": 8,
    "event_attend": 25,
    "daily_login": 5
  }'::jsonb,
  per_minute_cap       INTEGER NOT NULL DEFAULT 60,
  excluded_channels    UUID[] NOT NULL DEFAULT '{}',
  excluded_role_bots   BOOLEAN NOT NULL DEFAULT true,
  decay_per_day        DOUBLE PRECISION NOT NULL DEFAULT 0,
  season_started_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### `xp_badges`

```sql
CREATE TABLE xp_badges (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id   UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  level       INTEGER NOT NULL,
  awarded_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (server_id, user_id, level)
);
```

## 2. RLS Policies

```sql
ALTER TABLE xp_ledger    ENABLE ROW LEVEL SECURITY;
ALTER TABLE xp_balances  ENABLE ROW LEVEL SECURITY;
ALTER TABLE xp_rules     ENABLE ROW LEVEL SECURITY;
ALTER TABLE xp_badges    ENABLE ROW LEVEL SECURITY;

-- Members can read aggregated balances; ledger restricted to self + mods
CREATE POLICY "Member read balances"
  ON xp_balances FOR SELECT
  USING (server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid()));

CREATE POLICY "Self read ledger"
  ON xp_ledger FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Mod read ledger"
  ON xp_ledger FOR SELECT
  USING (
    server_id IN (
      SELECT server_id FROM server_member_perms
      WHERE user_id = auth.uid() AND (perms & 64) = 64
    )
  );

CREATE POLICY "Manage rules"
  ON xp_rules FOR ALL
  USING (
    server_id IN (
      SELECT server_id FROM server_member_perms
      WHERE user_id = auth.uid() AND (perms & 1) = 1
    )
  );

CREATE POLICY "Read badges public"
  ON xp_badges FOR SELECT
  USING (true);
```

## 3. Triggers

Triggers are intentionally minimal; aggregation is worker-driven.

```sql
CREATE OR REPLACE FUNCTION xp_balances_updated_at() RETURNS TRIGGER AS $$
BEGIN NEW.updated_at := now(); RETURN NEW; END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER xp_balances_touch
  BEFORE UPDATE ON xp_balances
  FOR EACH ROW EXECUTE FUNCTION xp_balances_updated_at();
```

## 4. Migration File

Path: `supabase/migrations/198_user_leaderboards_native.up.sql`

```sql
-- up
BEGIN;
  CREATE TABLE xp_rules (...);
  CREATE TABLE xp_balances (...);
  CREATE TABLE xp_badges (...);
  CREATE TABLE xp_ledger (...) PARTITION BY RANGE (occurred_at);
  CREATE TABLE xp_ledger_2026_05 PARTITION OF xp_ledger ...;
  -- triggers, RLS, grants
COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `lb:server:<sid>:30d:p<n>` | JSON list | 60s |
| `lb:server:<sid>:total:p<n>` | JSON list | 60s |
| `lb:user:<uid>:server:<sid>` | balance JSON | 30s |
| `xp:rate:user:<uid>:server:<sid>:bucket` | int | 60s rolling |

## 6. Search Index

Not used.

## 7. Vector Index

Not used.

## 8. Object Storage

Not used.

## 9. Data Retention

- Ledger 365 days then archived to R2
- Balances permanent
- Badges permanent

## 10. Sample Queries

```sql
-- Top 50 over 30 days
SELECT u.id, u.handle, b.xp_30d, b.level, b.rank_30d
FROM xp_balances b
JOIN users u ON u.id = b.user_id
WHERE b.server_id = $1
ORDER BY b.xp_30d DESC
LIMIT 50;

-- My rank
SELECT * FROM xp_balances WHERE server_id = $1 AND user_id = $2;

-- Recompute window using ledger
SELECT user_id, sum(amount)::bigint AS xp
FROM xp_ledger
WHERE server_id = $1 AND occurred_at > now() - interval '30 days'
GROUP BY user_id;
```
