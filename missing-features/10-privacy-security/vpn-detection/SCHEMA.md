# VPN Detection — Backend Schema

## 1. Tables

### `auth_security_events`

```sql
CREATE TABLE auth_security_events (
  id            BIGSERIAL PRIMARY KEY,
  user_id       UUID REFERENCES users(id) ON DELETE SET NULL,
  event_type    TEXT NOT NULL CHECK (event_type IN ('signup', 'login', 'oauth_callback')),
  ip_hash       BYTEA NOT NULL,        -- sha256(salted_ip)
  ip_prefix     INET,                  -- /24 or /48 truncation for analytics
  country_code  TEXT,
  asn           INT,
  asn_org       TEXT,
  is_vpn        BOOLEAN,
  is_proxy      BOOLEAN,
  is_tor        BOOLEAN,
  is_hosting    BOOLEAN,
  detection_source TEXT,               -- 'vpnapi' | 'maxmind' | 'unavailable'
  user_agent    TEXT,
  occurred_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_auth_sec_user_time ON auth_security_events(user_id, occurred_at DESC);
CREATE INDEX idx_auth_sec_type_time ON auth_security_events(event_type, occurred_at DESC) WHERE is_vpn = TRUE;
```

### `vpn_detection_salt`

Used to rotate the IP-hash salt daily. Old salts retained 30d for forensics correlation.

```sql
CREATE TABLE vpn_detection_salt (
  effective_date DATE PRIMARY KEY,
  salt           BYTEA NOT NULL
);
```

## 2. RLS Policies

```sql
ALTER TABLE auth_security_events ENABLE ROW LEVEL SECURITY;

-- Self read: user can see their own login history
CREATE POLICY "self read"
  ON auth_security_events FOR SELECT
  USING (user_id = auth.uid());

-- T&S role read all
CREATE POLICY "t&s read all"
  ON auth_security_events FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM user_roles
      WHERE user_id = auth.uid() AND role IN ('trust_safety', 'admin')
    )
  );

-- Inserts only via service role
-- (no policy granted to authenticated; INSERT requires service-role connection)

-- Salt table not RLS-readable by anyone but the service role
ALTER TABLE vpn_detection_salt ENABLE ROW LEVEL SECURITY;
-- no policy → only service role
```

## 3. Triggers

None. Inserts come from the auth pipeline directly.

## 4. Migration File

Path: `supabase/migrations/219_vpn_detection.up.sql`

```sql
BEGIN;
CREATE TABLE auth_security_events (...);
CREATE TABLE vpn_detection_salt (...);

INSERT INTO vpn_detection_salt (effective_date, salt)
VALUES (CURRENT_DATE, gen_random_bytes(32));

ALTER TABLE auth_security_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE vpn_detection_salt   ENABLE ROW LEVEL SECURITY;
-- policies ...

GRANT SELECT ON auth_security_events TO authenticated;

COMMIT;
```

A daily cron job inserts a new salt:
```sql
SELECT cron.schedule(
  'rotate_vpn_salt',
  '0 0 * * *',
  $$ INSERT INTO vpn_detection_salt (effective_date, salt) VALUES (CURRENT_DATE, gen_random_bytes(32)) ON CONFLICT DO NOTHING; $$
);
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `vpn:ip:<sha256_hex>` | JSON `{is_vpn, asn, country, source}` | 24h |
| `vpn:provider_quota:vpnapi:<date>` | int counter | 24h |
| `vpn:provider_health:vpnapi` | up/down | 60s |

## 6. Search Index

Not applicable.

## 7. Vector Index

Not applicable.

## 8. Object Storage

Not applicable.

## 9. Data Retention

- `auth_security_events`: 180 days hot; archived to R2 cold storage thereafter, retained 2 years total per legal-hold policy.
- `vpn_detection_salt`: daily rotation; rows older than 30 days are deleted (cannot reconstruct hashes after that — by design).

## 10. Sample Queries

```sql
-- user's recent sessions
SELECT occurred_at, country_code, asn_org, is_vpn
FROM auth_security_events
WHERE user_id = $1
ORDER BY occurred_at DESC
LIMIT 20;

-- T&S dashboard tile: VPN signups last 24h
SELECT COUNT(*) FROM auth_security_events
WHERE event_type = 'signup'
  AND is_vpn = TRUE
  AND occurred_at > now() - interval '24 hours';

-- correlate by hashed IP
SELECT user_id, occurred_at FROM auth_security_events
WHERE ip_hash = $1
  AND occurred_at > now() - interval '7 days';
```
