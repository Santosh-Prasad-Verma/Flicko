# Regional Content Filters — Backend Schema

## 1. Tables

### `region_rules`

Defines a rule. Each rule may apply to one or many regions via the join table.

```sql
CREATE TABLE region_rules (
  id            TEXT PRIMARY KEY,                  -- 'de.symbols.nazi'
  name          TEXT NOT NULL,                     -- human-readable
  description   TEXT,
  kind          TEXT NOT NULL CHECK (kind IN ('regex','hash','attribute','age_gate')),
  pattern       TEXT,                              -- for regex / hash list / json attribute query
  applies_to    TEXT[] NOT NULL,                   -- ['message_text', 'server_name', ...]
  action        TEXT NOT NULL DEFAULT 'hide' CHECK (action IN ('hide', 'block_send', 'age_gate', 'warn')),
  age_scope     TEXT,                              -- e.g. 'kr_19_plus' for age_gate kind
  legal_ref     TEXT,                              -- 'StGB §86a'
  enabled       BOOLEAN NOT NULL DEFAULT false,
  version       INT NOT NULL DEFAULT 1,
  created_by    UUID REFERENCES users(id),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  deleted_at    TIMESTAMPTZ
);

CREATE INDEX idx_region_rules_enabled ON region_rules(enabled) WHERE deleted_at IS NULL;
CREATE INDEX idx_region_rules_kind    ON region_rules(kind);
```

### `region_rule_assignments`

Many-to-many: which regions does each rule apply to.

```sql
CREATE TABLE region_rule_assignments (
  rule_id     TEXT NOT NULL REFERENCES region_rules(id) ON DELETE CASCADE,
  region_code TEXT NOT NULL,                       -- ISO-3166 alpha-2: 'DE', 'KR'
  PRIMARY KEY (rule_id, region_code)
);

CREATE INDEX idx_region_rule_assignments_region
  ON region_rule_assignments(region_code, rule_id);
```

### `region_filter_audit`

Every filter action recorded for compliance.

```sql
CREATE TABLE region_filter_audit (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID REFERENCES users(id) ON DELETE SET NULL,
  rule_id       TEXT NOT NULL REFERENCES region_rules(id),
  region_code   TEXT NOT NULL,
  item_kind     TEXT NOT NULL,                    -- 'message' | 'channel' | 'server' | 'bio' | 'push'
  item_id       UUID,                             -- nullable for ephemeral items (push)
  action        TEXT NOT NULL,                    -- 'hidden' | 'blocked_send' | 'age_gated'
  reason_excerpt TEXT,                            -- short hash/match snippet, no PII
  occurred_at   TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_region_filter_audit_user        ON region_filter_audit(user_id, occurred_at DESC);
CREATE INDEX idx_region_filter_audit_rule_region ON region_filter_audit(rule_id, region_code, occurred_at DESC);
```

### `profiles` (column adds)

Already has `region_code` from `multi-currency`. Add age-attestation flags:

```sql
ALTER TABLE profiles
  ADD COLUMN age_attestations JSONB NOT NULL DEFAULT '{}'::jsonb;
-- e.g. { "kr_19_plus": true, "uk_18_plus": false, "us_13_plus": true }
```

### `region_appeals`

Submitted by users when they think a hide was wrong.

```sql
CREATE TABLE region_appeals (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  audit_id      UUID NOT NULL REFERENCES region_filter_audit(id),
  reason_text   TEXT NOT NULL,
  status        TEXT NOT NULL DEFAULT 'open' CHECK (status IN ('open','reviewed','rejected','accepted')),
  reviewed_by   UUID REFERENCES users(id),
  reviewed_at   TIMESTAMPTZ,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_region_appeals_status ON region_appeals(status, created_at);
CREATE INDEX idx_region_appeals_user   ON region_appeals(user_id);
```

## 2. RLS Policies

