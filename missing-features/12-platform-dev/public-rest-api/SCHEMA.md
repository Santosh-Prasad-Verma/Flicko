# SCHEMA: Public REST API

Migration: `242_public_api.sql`.

## oauth_apps
```sql
CREATE TABLE oauth_apps (
  id              text PRIMARY KEY DEFAULT ('flk_app_' || encode(gen_random_bytes(12),'base32')),
  owner_id        uuid NOT NULL REFERENCES users(id),
  display_name    text NOT NULL,
  description     text,
  homepage_url    text,
  privacy_url     text,
  client_secret_hash bytea NOT NULL,                 -- argon2id
  secret_prefix   text NOT NULL,                     -- first 6 chars, displayable
  redirect_uris   text[] NOT NULL DEFAULT '{}',
  allowed_scopes  text[] NOT NULL DEFAULT '{}',
  app_type        text NOT NULL DEFAULT 'confidential'
                    CHECK (app_type IN ('confidential','public')),
  rate_limit_rpm  integer NOT NULL DEFAULT 600,
  status          text NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active','suspended','deleted')),
  created_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX oauth_apps_owner_idx ON oauth_apps(owner_id) WHERE status='active';

ALTER TABLE oauth_apps ENABLE ROW LEVEL SECURITY;
CREATE POLICY oauth_apps_owner ON oauth_apps FOR ALL USING (owner_id = auth.uid());
```

## oauth_authorizations
```sql
CREATE TABLE oauth_authorizations (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  app_id          text NOT NULL REFERENCES oauth_apps(id) ON DELETE CASCADE,
  user_id         uuid NOT NULL REFERENCES users(id),
  server_id       uuid REFERENCES servers(id),
  scopes          text[] NOT NULL,
  channels_allow  uuid[] NOT NULL DEFAULT '{}',
  refresh_family  uuid NOT NULL DEFAULT gen_random_uuid(),
  refresh_hash    bytea NOT NULL,
  refresh_expires timestamptz NOT NULL,
  created_at      timestamptz NOT NULL DEFAULT now(),
  revoked_at      timestamptz,
  UNIQUE (app_id, user_id, server_id)
);
CREATE INDEX oauth_auth_user_idx ON oauth_authorizations(user_id) WHERE revoked_at IS NULL;
CREATE INDEX oauth_auth_family_idx ON oauth_authorizations(refresh_family);
```

## api_tokens
```sql
CREATE TABLE api_tokens (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  app_id          text NOT NULL REFERENCES oauth_apps(id) ON DELETE CASCADE,
  name            text NOT NULL,
  token_hash      bytea NOT NULL,
  token_prefix    text NOT NULL,                     -- e.g. flk_pk_abc123, displayable
  scopes          text[] NOT NULL,
  server_allow    uuid[] NOT NULL DEFAULT '{}',      -- empty = all
  created_by      uuid NOT NULL REFERENCES users(id),
  created_at      timestamptz NOT NULL DEFAULT now(),
  last_used_at    timestamptz,
  revoked_at      timestamptz,
  expires_at      timestamptz
);
CREATE UNIQUE INDEX api_tokens_hash_idx ON api_tokens(token_hash);
CREATE INDEX api_tokens_app_idx ON api_tokens(app_id) WHERE revoked_at IS NULL;

ALTER TABLE api_tokens ENABLE ROW LEVEL SECURITY;
CREATE POLICY api_tokens_app_owner ON api_tokens FOR ALL
  USING (
    EXISTS (SELECT 1 FROM oauth_apps a
             WHERE a.id = api_tokens.app_id
               AND a.owner_id = auth.uid())
  );
```

## api_rate_limits
```sql
CREATE TABLE api_rate_limits (
  id              bigserial PRIMARY KEY,
  scope           text NOT NULL CHECK (scope IN ('app','user','app_user','ip','route')),
  scope_key       text NOT NULL,                     -- e.g. app_id, user_id, app_id|user_id
  route_pattern   text,                              -- nullable for global
  rpm_limit       integer NOT NULL,
  burst_limit     integer NOT NULL,
  effective_at    timestamptz NOT NULL DEFAULT now(),
  expires_at      timestamptz,
  reason          text,
  UNIQUE (scope, scope_key, route_pattern)
);
CREATE INDEX rate_limits_scope_idx ON api_rate_limits(scope, scope_key);
```
Live counters live in Redis (`rl:{scope}:{key}:{route}:{minute}`); this table holds only the configured caps and overrides. Default caps (app=600 rpm, user=300 rpm, ip=600 rpm) seeded at migration.

## webhook_subscriptions
```sql
CREATE TABLE webhook_subscriptions (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  app_id          text NOT NULL REFERENCES oauth_apps(id) ON DELETE CASCADE,
  server_id       uuid REFERENCES servers(id),
  url             text NOT NULL,
  events          text[] NOT NULL,
  secret_hash     bytea NOT NULL,
  status          text NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active','suspended','disabled')),
  failure_count   integer NOT NULL DEFAULT 0,
  last_success_at timestamptz,
  last_error      text,
  created_at      timestamptz NOT NULL DEFAULT now()
);
CREATE INDEX wh_app_idx ON webhook_subscriptions(app_id);
CREATE INDEX wh_events_idx ON webhook_subscriptions USING gin(events);
```

## webhook_deliveries
```sql
CREATE TABLE webhook_deliveries (
  id              uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  sub_id          uuid NOT NULL REFERENCES webhook_subscriptions(id) ON DELETE CASCADE,
  event_id        uuid NOT NULL,
  attempt         smallint NOT NULL DEFAULT 1,
  status_code     smallint,
  latency_ms      integer,
  delivered_at    timestamptz,
  next_retry_at   timestamptz,
  result          text NOT NULL CHECK (result IN ('queued','delivered','failed','dropped'))
) PARTITION BY RANGE (delivered_at);
CREATE INDEX wh_del_sub_idx ON webhook_deliveries(sub_id, delivered_at DESC);
```

## RLS summary
- App owner sees their app, tokens, authorizations, webhooks.
- Users see authorizations they personally granted.
- Platform admins see all via `auth.jwt() ->> 'role' = 'admin'`.

## Triggers
- `oauth_auth_revoke_family`: on UPDATE setting `revoked_at`, also revoke other rows sharing `refresh_family`.
- `api_tokens_last_used`: bump `last_used_at` once per minute via batched job, not per request.
- `webhook_failure_circuit`: on `failure_count` crossing 50, set `status='suspended'`.
