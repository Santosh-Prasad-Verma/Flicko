# Email Digest — Backend Schema

## 1. Tables

### `digest_subscriptions`

```sql
CREATE TABLE digest_subscriptions (
  user_id          UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  cadence          TEXT NOT NULL DEFAULT 'off' CHECK (cadence IN ('off','daily','weekly')),
  day_of_week      SMALLINT CHECK (day_of_week BETWEEN 0 AND 6),       -- 0=Sun
  hour_of_day      SMALLINT CHECK (hour_of_day BETWEEN 0 AND 23),
  tz               TEXT NOT NULL DEFAULT 'UTC',
  server_allowlist UUID[] NOT NULL DEFAULT '{}',                       -- empty = all unmuted
  last_sent_at     TIMESTAMPTZ,
  next_send_at     TIMESTAMPTZ,
  state            TEXT NOT NULL DEFAULT 'active'
                    CHECK (state IN ('active','paused','suppressed')),
  bounce_count     INT NOT NULL DEFAULT 0,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_digest_subs_due
  ON digest_subscriptions(next_send_at)
  WHERE cadence <> 'off' AND state = 'active';
```

### `digest_runs`

```sql
CREATE TABLE digest_runs (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  planned_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  sent_at       TIMESTAMPTZ,
  result        TEXT NOT NULL CHECK (result IN ('planned','sent','skipped_empty','failed','suppressed')),
  resend_msg_id TEXT,
  bytes_sent    INT,
  open_count    INT NOT NULL DEFAULT 0,
  click_count   INT NOT NULL DEFAULT 0,
  failure_reason TEXT
);

CREATE INDEX idx_digest_runs_user_time ON digest_runs(user_id, planned_at DESC);
CREATE INDEX idx_digest_runs_state     ON digest_runs(result);
```

### `digest_unsubscribe_tokens`

```sql
CREATE TABLE digest_unsubscribe_tokens (
  jti        UUID PRIMARY KEY,
  user_id    UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  expires_at TIMESTAMPTZ NOT NULL,
  used_at    TIMESTAMPTZ
);

CREATE INDEX idx_digest_unsub_user ON digest_unsubscribe_tokens(user_id);
```

### `digest_email_events`

```sql
CREATE TABLE digest_email_events (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  resend_msg_id TEXT,
  kind          TEXT NOT NULL CHECK (kind IN ('open','click','bounce','complaint','delivered','dropped')),
  detail        JSONB,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_digest_events_user_kind ON digest_email_events(user_id, kind, created_at DESC);
```

## 2. RLS Policies

```sql
ALTER TABLE digest_subscriptions ENABLE ROW LEVEL SECURITY;
ALTER TABLE digest_runs          ENABLE ROW LEVEL SECURITY;

CREATE POLICY digest_self ON digest_subscriptions FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

CREATE POLICY digest_runs_self ON digest_runs FOR SELECT
  USING (user_id = auth.uid());
```

## 3. Triggers

```sql
CREATE TRIGGER digest_subs_set_updated_at
  BEFORE UPDATE ON digest_subscriptions
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Recompute next_send_at on cadence change.
CREATE OR REPLACE FUNCTION digest_recompute_next() RETURNS TRIGGER AS $$
BEGIN
  IF NEW.cadence = 'off' THEN
    NEW.next_send_at := NULL;
  ELSE
    -- naive: next minute past hour pref; service computes precise tz-aware
    NEW.next_send_at := COALESCE(NEW.next_send_at, now() + interval '1 hour');
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

CREATE TRIGGER digest_subs_recompute
  BEFORE INSERT OR UPDATE OF cadence, day_of_week, hour_of_day, tz ON digest_subscriptions
  FOR EACH ROW EXECUTE FUNCTION digest_recompute_next();
```

## 4. Migration File

Path: `supabase/migrations/167_email_digest.up.sql`

```sql
BEGIN;
-- create tables, indexes, RLS, triggers
SELECT cron.schedule('digest_planner_tick','*/5 * * * *',
  'SELECT plan_digests();');
GRANT SELECT, INSERT, UPDATE, DELETE ON digest_subscriptions      TO authenticated;
GRANT SELECT                          ON digest_runs              TO authenticated;
COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `digest:user:<uid>:rank:<window>` | ranked JSON | 30m |
| `digest:resend:rate` | rolling counter | 60s |

## 6. Search Index

Not searchable.

## 7. Object Storage

None.

## 8. Data Retention

- Runs: 90 days
- Email events: 180 days
- Suppressed subs: keep but never send

## 9. Sample Queries

```sql
-- Plan due users
SELECT user_id, server_allowlist, tz
FROM digest_subscriptions
WHERE cadence <> 'off' AND state = 'active'
  AND next_send_at <= now() + interval '5 minutes'
ORDER BY next_send_at
LIMIT 1000
FOR UPDATE SKIP LOCKED;

-- Latest run for a user
SELECT * FROM digest_runs
WHERE user_id = $1
ORDER BY planned_at DESC
LIMIT 1;
```