```sql
ALTER TABLE region_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE region_rule_assignments ENABLE ROW LEVEL SECURITY;
ALTER TABLE region_filter_audit ENABLE ROW LEVEL SECURITY;
ALTER TABLE region_appeals ENABLE ROW LEVEL SECURITY;

-- region_rules: public can see enabled, non-deleted rules (transparency)
CREATE POLICY "Public reads enabled rules"
  ON region_rules FOR SELECT
  USING (enabled = true AND deleted_at IS NULL);

CREATE POLICY "Admins read all rules"
  ON region_rules FOR SELECT
  USING (auth.role() = 'service_role'
         OR EXISTS (SELECT 1 FROM admin_users WHERE user_id = auth.uid()));

CREATE POLICY "Admins write rules"
  ON region_rules FOR ALL
  USING (auth.role() = 'service_role'
         OR EXISTS (SELECT 1 FROM admin_users WHERE user_id = auth.uid()));

CREATE POLICY "Public reads rule assignments"
  ON region_rule_assignments FOR SELECT USING (true);
CREATE POLICY "Admins manage rule assignments"
  ON region_rule_assignments FOR ALL
  USING (auth.role() = 'service_role'
         OR EXISTS (SELECT 1 FROM admin_users WHERE user_id = auth.uid()));

-- audit: user reads own; admin/legal read all
CREATE POLICY "User reads own audit"
  ON region_filter_audit FOR SELECT
  USING (user_id = auth.uid());

CREATE POLICY "Admin reads all audit"
  ON region_filter_audit FOR SELECT
  USING (auth.role() = 'service_role'
         OR EXISTS (SELECT 1 FROM admin_users WHERE user_id = auth.uid()));

CREATE POLICY "Service role writes audit"
  ON region_filter_audit FOR INSERT
  WITH CHECK (auth.role() = 'service_role');

-- appeals: user reads/creates own; admin reviews
CREATE POLICY "User reads own appeals"
  ON region_appeals FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "User creates appeals"
  ON region_appeals FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "Admin reads all appeals"
  ON region_appeals FOR SELECT
  USING (EXISTS (SELECT 1 FROM admin_users WHERE user_id = auth.uid()));
CREATE POLICY "Admin reviews appeals"
  ON region_appeals FOR UPDATE
  USING (EXISTS (SELECT 1 FROM admin_users WHERE user_id = auth.uid()));
```

## 3. Triggers

```sql
CREATE TRIGGER region_rules_set_updated_at
  BEFORE UPDATE ON region_rules
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Cache bust on rule change
CREATE OR REPLACE FUNCTION region_rules_notify() RETURNS TRIGGER AS $$
BEGIN
  PERFORM pg_notify('region_rules_changed', COALESCE(NEW.id, OLD.id));
  RETURN COALESCE(NEW, OLD);
END; $$ LANGUAGE plpgsql;

CREATE TRIGGER region_rules_change_notify
  AFTER INSERT OR UPDATE OR DELETE ON region_rules
  FOR EACH ROW EXECUTE FUNCTION region_rules_notify();

CREATE TRIGGER region_rule_assignments_change_notify
  AFTER INSERT OR DELETE ON region_rule_assignments
  FOR EACH ROW EXECUTE FUNCTION region_rules_notify();
```

## 4. Migration File

Path: `supabase/migrations/262_regional_content_filters.up.sql`
Down: `supabase/migrations/262_regional_content_filters.down.sql`

