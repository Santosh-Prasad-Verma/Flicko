# SCHEMA: Plugin System

Migrations: `240_plugins.sql`.

## plugins
```sql
CREATE TABLE plugins (
  id              text PRIMARY KEY,                    -- reverse-DNS, e.g. com.acme.welcomer
  publisher_id    uuid NOT NULL REFERENCES users(id),
  display_name    text NOT NULL,
  summary         text NOT NULL CHECK (length(summary) <= 140),
  description_md  text NOT NULL,
  icon_url        text,
  homepage_url    text,
  repo_url        text,
  category        text NOT NULL,
  status          text NOT NULL DEFAULT 'draft'
                    CHECK (status IN ('draft','review','published','suspended')),
  signing_pubkey  bytea NOT NULL,                      -- Ed25519 32 bytes
  created_at      timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX plugins_publisher_idx ON plugins(publisher_id);
CREATE INDEX plugins_status_idx ON plugins(status) WHERE status = 'published';
```

## plugin_versions
```sql
CREATE TABLE plugin_versions (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  plugin_id       text NOT NULL REFERENCES plugins(id) ON DELETE CASCADE,
  semver          text NOT NULL,
  channel         text NOT NULL DEFAULT 'stable'
                    CHECK (channel IN ('stable','beta','dev')),
  manifest_yaml   text NOT NULL,
  manifest_hash   bytea NOT NULL,
  wasm_sha256     bytea NOT NULL,
  wasm_size_bytes integer NOT NULL,
  signature       bytea NOT NULL,                     -- Ed25519 over manifest_hash || wasm_sha256
  scopes          text[] NOT NULL,
  resource_caps   jsonb NOT NULL,                     -- { mem_mb, fuel, wall_ms }
  disabled        boolean NOT NULL DEFAULT false,
  disabled_reason text,
  uploaded_at     timestamptz NOT NULL DEFAULT now(),
  UNIQUE (plugin_id, semver)
);
CREATE INDEX plugin_versions_channel_idx ON plugin_versions(plugin_id, channel, uploaded_at DESC);
```

## plugin_installs
```sql
CREATE TABLE plugin_installs (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id       uuid NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  plugin_id       text NOT NULL REFERENCES plugins(id),
  version_id      uuid NOT NULL REFERENCES plugin_versions(id),
  enabled         boolean NOT NULL DEFAULT true,
  state           text NOT NULL DEFAULT 'installing'
                    CHECK (state IN ('installing','active','degraded','disabled','failed')),
  config          jsonb NOT NULL DEFAULT '{}',
  channels        uuid[] NOT NULL DEFAULT '{}',       -- write-scope channel allowlist
  installed_by    uuid NOT NULL REFERENCES users(id),
  installed_at    timestamptz NOT NULL DEFAULT now(),
  updated_at      timestamptz NOT NULL DEFAULT now(),
  UNIQUE (server_id, plugin_id)
);
CREATE INDEX plugin_installs_server_idx ON plugin_installs(server_id) WHERE enabled;
CREATE INDEX plugin_installs_plugin_idx ON plugin_installs(plugin_id);

ALTER TABLE plugin_installs ENABLE ROW LEVEL SECURITY;
CREATE POLICY install_read ON plugin_installs FOR SELECT
  USING (server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid()));
CREATE POLICY install_write ON plugin_installs FOR ALL
  USING (EXISTS (SELECT 1 FROM server_members
                  WHERE server_id = plugin_installs.server_id
                    AND user_id = auth.uid()
                    AND role IN ('owner','admin')));
```

## plugin_capabilities
```sql
CREATE TABLE plugin_capabilities (
  id              bigserial PRIMARY KEY,
  install_id      uuid NOT NULL REFERENCES plugin_installs(id) ON DELETE CASCADE,
  scope           text NOT NULL,
  resource_ref    text,                                -- e.g. channel:abc, domain:api.acme.com
  invoked_at      timestamptz NOT NULL DEFAULT now(),
  hook            text NOT NULL,
  latency_ms      integer NOT NULL,
  fuel_used       bigint NOT NULL,
  result          text NOT NULL CHECK (result IN ('ok','error','timeout','rate_limited')),
  error_msg       text
) PARTITION BY RANGE (invoked_at);
CREATE INDEX cap_install_time_idx ON plugin_capabilities(install_id, invoked_at DESC);
-- monthly partitions created by cron
```

## RLS summary
- `plugins`: SELECT public for `status='published'`; ALL for owner.
- `plugin_versions`: SELECT public for non-disabled stable; ALL for plugin owner.
- `plugin_installs`: see above.
- `plugin_capabilities`: SELECT for server admins of `install_id.server_id`.

## Triggers
- `plugin_installs_updated_at`: bump on UPDATE.
- `plugin_versions_signature_check`: BEFORE INSERT verifies signature against `plugins.signing_pubkey`.
- `plugin_installs_state_audit`: AFTER UPDATE writes to `audit_log` when `state` changes.
