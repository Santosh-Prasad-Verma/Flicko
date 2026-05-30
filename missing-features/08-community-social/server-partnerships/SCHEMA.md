# Server Partnerships — Backend Schema

## 1. Tables

### `partnerships`

```sql
CREATE TABLE partnerships (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_a        UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  server_b        UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  status          TEXT NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending','active','declined','terminated','cooldown')),
  proposer_id     UUID NOT NULL REFERENCES users(id),
  message         TEXT CHECK (length(message) <= 1000),
  invite_a_for_b  TEXT,
  invite_b_for_a  TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  accepted_at     TIMESTAMPTZ,
  terminated_at   TIMESTAMPTZ,
  cooldown_until  TIMESTAMPTZ,
  CHECK (server_a < server_b),
  UNIQUE (server_a, server_b, status) DEFERRABLE INITIALLY DEFERRED
);

CREATE INDEX idx_partnerships_a_status ON partnerships(server_a, status);
CREATE INDEX idx_partnerships_b_status ON partnerships(server_b, status);
CREATE UNIQUE INDEX idx_partnerships_active_pair
  ON partnerships(server_a, server_b)
  WHERE status = 'active';
```

### `partnership_referrals`

Tracks attribution from a partner's slot.

```sql
CREATE TABLE partnership_referrals (
  id             UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  partnership_id UUID NOT NULL REFERENCES partnerships(id) ON DELETE CASCADE,
  from_server    UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  to_server      UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  user_id        UUID REFERENCES users(id) ON DELETE SET NULL,
  event          TEXT NOT NULL CHECK (event IN ('click','join','left_within_24h','retained_7d')),
  occurred_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_partnership_referrals_partnership ON partnership_referrals(partnership_id, occurred_at DESC);
CREATE INDEX idx_partnership_referrals_to_server   ON partnership_referrals(to_server, occurred_at DESC);
```

### `partnership_metrics` (materialized)

```sql
CREATE MATERIALIZED VIEW partnership_metrics AS
SELECT
  partnership_id,
  count(*) FILTER (WHERE event='click')          AS clicks,
  count(*) FILTER (WHERE event='join')           AS joins,
  count(*) FILTER (WHERE event='retained_7d')    AS retained_7d,
  max(occurred_at)                                AS last_event_at
FROM partnership_referrals
GROUP BY partnership_id;

CREATE UNIQUE INDEX idx_partnership_metrics_pid ON partnership_metrics(partnership_id);
```

## 2. RLS Policies

```sql
ALTER TABLE partnerships          ENABLE ROW LEVEL SECURITY;
ALTER TABLE partnership_referrals ENABLE ROW LEVEL SECURITY;

-- Public read of active partnerships when both servers are public
CREATE POLICY "Public read active"
  ON partnerships FOR SELECT
  USING (
    status = 'active'
    AND server_a IN (SELECT id FROM servers WHERE visibility='public')
    AND server_b IN (SELECT id FROM servers WHERE visibility='public')
  );

-- Managers of either server can read everything
CREATE POLICY "Managers read"
  ON partnerships FOR SELECT
  USING (
    (server_a IN (SELECT server_id FROM server_member_perms WHERE user_id = auth.uid() AND (perms & 1) = 1))
    OR
    (server_b IN (SELECT server_id FROM server_member_perms WHERE user_id = auth.uid() AND (perms & 1) = 1))
  );

CREATE POLICY "Managers write"
  ON partnerships FOR ALL
  USING (
    (server_a IN (SELECT server_id FROM server_member_perms WHERE user_id = auth.uid() AND (perms & 1) = 1))
    OR
    (server_b IN (SELECT server_id FROM server_member_perms WHERE user_id = auth.uid() AND (perms & 1) = 1))
  );

-- Referrals only readable by managers of either side
CREATE POLICY "Managers read referrals"
  ON partnership_referrals FOR SELECT
  USING (
    from_server IN (SELECT server_id FROM server_member_perms WHERE user_id = auth.uid() AND (perms & 1) = 1)
    OR to_server IN (SELECT server_id FROM server_member_perms WHERE user_id = auth.uid() AND (perms & 1) = 1)
  );
```

## 3. Triggers

```sql
CREATE OR REPLACE FUNCTION partnerships_normalize_pair() RETURNS TRIGGER AS $$
DECLARE a UUID; b UUID;
BEGIN
  IF NEW.server_a > NEW.server_b THEN
    a := NEW.server_b; b := NEW.server_a;
    NEW.server_a := a; NEW.server_b := b;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER partnerships_normalize
  BEFORE INSERT OR UPDATE ON partnerships
  FOR EACH ROW EXECUTE FUNCTION partnerships_normalize_pair();
```

## 4. Migration File

Path: `supabase/migrations/195_server_partnerships.up.sql`

```sql
-- up
BEGIN;
  CREATE TABLE partnerships (...);
  CREATE TABLE partnership_referrals (...);
  CREATE MATERIALIZED VIEW partnership_metrics AS ...;
  -- triggers, RLS, grants
COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `partner:server:<sid>:active` | JSON list | 60s |
| `partner:metrics:<pid>` | JSON | 5m |

## 6. Search Index

Not used.

## 7. Vector Index

Not used.

## 8. Object Storage

Not used.

## 9. Data Retention

- Active partnerships forever (until terminated)
- Terminated kept 365d for analytics
- Referrals 365d, then archived

## 10. Sample Queries

```sql
-- Active partners for a server
SELECT p.*,
       CASE WHEN p.server_a = $1 THEN p.server_b ELSE p.server_a END AS partner_id
FROM partnerships p
WHERE (p.server_a = $1 OR p.server_b = $1)
  AND p.status = 'active'
ORDER BY p.accepted_at DESC;

-- 7d join attribution
SELECT count(*) FROM partnership_referrals
WHERE partnership_id = $1 AND event = 'join'
  AND occurred_at > now() - interval '7 days';
```
