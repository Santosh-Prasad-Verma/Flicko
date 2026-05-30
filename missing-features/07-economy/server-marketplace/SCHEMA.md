# SCHEMA - Server Marketplace

## Migration 175: listings, bids, purchases

```sql
-- 175_marketplace_listings.up.sql

CREATE TYPE listing_status   AS ENUM ('draft','live','paused','ended','removed');
CREATE TYPE listing_kind     AS ENUM ('fixed','auction');
CREATE TYPE purchase_status  AS ENUM ('pending','succeeded','failed','refunded','disputed');

CREATE TABLE listings (
  id              ulid PRIMARY KEY DEFAULT gen_ulid(),
  server_id       ulid NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  creator_id      ulid NOT NULL REFERENCES users(id),
  title           text NOT NULL CHECK (char_length(title) BETWEEN 3 AND 80),
  description     text NOT NULL CHECK (char_length(description) <= 4000),
  media           jsonb NOT NULL DEFAULT '[]'::jsonb,
  category        text NOT NULL,
  kind            listing_kind NOT NULL DEFAULT 'fixed',
  price_cents     bigint CHECK (price_cents IS NULL OR price_cents >= 50),
  currency        char(3) NOT NULL DEFAULT 'USD',
  stock           integer,                       -- NULL = unlimited
  refund_window_h smallint NOT NULL DEFAULT 72,
  server_cut_bps  smallint NOT NULL DEFAULT 1500 CHECK (server_cut_bps BETWEEN 0 AND 3000),
  status          listing_status NOT NULL DEFAULT 'draft',
  version         integer NOT NULL DEFAULT 1,
  starts_at       timestamptz,
  ends_at         timestamptz,
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX listings_server_status_idx ON listings(server_id, status, created_at DESC);
CREATE INDEX listings_creator_idx       ON listings(creator_id, status);
CREATE INDEX listings_ends_at_idx       ON listings(ends_at) WHERE kind='auction' AND status='live';

CREATE TABLE bids (
  id           ulid PRIMARY KEY DEFAULT gen_ulid(),
  listing_id   ulid NOT NULL REFERENCES listings(id) ON DELETE CASCADE,
  bidder_id    ulid NOT NULL REFERENCES users(id),
  amount_cents bigint NOT NULL CHECK (amount_cents > 0),
  hold_intent  text,                            -- Stripe PI id holding funds
  created_at   timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX bids_listing_amount_idx ON bids(listing_id, amount_cents DESC);
CREATE UNIQUE INDEX bids_idem_idx     ON bids(listing_id, bidder_id, amount_cents);

CREATE TABLE payment_intents (
  id              ulid PRIMARY KEY DEFAULT gen_ulid(),
  stripe_pi_id    text UNIQUE NOT NULL,
  buyer_id        ulid NOT NULL REFERENCES users(id),
  listing_id      ulid NOT NULL REFERENCES listings(id),
  listing_version integer NOT NULL,
  amount_cents    bigint NOT NULL,
  currency        char(3) NOT NULL,
  app_fee_cents   bigint NOT NULL,
  server_cut_cents bigint NOT NULL,
  status          text NOT NULL,
  idempotency_key text NOT NULL,
  body_hash       bytea NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  finalized_at    timestamptz
);
CREATE UNIQUE INDEX pi_idem_idx ON payment_intents(buyer_id, idempotency_key);

CREATE TABLE purchases (
  id              ulid PRIMARY KEY DEFAULT gen_ulid(),
  payment_intent  ulid NOT NULL UNIQUE REFERENCES payment_intents(id),
  listing_id      ulid NOT NULL REFERENCES listings(id),
  buyer_id        ulid NOT NULL REFERENCES users(id),
  status          purchase_status NOT NULL DEFAULT 'pending',
  fulfilled_at    timestamptz,
  refund_id       text,
  dispute_id      text,
  created_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX purchases_buyer_idx    ON purchases(buyer_id, created_at DESC);
CREATE INDEX purchases_listing_idx  ON purchases(listing_id);

CREATE TABLE stripe_events (
  event_id     text PRIMARY KEY,
  type         text NOT NULL,
  payload      jsonb NOT NULL,
  received_at  timestamptz NOT NULL DEFAULT now(),
  processed_at timestamptz
);

-- ledger lives in shared schema, see 07-economy/server-economy
```

## Row Level Security
```sql
ALTER TABLE listings        ENABLE ROW LEVEL SECURITY;
ALTER TABLE bids            ENABLE ROW LEVEL SECURITY;
ALTER TABLE payment_intents ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchases       ENABLE ROW LEVEL SECURITY;

CREATE POLICY listings_read ON listings FOR SELECT
  USING (status='live' AND server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid()));

CREATE POLICY listings_write ON listings FOR ALL
  USING (creator_id = auth.uid() OR EXISTS (
    SELECT 1 FROM server_roles sr WHERE sr.server_id=listings.server_id AND sr.user_id=auth.uid() AND sr.role IN ('owner','admin')
  ));

CREATE POLICY purchases_read ON purchases FOR SELECT
  USING (buyer_id = auth.uid() OR EXISTS (
    SELECT 1 FROM listings l JOIN server_roles sr ON sr.server_id=l.server_id
    WHERE l.id=purchases.listing_id AND sr.user_id=auth.uid() AND sr.role IN ('owner','admin')));
```

## Idempotency Keys
- `payment_intents (buyer_id, idempotency_key)` UNIQUE - replay guard.
- `stripe_events.event_id` PK - webhook replay guard.
- `bids (listing_id, bidder_id, amount_cents)` UNIQUE - prevents accidental duplicate bid.

## Ledger Entries (shared `ledger_entries` table from server-economy)
For each succeeded purchase, four immutable rows are written in one tx:
1. DR `user:{buyer}.cash`     CR `platform:clearing`     amount=gross
2. DR `platform:clearing`     CR `user:{seller}.payable` amount=gross-app_fee-server_cut
3. DR `platform:clearing`     CR `platform:revenue`      amount=app_fee
4. DR `platform:clearing`     CR `server:{srv}.payable`  amount=server_cut

All entries share `tx_group_id = purchase.id` and `prev_hash = sha256(prev_row_hash || row_canonical)` forming a chain.
