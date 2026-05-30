# SCHEMA: Visual Webhook Builder

## Migration 247: Webhook Builder Foundation

### Table: `webhooks`
```sql
CREATE TABLE webhooks (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id     UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  name          TEXT NOT NULL,
  direction     TEXT NOT NULL CHECK (direction IN ('inbound', 'outbound')),
  template_id   UUID REFERENCES webhook_templates(id),
  template_version INTEGER,
  graph         JSONB NOT NULL,
  enabled       BOOLEAN NOT NULL DEFAULT true,
  created_by    UUID NOT NULL REFERENCES auth.users(id),
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX webhooks_server_idx ON webhooks(server_id) WHERE enabled = true;
CREATE INDEX webhooks_template_idx ON webhooks(template_id, template_version);
```

### Table: `webhook_templates`
```sql
CREATE TABLE webhook_templates (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  slug          TEXT NOT NULL,
  version       INTEGER NOT NULL,
  category      TEXT NOT NULL,
  name          TEXT NOT NULL,
  description   TEXT NOT NULL,
  icon          TEXT NOT NULL,
  direction     TEXT NOT NULL CHECK (direction IN ('inbound', 'outbound')),
  graph         JSONB NOT NULL,
  signature_scheme TEXT,
  published_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  deprecated_at TIMESTAMPTZ,
  UNIQUE(slug, version)
);
CREATE INDEX webhook_templates_slug_idx ON webhook_templates(slug, version DESC);
CREATE INDEX webhook_templates_category_idx ON webhook_templates(category) WHERE deprecated_at IS NULL;
```

Templates are seeded for: GitHub releases, GitHub PRs, GitLab pipelines, Stripe receipts, Sentry alerts, Linear issues, Vercel deploys, Custom HTTP, Generic JSON in, Generic JSON out.

### Table: `webhook_runs`
```sql
CREATE TABLE webhook_runs (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  webhook_id      UUID NOT NULL REFERENCES webhooks(id) ON DELETE CASCADE,
  server_id       UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  direction       TEXT NOT NULL CHECK (direction IN ('inbound', 'outbound')),
  status          TEXT NOT NULL CHECK (status IN (
                    'pending','running','succeeded',
                    'failed_retryable','failed_permanent','failed_timeout',
                    'dead_lettered'
                  )),
  attempt         INTEGER NOT NULL DEFAULT 1,
  next_retry_at   TIMESTAMPTZ,
  request_body    JSONB,
  request_headers JSONB,
  source_ip       INET,
  destination_url TEXT,
  response_status INTEGER,
  response_body   TEXT,
  duration_ms     INTEGER,
  graph_snapshot  JSONB NOT NULL,
  node_outputs    JSONB,
  error_reason    TEXT,
  replay_of       UUID REFERENCES webhook_runs(id),
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  completed_at    TIMESTAMPTZ
);
CREATE INDEX webhook_runs_webhook_idx ON webhook_runs(webhook_id, created_at DESC);
CREATE INDEX webhook_runs_pending_idx ON webhook_runs(status, next_retry_at)
  WHERE status IN ('pending', 'failed_retryable');
CREATE INDEX webhook_runs_server_idx ON webhook_runs(server_id, created_at DESC);
```

`request_body` is truncated to 1 MB before storage. `response_body` is truncated to 64 KB. A retention job purges runs older than 30 days nightly.

### Table: `webhook_signatures`
```sql
CREATE TABLE webhook_signatures (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  webhook_id      UUID NOT NULL REFERENCES webhooks(id) ON DELETE CASCADE,
  scheme          TEXT NOT NULL CHECK (scheme IN ('flicko_v1','github','stripe','custom_hmac')),
  secret_encrypted BYTEA NOT NULL,
  secret_prefix   TEXT NOT NULL,
  active          BOOLEAN NOT NULL DEFAULT true,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  rotated_at      TIMESTAMPTZ,
  expires_at      TIMESTAMPTZ
);
CREATE INDEX webhook_signatures_webhook_idx ON webhook_signatures(webhook_id) WHERE active = true;
```

Secrets are encrypted at rest with `pgsodium`. The `expires_at` column drives the 24-hour grace window after rotation.

### Table: `webhook_replay_queue`
```sql
CREATE TABLE webhook_replay_queue (
  id            BIGSERIAL PRIMARY KEY,
  run_id        UUID NOT NULL REFERENCES webhook_runs(id) ON DELETE CASCADE,
  webhook_id    UUID NOT NULL,
  enqueued_at   TIMESTAMPTZ NOT NULL DEFAULT now(),
  scheduled_at  TIMESTAMPTZ NOT NULL,
  attempt       INTEGER NOT NULL,
  locked_until  TIMESTAMPTZ
);
CREATE INDEX webhook_replay_queue_due_idx ON webhook_replay_queue(scheduled_at)
  WHERE locked_until IS NULL OR locked_until < now();
```

### Table: `webhook_signature_failures`
A small append-only table that tracks signature mismatches per webhook for the dashboard counter.
```sql
CREATE TABLE webhook_signature_failures (
  id          BIGSERIAL PRIMARY KEY,
  webhook_id  UUID NOT NULL REFERENCES webhooks(id) ON DELETE CASCADE,
  source_ip   INET,
  reason      TEXT NOT NULL,
  occurred_at TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX webhook_signature_failures_webhook_idx
  ON webhook_signature_failures(webhook_id, occurred_at DESC);
```

A retention job deletes rows older than 14 days.

## Graph JSON Shape
The `graph` column stores a serialized canvas:
```json
{
  "nodes": [
    {"id":"n1","type":"trigger.github.release","config":{"repo":"acme/api"}},
    {"id":"n2","type":"transform.jsonata","config":{"expr":"{ name: $.release.name }"}},
    {"id":"n3","type":"destination.channel.post","config":{"channel_id":"...","template":"{{name}}"}}
  ],
  "edges": [
    {"from":"n1","to":"n2"},
    {"from":"n2","to":"n3"}
  ]
}
```

A check constraint validates the shape via a Postgres function `webhook_graph_valid(graph jsonb)` that verifies presence of `nodes`/`edges`, no orphan ids, and at most one trigger.

## RLS Policies
```sql
ALTER TABLE webhooks ENABLE ROW LEVEL SECURITY;
CREATE POLICY webhooks_admin_rw ON webhooks
  FOR ALL TO authenticated
  USING (server_id IN (SELECT server_id FROM server_admins WHERE user_id = auth.uid()));

ALTER TABLE webhook_runs ENABLE ROW LEVEL SECURITY;
CREATE POLICY webhook_runs_admin_r ON webhook_runs
  FOR SELECT TO authenticated
  USING (server_id IN (SELECT server_id FROM server_admins WHERE user_id = auth.uid()));

ALTER TABLE webhook_signatures ENABLE ROW LEVEL SECURITY;
CREATE POLICY webhook_signatures_admin_r ON webhook_signatures
  FOR SELECT TO authenticated
  USING (webhook_id IN (
    SELECT id FROM webhooks WHERE server_id IN (
      SELECT server_id FROM server_admins WHERE user_id = auth.uid()
    )
  ));
```

`webhook_signatures` never exposes `secret_encrypted` to clients; the column is omitted from the API response shape.
