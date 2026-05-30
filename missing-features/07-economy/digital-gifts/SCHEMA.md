# SCHEMA - Digital Gifts

## Migration 177: gifts catalog and sends

```sql
-- 177_digital_gifts.up.sql

CREATE TYPE gift_surface AS ENUM ('chat','voice','stage','video','dm');

CREATE TABLE gift_catalog (
  id            ulid PRIMARY KEY DEFAULT gen_ulid(),
  slug          text UNIQUE NOT NULL,
  name          text NOT NULL,
  category      text NOT NULL,
  coin_cost     integer NOT NULL CHECK (coin_cost BETWEEN 1 AND 100000),
  surfaces      gift_surface[] NOT NULL DEFAULT '{chat,voice,stage,video,dm}',
  asset_url     text NOT NULL,
  asset_kind    text NOT NULL CHECK (asset_kind IN ('lottie','rive','sprite')),
  duration_ms   integer NOT NULL,
  active        boolean NOT NULL DEFAULT true,
  premium       boolean NOT NULL DEFAULT false,
  created_at    timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX gift_catalog_active_idx ON gift_catalog(active, category, coin_cost);

CREATE TABLE coin_balances (
  user_id       ulid PRIMARY KEY REFERENCES users(id),
  balance       bigint NOT NULL DEFAULT 0 CHECK (balance >= 0),
  lifetime_in   bigint NOT NULL DEFAULT 0,
  lifetime_out  bigint NOT NULL DEFAULT 0,
  updated_at    timestamptz NOT NULL DEFAULT now()
);

CREATE TABLE coin_topups (
  id              ulid PRIMARY KEY DEFAULT gen_ulid(),
  user_id         ulid NOT NULL REFERENCES users(id),
  pack_id         text NOT NULL,
  coins           integer NOT NULL CHECK (coins > 0),
  cents           bigint NOT NULL,
  bonus_coins     integer NOT NULL DEFAULT 0,
  source          text NOT NULL DEFAULT 'stripe' CHECK (source IN ('stripe','apple_iap','google_iap')),
  stripe_pi_id    text UNIQUE,
  status          text NOT NULL DEFAULT 'pending',
  idempotency_key text NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  credited_at     timestamptz
);
CREATE UNIQUE INDEX coin_topups_idem_idx ON coin_topups(user_id, idempotency_key);

CREATE TABLE sent_gifts (
  id            ulid PRIMARY KEY DEFAULT gen_ulid(),
  sender_id     ulid NOT NULL REFERENCES users(id),
  recipient_id  ulid NOT NULL REFERENCES users(id),
  gift_id       ulid NOT NULL REFERENCES gift_catalog(id),
  count         integer NOT NULL DEFAULT 1 CHECK (count BETWEEN 1 AND 99),
  coins_spent   bigint NOT NULL,
  surface       gift_surface NOT NULL,
  surface_id    ulid,
  server_id     ulid REFERENCES servers(id),
  idempotency_key text NOT NULL,
  created_at    timestamptz NOT NULL DEFAULT now(),
  CHECK (sender_id <> recipient_id)
);
CREATE UNIQUE INDEX sent_gifts_idem_idx ON sent_gifts(sender_id, idempotency_key);
CREATE INDEX sent_gifts_recipient_idx   ON sent_gifts(recipient_id, created_at DESC);
CREATE INDEX sent_gifts_surface_idx     ON sent_gifts(surface, surface_id, created_at DESC);
CREATE INDEX sent_gifts_server_idx      ON sent_gifts(server_id, created_at DESC) WHERE server_id IS NOT NULL;

-- Materialized view rebuilt every 60s for leaderboards
CREATE MATERIALIZED VIEW creator_gift_leaderboard_7d AS
  SELECT recipient_id AS creator_id, sender_id, sum(coins_spent) AS coins
    FROM sent_gifts
    WHERE created_at > now() - interval '7 days'
    GROUP BY recipient_id, sender_id;
CREATE UNIQUE INDEX creator_gift_lb_pk ON creator_gift_leaderboard_7d(creator_id, sender_id);
```

## Row Level Security
```sql
ALTER TABLE coin_balances ENABLE ROW LEVEL SECURITY;
ALTER TABLE coin_topups   ENABLE ROW LEVEL SECURITY;
ALTER TABLE sent_gifts    ENABLE ROW LEVEL SECURITY;

CREATE POLICY balance_owner ON coin_balances FOR SELECT USING (user_id = auth.uid());
CREATE POLICY topup_owner   ON coin_topups   FOR SELECT USING (user_id = auth.uid());
CREATE POLICY gift_party    ON sent_gifts    FOR SELECT
  USING (sender_id = auth.uid() OR recipient_id = auth.uid()
         OR (server_id IS NOT NULL AND auth.uid() IN
             (SELECT user_id FROM server_members WHERE server_id = sent_gifts.server_id)));
```

## Idempotency Keys
- `coin_topups(user_id, idempotency_key)` UNIQUE - prevents double-credit on retry.
- `sent_gifts(sender_id, idempotency_key)` UNIQUE - prevents double-spend on retry.
- `coin_topups.stripe_pi_id` UNIQUE - prevents duplicate webhook credit.

## Ledger Entries
On top-up `payment_intent.succeeded`:
1. DR `user:{u}.cash`         CR `platform:clearing`        amount=cents
2. DR `platform:clearing`     CR `platform:coin_liability`  amount=cents (deferred revenue, ASC 606)

On gift send (cents = coins_spent (1 coin = $0.01 fixed peg)):
1. DR `platform:coin_liability` CR `user:{creator}.coin_payable`        amount=cents - app_fee - server_cut
2. DR `platform:coin_liability` CR `platform:revenue`                   amount=app_fee
3. DR `platform:coin_liability` CR `server:{srv}.coin_payable`          amount=server_cut

`tx_group_id = sent_gifts.id`. Refund of unspent balance reverses #1 of top-up + decreases coin_balance.
