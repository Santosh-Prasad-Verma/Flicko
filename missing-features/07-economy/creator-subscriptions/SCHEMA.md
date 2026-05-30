# SCHEMA - Creator Subscriptions

## Migration 176: subscription_plans, subscriptions

```sql
-- 176_creator_subscriptions.up.sql

CREATE TYPE plan_status         AS ENUM ('draft','active','archived');
CREATE TYPE subscription_status AS ENUM ('incomplete','trialing','active','past_due','canceled','ended');

CREATE TABLE subscription_plans (
  id                  ulid PRIMARY KEY DEFAULT gen_ulid(),
  creator_id          ulid NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  server_id           ulid REFERENCES servers(id),         -- optional, server-bound tier
  name                text NOT NULL CHECK (char_length(name) BETWEEN 2 AND 40),
  tagline             text CHECK (char_length(tagline) <= 120),
  monthly_cents       bigint NOT NULL CHECK (monthly_cents BETWEEN 100 AND 100000),
  yearly_cents        bigint CHECK (yearly_cents IS NULL OR yearly_cents > 0),
  trial_days          smallint NOT NULL DEFAULT 0 CHECK (trial_days BETWEEN 0 AND 30),
  perks               jsonb NOT NULL DEFAULT '[]'::jsonb,
  channel_grants      ulid[] NOT NULL DEFAULT '{}',
  role_grant          ulid,
  max_subscribers     integer,
  status              plan_status NOT NULL DEFAULT 'draft',
  stripe_product_id   text UNIQUE,
  stripe_price_m_id   text,
  stripe_price_y_id   text,
  app_fee_bps         smallint NOT NULL DEFAULT 500 CHECK (app_fee_bps BETWEEN 0 AND 2000),
  server_cut_bps      smallint NOT NULL DEFAULT 0  CHECK (server_cut_bps BETWEEN 0 AND 3000),
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX subscription_plans_creator_idx ON subscription_plans(creator_id, status);

CREATE TABLE subscriptions (
  id                  ulid PRIMARY KEY DEFAULT gen_ulid(),
  user_id             ulid NOT NULL REFERENCES users(id),
  plan_id             ulid NOT NULL REFERENCES subscription_plans(id),
  creator_id          ulid NOT NULL REFERENCES users(id),
  status              subscription_status NOT NULL,
  stripe_sub_id       text UNIQUE NOT NULL,
  stripe_customer_id  text NOT NULL,
  current_period_end  timestamptz NOT NULL,
  cancel_at_period_end boolean NOT NULL DEFAULT false,
  trial_end           timestamptz,
  cancellation_reason text,
  gift_from_user_id   ulid REFERENCES users(id),
  promo_code_id       ulid,
  created_at          timestamptz NOT NULL DEFAULT now(),
  updated_at          timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX subscriptions_user_idx        ON subscriptions(user_id, status);
CREATE INDEX subscriptions_creator_idx     ON subscriptions(creator_id, status);
CREATE INDEX subscriptions_period_end_idx  ON subscriptions(current_period_end) WHERE status IN ('active','trialing','past_due');
CREATE UNIQUE INDEX subscriptions_unique_active
  ON subscriptions(user_id, creator_id) WHERE status IN ('active','trialing','past_due');

CREATE TABLE invoices (
  id                ulid PRIMARY KEY DEFAULT gen_ulid(),
  subscription_id   ulid NOT NULL REFERENCES subscriptions(id),
  stripe_invoice_id text UNIQUE NOT NULL,
  amount_cents      bigint NOT NULL,
  app_fee_cents     bigint NOT NULL,
  server_cut_cents  bigint NOT NULL DEFAULT 0,
  status            text NOT NULL,
  paid_at           timestamptz,
  attempt_count     smallint NOT NULL DEFAULT 0,
  next_attempt_at   timestamptz,
  created_at        timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX invoices_subscription_idx ON invoices(subscription_id, created_at DESC);

CREATE TABLE promo_codes (
  id                ulid PRIMARY KEY DEFAULT gen_ulid(),
  creator_id        ulid NOT NULL REFERENCES users(id),
  code              text NOT NULL,
  pct_off           smallint CHECK (pct_off IS NULL OR pct_off BETWEEN 1 AND 100),
  amount_off_cents  bigint   CHECK (amount_off_cents IS NULL OR amount_off_cents > 0),
  max_redemptions   integer NOT NULL DEFAULT 100,
  redeemed          integer NOT NULL DEFAULT 0,
  starts_at         timestamptz,
  ends_at           timestamptz,
  active            boolean NOT NULL DEFAULT true,
  CHECK ((pct_off IS NOT NULL) <> (amount_off_cents IS NOT NULL))
);
CREATE UNIQUE INDEX promo_codes_creator_code_idx ON promo_codes(creator_id, lower(code));

CREATE TABLE gift_subscriptions (
  id                ulid PRIMARY KEY DEFAULT gen_ulid(),
  gifter_id         ulid NOT NULL REFERENCES users(id),
  recipient_id      ulid REFERENCES users(id),
  recipient_email   citext,
  plan_id           ulid NOT NULL REFERENCES subscription_plans(id),
  cycles            smallint NOT NULL DEFAULT 1 CHECK (cycles BETWEEN 1 AND 12),
  message           text,
  redeemed_at       timestamptz,
  created_at        timestamptz NOT NULL DEFAULT now(),
  CHECK (recipient_id IS NOT NULL OR recipient_email IS NOT NULL)
);
CREATE INDEX gifts_recipient_idx ON gift_subscriptions(recipient_id) WHERE redeemed_at IS NULL;
```

## Row Level Security
```sql
ALTER TABLE subscription_plans ENABLE ROW LEVEL SECURITY;
ALTER TABLE subscriptions      ENABLE ROW LEVEL SECURITY;
ALTER TABLE invoices           ENABLE ROW LEVEL SECURITY;

CREATE POLICY plans_read ON subscription_plans FOR SELECT
  USING (status='active' OR creator_id = auth.uid());
CREATE POLICY plans_write ON subscription_plans FOR ALL
  USING (creator_id = auth.uid());

CREATE POLICY subs_read ON subscriptions FOR SELECT
  USING (user_id = auth.uid() OR creator_id = auth.uid());

CREATE POLICY invoices_read ON invoices FOR SELECT
  USING (EXISTS (SELECT 1 FROM subscriptions s
                 WHERE s.id=invoices.subscription_id
                   AND (s.user_id=auth.uid() OR s.creator_id=auth.uid())));
```

## Idempotency Keys
- `subscriptions(user_id, creator_id) WHERE status IN active/trialing/past_due` UNIQUE - one active sub per user per creator.
- `invoices.stripe_invoice_id` UNIQUE - replay guard.
- `promo_codes(creator_id, lower(code))` UNIQUE.

## Ledger Entries
On every `invoice.paid` (subscription renewal), four immutable ledger rows in one transaction:
1. DR `user:{subscriber}.cash`     CR `platform:clearing`     amount=invoice_total
2. DR `platform:clearing`          CR `user:{creator}.payable` amount=invoice_total - app_fee - server_cut
3. DR `platform:clearing`          CR `platform:revenue`      amount=app_fee
4. DR `platform:clearing`          CR `server:{srv}.payable`  amount=server_cut (if server_id set)

`tx_group_id = invoice.id`. Refund reverses with mirrored CR/DR rows pointing back via `reverses_tx = invoice.id`.
