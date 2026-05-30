# Server Economy — Backend Schema

Migration: `supabase/migrations/175_server_economy.up.sql`.
All money handled as `BIGINT` minor-units (no decimals, no float). Reconciliation invariant: for every wallet, `balance = SUM(amount) of wallet_entries`.

## 1. Tables

### `currency_config`

```sql
CREATE TABLE currency_config (
  server_id        UUID PRIMARY KEY REFERENCES servers(id) ON DELETE CASCADE,
  name             TEXT        NOT NULL CHECK (length(name) BETWEEN 1 AND 20),
  icon_url         TEXT,
  starting_balance BIGINT      NOT NULL DEFAULT 0 CHECK (starting_balance >= 0),
  decimals         SMALLINT    NOT NULL DEFAULT 0 CHECK (decimals BETWEEN 0 AND 4),
  tz               TEXT        NOT NULL DEFAULT 'UTC',
  daily_base       BIGINT      NOT NULL DEFAULT 10  CHECK (daily_base >= 0),
  daily_max_streak SMALLINT    NOT NULL DEFAULT 7,
  earn_msg_rate    BIGINT      NOT NULL DEFAULT 1,   -- per qualified message
  earn_msg_cap     BIGINT      NOT NULL DEFAULT 50,  -- per day
  earn_voice_rate  BIGINT      NOT NULL DEFAULT 2,   -- per minute
  earn_voice_cap   BIGINT      NOT NULL DEFAULT 120,
  velocity_window  INTERVAL    NOT NULL DEFAULT '1 hour',
  velocity_cap     BIGINT      NOT NULL DEFAULT 500,
  enabled          BOOLEAN     NOT NULL DEFAULT TRUE,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

### `wallets`

```sql
CREATE TABLE wallets (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id   UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES users(id)   ON DELETE CASCADE,
  balance     BIGINT NOT NULL DEFAULT 0 CHECK (balance >= 0),
  frozen      BOOLEAN NOT NULL DEFAULT FALSE,
  freeze_reason TEXT,
  version     BIGINT  NOT NULL DEFAULT 0,            -- optimistic-lock counter
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (server_id, user_id)
);
CREATE INDEX idx_wallets_server_balance ON wallets(server_id, balance DESC) WHERE NOT frozen;
```

### `wallet_entries` (immutable, double-entry)

```sql
CREATE TABLE wallet_entries (
  id              BIGSERIAL PRIMARY KEY,        -- monotonic for ordering
  entry_ulid      TEXT NOT NULL UNIQUE,         -- 26-char ULID for client cursor
  wallet_id       UUID NOT NULL REFERENCES wallets(id) ON DELETE RESTRICT,
  transaction_id  UUID NOT NULL,
  direction       SMALLINT NOT NULL CHECK (direction IN (1, -1)),  -- +1 credit, -1 debit
  amount          BIGINT  NOT NULL CHECK (amount > 0),              -- always positive; sign in direction
  signed_amount   BIGINT  GENERATED ALWAYS AS (direction * amount) STORED,
  source          TEXT    NOT NULL,             -- 'msg','voice','daily','grant','marketplace_buy',...
  ref_id          TEXT,                         -- external ref (message_id, listing_id...)
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_entries_wallet_created ON wallet_entries(wallet_id, created_at DESC);
CREATE INDEX idx_entries_txn ON wallet_entries(transaction_id);
-- Append-only enforcement
CREATE RULE no_update_entries AS ON UPDATE TO wallet_entries DO INSTEAD NOTHING;
CREATE RULE no_delete_entries AS ON DELETE TO wallet_entries DO INSTEAD NOTHING;
```

### `transactions`

```sql
CREATE TABLE transactions (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id       UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  kind            TEXT NOT NULL,           -- 'earn','spend','transfer','grant','revoke','reversal'
  initiator_id    UUID,                    -- user/mod who triggered (NULL for system)
  idempotency_key TEXT NOT NULL,
  status          TEXT NOT NULL DEFAULT 'committed', -- 'committed','reversed'
  reversed_by     UUID REFERENCES transactions(id),
  meta            JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (server_id, idempotency_key)
);
CREATE INDEX idx_txn_server_created ON transactions(server_id, created_at DESC);
```

### `daily_claims`

```sql
CREATE TABLE daily_claims (
  wallet_id     UUID PRIMARY KEY REFERENCES wallets(id) ON DELETE CASCADE,
  last_claim_at TIMESTAMPTZ,
  streak_days   SMALLINT NOT NULL DEFAULT 0,
  total_claimed BIGINT   NOT NULL DEFAULT 0,
  next_eligible TIMESTAMPTZ
);
```

### `velocity_buckets` (DB mirror of Redis, used for reconciliation only)

```sql
CREATE TABLE velocity_buckets (
  wallet_id  UUID NOT NULL REFERENCES wallets(id) ON DELETE CASCADE,
  source     TEXT NOT NULL,
  bucket_at  TIMESTAMPTZ NOT NULL,
  amount     BIGINT NOT NULL DEFAULT 0,
  PRIMARY KEY (wallet_id, source, bucket_at)
);
```

## 2. RLS Policies

```sql
ALTER TABLE wallets         ENABLE ROW LEVEL SECURITY;
ALTER TABLE wallet_entries  ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions    ENABLE ROW LEVEL SECURITY;
ALTER TABLE currency_config ENABLE ROW LEVEL SECURITY;
ALTER TABLE daily_claims    ENABLE ROW LEVEL SECURITY;

CREATE POLICY "members read currency"
  ON currency_config FOR SELECT
  USING (server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid()));