```sql
-- up
BEGIN;

CREATE TABLE region_rules (...);
CREATE TABLE region_rule_assignments (...);
CREATE TABLE region_filter_audit (...);
CREATE TABLE region_appeals (...);

ALTER TABLE profiles ADD COLUMN age_attestations JSONB NOT NULL DEFAULT '{}'::jsonb;

CREATE FUNCTION region_rules_notify() ...;
CREATE TRIGGER region_rules_change_notify ...;
CREATE TRIGGER region_rule_assignments_change_notify ...;

-- seed canonical rules (legal-reviewed examples; pattern is illustrative)
INSERT INTO region_rules(id, name, description, kind, pattern, applies_to, action, legal_ref, enabled) VALUES
  ('de.symbols.nazi',
   'German banned symbols (§86a StGB)',
   'Hides Nazi-related symbols and slogans for German users.',
   'regex',
   '(?i)\b(hakenkreuz|swastika|sieg heil|heil hitler)\b',
   ARRAY['message_text','channel_name','server_name','bio'],
   'hide',
   'StGB §86a', false),
  ('kr.gambling.disclosure',
   'Korean loot-box odds disclosure',
   'Hides loot-box channels lacking odds disclosure attribute.',
   'attribute',
   '{"is_loot_box": true, "odds_disclosed": false}',
   ARRAY['channel_attributes'],
   'hide', 'Game Industry Promotion Act 2024', false),
  ('kr.under19.adult',
   'Korean under-19 adult-content gate',
   'Requires age attestation for adult-only servers.',
   'age_gate',
   NULL,
   ARRAY['server_attributes'],
   'age_gate', 'Youth Protection Act', false),
  ('uk.adult.age',
   'UK adult content age gate',
   'Requires 18+ attestation for adult content per Online Safety Act.',
   'age_gate',
   NULL,
   ARRAY['channel_attributes'],
   'age_gate', 'Online Safety Act 2024', false),
  ('us.coppa.13',
   'US COPPA under-13 gate',
   'Requires 13+ attestation for US users.',
   'age_gate',
   NULL,
   ARRAY['user_attributes'],
   'age_gate', 'COPPA', true),
  ('global.csam.zero_tolerance',
   'CSAM zero tolerance (global)',
   'Globally hides matched CSAM hashes and reports.',
   'hash',
   NULL,
   ARRAY['media'],
   'hide', 'Multiple jurisdictions', true);

INSERT INTO region_rule_assignments(rule_id, region_code) VALUES
  ('de.symbols.nazi','DE'),
  ('kr.gambling.disclosure','KR'),
  ('kr.under19.adult','KR'),
  ('uk.adult.age','GB'),
  ('us.coppa.13','US');
-- 'global.csam.zero_tolerance' applies to all regions; we handle by special-casing where region_code IS NULL or via a wildcard '*' assignment
INSERT INTO region_rule_assignments(rule_id, region_code)
SELECT 'global.csam.zero_tolerance', code FROM (VALUES ('US'),('GB'),('DE'),('FR'),('IT'),('ES'),('JP'),('KR'),('IN'),('BR'),('CA'),('AU')) AS r(code);

COMMIT;
```

```sql
-- down
BEGIN;
DROP TRIGGER IF EXISTS region_rule_assignments_change_notify ON region_rule_assignments;
DROP TRIGGER IF EXISTS region_rules_change_notify ON region_rules;
DROP FUNCTION IF EXISTS region_rules_notify();
DROP TABLE IF EXISTS region_appeals;
DROP TABLE IF EXISTS region_filter_audit;
DROP TABLE IF EXISTS region_rule_assignments;
DROP TABLE IF EXISTS region_rules;
ALTER TABLE profiles DROP COLUMN IF EXISTS age_attestations;
COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `region_rules:<region>` | JSON list | 5m |
| `region_rules:_global` | JSON list | 5m |
| `region:user:<user_id>` | region code | 1h |

## 6. Search Index

Not used.

## 7. Vector Index

Not used (yet — phase 2 ML classifier might use embeddings).

## 8. Object Storage

- Bucket `region-hash-lists` for media-hash files (private, read-by-service-role only).
- Files updated weekly from upstream partners.

## 9. Data Retention

- `region_filter_audit`: 365d hot for compliance evidence; archive monthly to R2 anonymized (drop user_id).
- `region_rules`: never drop; soft-delete via `deleted_at`.
- `region_appeals`: 730d (legal retention).
- GDPR cascade: delete user → audit rows redact user_id (keep aggregate count).

## 10. Sample Queries

```sql
-- All enabled rules for a region
SELECT r.*
FROM region_rules r
JOIN region_rule_assignments a ON a.rule_id = r.id
WHERE a.region_code = $1
  AND r.enabled = true
  AND r.deleted_at IS NULL
ORDER BY r.id;

-- Top fired rules in last 7 days
SELECT rule_id, region_code, COUNT(*) AS fires
FROM region_filter_audit
WHERE occurred_at > now() - INTERVAL '7 days'
GROUP BY rule_id, region_code
ORDER BY fires DESC
LIMIT 20;

-- Appeals pending review
SELECT id, user_id, audit_id, reason_text, created_at
FROM region_appeals
WHERE status = 'open'
ORDER BY created_at;

-- Per-region transparency report (anonymized counts)
SELECT region_code, item_kind, COUNT(*) AS hidden_count
FROM region_filter_audit
WHERE occurred_at >= date_trunc('quarter', now())
GROUP BY region_code, item_kind
ORDER BY region_code, hidden_count DESC;
```
