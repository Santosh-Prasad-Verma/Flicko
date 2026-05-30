# Stream Donations — Schema

## Tables

```sql
CREATE TABLE stream_donations (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  stream_id       UUID NOT NULL REFERENCES streams(id) ON DELETE CASCADE,
  donor_user_id   UUID REFERENCES users(id),
  donor_name      TEXT,
  amount_cents    INT NOT NULL CHECK (amount_cents >= 100),
  currency        CHAR(3) NOT NULL,
  message         TEXT,
  tts_voice       TEXT,
  stripe_pi_id    TEXT UNIQUE,
  status          TEXT NOT NULL DEFAULT 'pending'
                    CHECK (status IN ('pending','succeeded','failed','refunded','disputed')),
  flicko_fee_cents INT NOT NULL,
  net_cents       INT NOT NULL,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  settled_at      TIMESTAMPTZ
);
CREATE INDEX idx_donations_stream ON stream_donations(stream_id, created_at DESC);
CREATE INDEX idx_donations_donor  ON stream_donations(donor_user_id);

CREATE TABLE donation_alert_rules (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  min_cents   INT NOT NULL DEFAULT 100,
  layout      TEXT NOT NULL DEFAULT 'classic',
  sound_url   TEXT,
  tts_enabled BOOLEAN NOT NULL DEFAULT true,
  duration_ms INT NOT NULL DEFAULT 6000,
  variables   JSONB DEFAULT '{}',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE donation_payouts (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id     UUID NOT NULL REFERENCES users(id),
  total_cents INT NOT NULL,
  currency    CHAR(3) NOT NULL,
  stripe_transfer_id TEXT UNIQUE,
  period_start DATE NOT NULL,
  period_end   DATE NOT NULL,
  status       TEXT NOT NULL DEFAULT 'queued',
  created_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

## RLS
```sql
ALTER TABLE stream_donations ENABLE ROW LEVEL SECURITY;
CREATE POLICY donations_read_streamer ON stream_donations FOR SELECT
  USING (stream_id IN (SELECT id FROM streams WHERE owner_user_id = auth.uid()));
CREATE POLICY donations_read_self ON stream_donations FOR SELECT
  USING (donor_user_id = auth.uid());
-- Inserts: service role only via Stripe webhook.
```

## Stripe Webhook Idempotency
| Event | Handler |
|-------|---------|
| `payment_intent.succeeded` | mark donation succeeded; broadcast Centrifugo `stream-alerts:<stream>` |
| `payment_intent.payment_failed` | mark failed |
| `charge.refunded` | mark refunded; reverse ledger |
| `charge.dispute.created` | freeze, alert ops |

Idempotency key: stripe `event.id`, stored in `webhook_events` table.

## Cache
| Key | Value | TTL |
|-----|-------|-----|
| `donations:total:<stream>` | running total | live |
| `donations:goal:<stream>` | goal config | 1h |

## Migration: `supabase/migrations/233_stream_donations.up.sql`

## Fees
- Stripe: 2.9% + $0.30
- Flicko: 5% (configurable)
- Net = amount − stripe_fee − flicko_fee
- Min donation: $1.00 (avoid Stripe min-fee loss)