CREATE POLICY "owner write currency"
  ON currency_config FOR ALL
  USING (server_id IN (
    SELECT s.id FROM servers s WHERE s.owner_id = auth.uid()
  ));

CREATE POLICY "self read wallet"
  ON wallets FOR SELECT
  USING (
    user_id = auth.uid()
    OR EXISTS (
      SELECT 1 FROM server_members sm
      WHERE sm.server_id = wallets.server_id
        AND sm.user_id = auth.uid()
        AND has_server_permission(sm.server_id, sm.user_id, 'MANAGE_ECONOMY')
    )
  );

-- Wallet writes are blocked from clients; only service role.
CREATE POLICY "no client wallet writes"
  ON wallets FOR INSERT WITH CHECK (false);
CREATE POLICY "no client wallet updates"
  ON wallets FOR UPDATE USING (false);

CREATE POLICY "self read entries"
  ON wallet_entries FOR SELECT
  USING (
    wallet_id IN (SELECT id FROM wallets WHERE user_id = auth.uid())
  );

-- entries are append-only; rules above already block UPDATE/DELETE
CREATE POLICY "no client entries write"
  ON wallet_entries FOR INSERT WITH CHECK (false);
```

## 3. Triggers

```sql
CREATE TRIGGER currency_set_updated_at
  BEFORE UPDATE ON currency_config
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER wallet_set_updated_at
  BEFORE UPDATE ON wallets
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Forbid balance from going negative even if app forgot CHECK
CREATE OR REPLACE FUNCTION assert_balance_nonneg()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
  IF NEW.balance < 0 THEN
    RAISE EXCEPTION 'wallet balance would go negative (wallet=%, attempted=%)', NEW.id, NEW.balance;
  END IF;
  RETURN NEW;
END $$;
CREATE TRIGGER wallet_assert_nonneg BEFORE UPDATE ON wallets
  FOR EACH ROW EXECUTE FUNCTION assert_balance_nonneg();

-- Auto-provision wallet on server join
CREATE OR REPLACE FUNCTION provision_wallet()
RETURNS TRIGGER LANGUAGE plpgsql AS $$
DECLARE start_bal BIGINT;
BEGIN
  SELECT starting_balance INTO start_bal FROM currency_config WHERE server_id = NEW.server_id;
  IF start_bal IS NULL THEN start_bal := 0; END IF;
  INSERT INTO wallets(server_id, user_id, balance)
    VALUES (NEW.server_id, NEW.user_id, start_bal)
    ON CONFLICT DO NOTHING;
  RETURN NEW;
END $$;
CREATE TRIGGER member_join_provision_wallet
  AFTER INSERT ON server_members
  FOR EACH ROW EXECUTE FUNCTION provision_wallet();
```

## 4. Migration File

```sql
-- 175_server_economy.up.sql
BEGIN;
-- (table DDL above)
-- (RLS above)
-- (triggers above)

GRANT SELECT ON currency_config, wallets, wallet_entries, transactions, daily_claims TO authenticated;
GRANT USAGE ON SEQUENCE wallet_entries_id_seq TO service_role;

COMMIT;
```

`175_server_economy.down.sql`:

```sql
BEGIN;
DROP TRIGGER IF EXISTS member_join_provision_wallet ON server_members;
DROP FUNCTION IF EXISTS provision_wallet;
DROP FUNCTION IF EXISTS assert_balance_nonneg;
DROP TABLE IF EXISTS velocity_buckets;
DROP TABLE IF EXISTS daily_claims;
DROP TABLE IF EXISTS wallet_entries;
DROP TABLE IF EXISTS wallets;
DROP TABLE IF EXISTS transactions;
DROP TABLE IF EXISTS currency_config;
COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `econ:wallet:<wallet_id>` | JSON | 30s |
| `econ:cur:<server_id>` | JSON config | 5m |
| `econ:lb:<server_id>:weekly` | ZSET user_id->balance_delta | 5m |
| `econ:velocity:msg:<wallet_id>:<unix_hour>` | INT counter | 1h aligned |
| `econ:idem:<key>` | txn id | 24h |

## 6. Search Index

None. Leaderboards served from Postgres + Redis.

## 7. Vector Index

N/A.

## 8. Object Storage (Appwrite)

- Bucket: `currency-icons`
- MIME: `image/png`, `image/svg+xml`, `image/webp`
- Max size: 64 KB
- Permission: `read("any")`, `write("server_admin:{serverId}")`

## 9. Data Retention

- Wallets: forever while user+server exist.
- Entries: 5y in primary; partition by month after `wallet_entries` exceeds 100M rows; archived partitions dumped to R2.
- GDPR delete: anonymize `user_id` in `wallets` + `transactions` (set to a tombstone UUID), keep entries for ledger integrity.

## 10. Sample Queries

```sql
-- Recompute balance (reconciliation)
SELECT wallet_id, SUM(signed_amount) AS computed
FROM wallet_entries GROUP BY wallet_id;

-- Top 50 weekly earners
SELECT user_id, SUM(signed_amount) AS delta
FROM wallet_entries we
JOIN wallets w ON w.id = we.wallet_id
WHERE w.server_id = $1
  AND we.created_at >= now() - interval '7 days'
  AND we.direction = 1
GROUP BY user_id
ORDER BY delta DESC
LIMIT 50;

-- Daily claim eligibility
SELECT next_eligible <= now() AS eligible, streak_days
FROM daily_claims WHERE wallet_id = $1;
```
