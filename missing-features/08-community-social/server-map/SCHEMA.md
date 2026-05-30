# Server Map — Backend Schema

## 1. Tables

### `member_locations`

```sql
CREATE TABLE member_locations (
  user_id          UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  server_id        UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  precision        SMALLINT NOT NULL DEFAULT 5 CHECK (precision IN (2,4,5)),  -- 2=country, 4=region, 5=city
  geohash          TEXT NOT NULL CHECK (length(geohash) BETWEEN 2 AND 5),
  country_code     CHAR(2),
  region_code      TEXT,
  display_label    TEXT CHECK (length(display_label) <= 80),
  consent_text_id  TEXT NOT NULL,                -- which privacy text version was accepted
  consent_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  expires_at       TIMESTAMPTZ NOT NULL DEFAULT (now() + interval '180 days'),
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, server_id)
);

CREATE INDEX idx_member_locations_server_geo ON member_locations(server_id, geohash);
CREATE INDEX idx_member_locations_expires    ON member_locations(expires_at);
```

### `member_location_clusters` (materialized)

Aggregates with k-anonymity floor of 5.

```sql
CREATE MATERIALIZED VIEW member_location_clusters AS
SELECT
  server_id,
  precision,
  geohash,
  count(*) AS member_count,
  any_value(country_code) AS country_code,
  any_value(display_label) AS display_label,
  bool_or(true) AS visible
FROM member_locations
GROUP BY server_id, precision, geohash
HAVING count(*) >= 5;

CREATE UNIQUE INDEX idx_mlc_server_geo ON member_location_clusters(server_id, geohash);
```

### `member_location_settings`

Per-user defaults plus per-server overrides.

```sql
CREATE TABLE member_location_settings (
  user_id              UUID PRIMARY KEY REFERENCES users(id) ON DELETE CASCADE,
  default_precision    SMALLINT NOT NULL DEFAULT 4,
  share_with_followers BOOLEAN NOT NULL DEFAULT false,
  age_gate_locked      BOOLEAN NOT NULL DEFAULT false,    -- true for under-18
  updated_at           TIMESTAMPTZ NOT NULL DEFAULT now()
);
```

## 2. RLS Policies

```sql
ALTER TABLE member_locations         ENABLE ROW LEVEL SECURITY;
ALTER TABLE member_location_settings ENABLE ROW LEVEL SECURITY;

-- A user can only read/write their own raw location row
CREATE POLICY "Self own location"
  ON member_locations FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Other server members can read CLUSTERS only via the materialized view; raw rows are never directly readable
-- (no policy enabling other reads)

-- Age gate enforced at insert
CREATE POLICY "Age gate precision"
  ON member_locations FOR INSERT
  WITH CHECK (
    NOT EXISTS (
      SELECT 1 FROM member_location_settings
      WHERE user_id = auth.uid() AND age_gate_locked = true AND member_locations.precision > 2
    )
  );

CREATE POLICY "Self settings"
  ON member_location_settings FOR ALL
  USING (user_id = auth.uid());

-- Cluster view exposed via security-definer function with k-anonymity already applied
ALTER MATERIALIZED VIEW member_location_clusters OWNER TO authenticated;
```

A security-definer function `get_server_clusters(server_id)` checks server membership, then returns clusters from the materialized view, never raw rows.

## 3. Triggers

```sql
CREATE TRIGGER member_locations_set_updated_at
  BEFORE UPDATE ON member_locations
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Auto-coarsen for under-18
CREATE OR REPLACE FUNCTION member_locations_age_coarsen() RETURNS TRIGGER AS $$
BEGIN
  IF EXISTS (SELECT 1 FROM users WHERE id = NEW.user_id AND date_of_birth > now() - interval '18 years') THEN
    NEW.precision := 2;
    NEW.geohash := substring(NEW.geohash from 1 for 2);
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER member_locations_coarsen
  BEFORE INSERT OR UPDATE ON member_locations
  FOR EACH ROW EXECUTE FUNCTION member_locations_age_coarsen();
```

## 4. Migration File

Path: `supabase/migrations/196_server_map.up.sql`

```sql
-- up
BEGIN;
  CREATE TABLE member_locations (...);
  CREATE TABLE member_location_settings (...);
  CREATE MATERIALIZED VIEW member_location_clusters AS ...;
  -- triggers, RLS, grants
  CREATE FUNCTION get_server_clusters(p_server UUID) ...;
COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `map:clusters:<server_id>:p<n>` | JSON | 5m |
| `map:user:<u>:server:<s>` | settings | 5m |

## 6. Search Index

Not used.

## 7. Vector Index

Not used.

## 8. Object Storage

Not used. Map tiles served via MapLibre using free OpenStreetMap tile provider (with attribution).

## 9. Data Retention

- Locations expire after 180 days unless refreshed by user
- Revocation deletes within 24h via worker
- Materialized cluster view rebuilt every 30 minutes
- GDPR delete: cascade

## 10. Sample Queries

```sql
-- Cluster fetch via security definer function
SELECT * FROM get_server_clusters($1);

-- Sweeping expired
DELETE FROM member_locations WHERE expires_at < now();

-- Density check before reveal
SELECT count(*) FROM member_locations
WHERE server_id = $1 AND geohash = $2;
-- if < 5, coarsen geohash by 1 character
```
