# SCHEMA: Zapier and Make Integration

## Migration 244
File: `backend/migrations/244_zapier_make.sql`.

```sql
-- Registered OAuth client apps (Zapier, Make, future partners)
CREATE TABLE oauth_clients (
    id              TEXT PRIMARY KEY,            -- 'zapier', 'make'
    name            TEXT NOT NULL,
    client_secret   TEXT NOT NULL,               -- bcrypt
    redirect_uris   TEXT[] NOT NULL,
    allowed_scopes  TEXT[] NOT NULL,
    logo_url        TEXT,
    description     TEXT,
    is_first_party  BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Issued tokens
CREATE TABLE oauth_tokens (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    client_id       TEXT NOT NULL REFERENCES oauth_clients(id),
    user_id         UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    server_ids      UUID[] NOT NULL,
    scopes          TEXT[] NOT NULL,
    access_hash     TEXT NOT NULL,
    refresh_hash    TEXT NOT NULL,
    access_expires  TIMESTAMPTZ NOT NULL,
    refresh_expires TIMESTAMPTZ NOT NULL,
    revoked_at      TIMESTAMPTZ,
    last_used_at    TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_oauth_tokens_user ON oauth_tokens (user_id) WHERE revoked_at IS NULL;
CREATE UNIQUE INDEX idx_oauth_tokens_access_hash ON oauth_tokens (access_hash);

-- Trigger subscriptions registered by Zapier or Make on behalf of admin
CREATE TABLE zapier_subscriptions (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    token_id        UUID NOT NULL REFERENCES oauth_tokens(id) ON DELETE CASCADE,
    client_id       TEXT NOT NULL,               -- 'zapier' or 'make'
    server_id       UUID NOT NULL,
    event_type      TEXT NOT NULL,
    target_url      TEXT NOT NULL,
    filters         JSONB NOT NULL DEFAULT '{}',
    status          TEXT NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active','paused','auto_paused','revoked')),
    secret          TEXT NOT NULL,               -- HMAC shared secret
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_fired_at   TIMESTAMPTZ,
    last_success_at TIMESTAMPTZ,
    last_failure_at TIMESTAMPTZ,
    fail_streak     INT NOT NULL DEFAULT 0
);
CREATE INDEX idx_zap_sub_event_server ON zapier_subscriptions (event_type, server_id)
    WHERE status = 'active';
CREATE INDEX idx_zap_sub_token ON zapier_subscriptions (token_id);

-- Aggregated trigger metrics (one row per subscription per day)
CREATE TABLE zap_triggers (
    subscription_id UUID NOT NULL REFERENCES zapier_subscriptions(id) ON DELETE CASCADE,
    day             DATE NOT NULL,
    fires           INT NOT NULL DEFAULT 0,
    successes       INT NOT NULL DEFAULT 0,
    failures        INT NOT NULL DEFAULT 0,
    dead_letters    INT NOT NULL DEFAULT 0,
    PRIMARY KEY (subscription_id, day)
);

-- Action call audit log (the partner calling Flicko)
CREATE TABLE zap_actions (
    id              BIGSERIAL PRIMARY KEY,
    token_id        UUID NOT NULL REFERENCES oauth_tokens(id) ON DELETE CASCADE,
    server_id       UUID NOT NULL,
    action_type     TEXT NOT NULL,
    idempotency_key TEXT,
    status_code     INT NOT NULL,
    duration_ms     INT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_zap_actions_token_created ON zap_actions (token_id, created_at DESC);
CREATE INDEX idx_zap_actions_idempotency
    ON zap_actions (token_id, idempotency_key)
    WHERE idempotency_key IS NOT NULL;

-- Per-attempt outbound delivery records (truncated to 7 days)
CREATE TABLE zap_delivery_attempts (
    id              BIGSERIAL PRIMARY KEY,
    subscription_id UUID NOT NULL REFERENCES zapier_subscriptions(id) ON DELETE CASCADE,
    attempt_no      INT NOT NULL,
    payload_hash    TEXT NOT NULL,
    status_code     INT,
    response_body   TEXT,
    duration_ms     INT,
    error           TEXT,
    next_retry_at   TIMESTAMPTZ,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Dead letter queue
CREATE TABLE zap_dead_letter (
    id              BIGSERIAL PRIMARY KEY,
    subscription_id UUID NOT NULL REFERENCES zapier_subscriptions(id) ON DELETE CASCADE,
    payload         JSONB NOT NULL,
    last_error      TEXT,
    attempts        INT NOT NULL,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    resolved_at     TIMESTAMPTZ
);

-- Idempotency cache for action calls
CREATE TABLE idempotency_keys (
    token_id        UUID NOT NULL,
    key             TEXT NOT NULL,
    response_body   JSONB,
    status_code     INT,
    expires_at      TIMESTAMPTZ NOT NULL,
    PRIMARY KEY (token_id, key)
);
CREATE INDEX idx_idempotency_expires ON idempotency_keys (expires_at);
```

## Seed Data
```sql
INSERT INTO oauth_clients (id, name, client_secret, redirect_uris, allowed_scopes, is_first_party)
VALUES
  ('zapier', 'Zapier', '$2a$12$...',
   ARRAY['https://zapier.com/dashboard/auth/oauth/return/App/'],
   ARRAY['messages.send','messages.read','members.read','members.manage',
         'channels.read','channels.manage','events.read'],
   FALSE),
  ('make', 'Make', '$2a$12$...',
   ARRAY['https://www.make.com/oauth/cb/app'],
   ARRAY['messages.send','messages.read','members.read','members.manage',
         'channels.read','channels.manage','events.read'],
   FALSE);
```

## Retention
- `zap_actions`: 90 days, then deleted.
- `zap_delivery_attempts`: 7 days.
- `zap_triggers`: 365 days.
- `zap_dead_letter`: until resolved or 30 days, whichever first.
- `idempotency_keys`: TTL job removes rows past `expires_at` hourly.

## Row Level Security
- `oauth_tokens`: user can read their own rows. Admins can revoke tokens that grant their server.
- `zapier_subscriptions`: server admins with `integrations.manage` can read and pause; only the issuing user can revoke at the OAuth level.
- `zap_actions` and `zap_delivery_attempts`: admins of `server_id` only.

## Realtime
Centrifugo channel `integrations:{server_id}` pushes:
- subscription created or paused
- delivery success / failure summaries every 30 seconds
- dead-letter alerts

## Indexes Strategy Notes
- The hot path is the trigger lookup: `event_type + server_id`. Partial index excludes paused rows.
- Token lookups by access hash are unique; no scans expected.
- Action audit queries by token in dashboard order by created_at desc; covering index keeps queries under 5 ms.
