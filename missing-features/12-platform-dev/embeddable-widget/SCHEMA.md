# SCHEMA: Embeddable Widget

## Migration 245
File: `backend/migrations/245_embed_widget.sql`.

```sql
-- Embed key registry
CREATE TABLE embed_keys (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    server_id       UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    name            TEXT NOT NULL,
    key_prefix      TEXT NOT NULL,                 -- 'emb_live_xxxx' first 12 chars (display)
    key_hash        TEXT NOT NULL,                 -- sha256 of full key
    allowed_channels UUID[] NOT NULL DEFAULT '{}', -- channel ids
    theme           TEXT NOT NULL DEFAULT 'auto'
                    CHECK (theme IN ('light','dark','auto')),
    show_badge      BOOLEAN NOT NULL DEFAULT TRUE,
    is_dev          BOOLEAN NOT NULL DEFAULT FALSE,
    status          TEXT NOT NULL DEFAULT 'active'
                    CHECK (status IN ('active','disabled','revoked')),
    created_by      UUID NOT NULL REFERENCES users(id),
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_used_at    TIMESTAMPTZ,
    rotated_at      TIMESTAMPTZ
);
CREATE UNIQUE INDEX idx_embed_keys_hash ON embed_keys (key_hash);
CREATE INDEX idx_embed_keys_server ON embed_keys (server_id) WHERE status = 'active';

-- Origin allowlist per key
CREATE TABLE embed_origins (
    id              BIGSERIAL PRIMARY KEY,
    key_id          UUID NOT NULL REFERENCES embed_keys(id) ON DELETE CASCADE,
    origin_pattern  TEXT NOT NULL,                 -- 'https://example.com' or 'https://*.example.com'
    has_wildcard    BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_embed_origins_key ON embed_origins (key_id);

-- Monthly view counters per key
CREATE TABLE embed_view_counters (
    key_id          UUID NOT NULL REFERENCES embed_keys(id) ON DELETE CASCADE,
    period          DATE NOT NULL,                 -- first day of the month
    inits           BIGINT NOT NULL DEFAULT 0,
    join_clicks     BIGINT NOT NULL DEFAULT 0,
    blocked_origins BIGINT NOT NULL DEFAULT 0,
    PRIMARY KEY (key_id, period)
);

-- Per-day fine-grained metrics for the admin dashboard
CREATE TABLE embed_daily_metrics (
    key_id          UUID NOT NULL,
    day             DATE NOT NULL,
    inits           INT NOT NULL DEFAULT 0,
    unique_referers INT NOT NULL DEFAULT 0,
    countries       JSONB,                         -- {"US": 412, "BR": 88}
    p95_init_ms     INT,
    PRIMARY KEY (key_id, day)
);

-- Audit log for embed key actions
CREATE TABLE embed_audit_events (
    id          BIGSERIAL PRIMARY KEY,
    key_id      UUID NOT NULL,
    actor_id    UUID NOT NULL,
    action      TEXT NOT NULL CHECK (action IN
                ('created','updated','rotated','revoked','origin_added','origin_removed')),
    metadata    JSONB,
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_embed_audit_key ON embed_audit_events (key_id, created_at DESC);
```

## User Privacy Column
Existing `users` table gains:
```sql
ALTER TABLE users
  ADD COLUMN hide_from_embeds BOOLEAN NOT NULL DEFAULT FALSE;
```
Existing `messages` table gains:
```sql
ALTER TABLE messages
  ADD COLUMN embed_visible BOOLEAN NOT NULL DEFAULT TRUE;
CREATE INDEX idx_messages_embed_visible
  ON messages (channel_id, created_at DESC)
  WHERE embed_visible = TRUE;
```
A trigger updates `embed_visible` from `users.hide_from_embeds` on insert.

## Row Level Security
- `embed_keys`: server admins with `embeds.manage` can read and write. The raw key value is never returned after creation; only the hash is stored.
- `embed_origins`, `embed_view_counters`, `embed_daily_metrics`: tied to admin permission via key ownership.

## Initial Payload Shape
`GET /api/v1/embed/init` response (typed):
```json
{
  "server": {"id": "...", "name": "Acme Community", "avatar_url": "..."},
  "channel": {"id": "...", "name": "general", "topic": "..."},
  "messages": [
    {
      "id": "01HX...",
      "author": {"id":"...", "name":"Sam", "avatar_url":"...", "color":"#7C3AED"},
      "body": "Hey welcome",
      "rendered": [{"type":"text","value":"Hey welcome"}],
      "created_at": "2026-05-29T12:01:08Z"
    }
  ],
  "presence_count": 12,
  "branding": {"badge": true, "theme": "auto"},
  "centrifugo": {"url": "wss://realtime.flicko.app/connection/websocket",
                 "token": "eyJ...", "channel": "embed:abcd:efgh", "ttl": 300}
}
```

## Centrifugo Namespace
`embed:` namespace config:
```yaml
embed:
  publish: false
  subscribe_to_user_personal_channel: false
  presence: true
  presence_disconnect_for_client: false
  history_size: 0
  history_ttl: "0s"
  position: false
```

## Retention
- `embed_audit_events`: 365 days.
- `embed_daily_metrics`: 24 months.
- `embed_view_counters`: lifetime of the key.

## Index Strategy
- Hot path is `key_hash` lookup: unique index, microsecond latency.
- Origin matching joins on `key_id`, ten or fewer rows per key, no scans.
- Counter increments use `INSERT ... ON CONFLICT (key_id, period) DO UPDATE SET inits = inits + 1`.

## Realtime
Centrifugo channel `embeds:{server_id}` for the admin manager pushes:
- key created or rotated
- monthly view counter every 60 seconds
- alerts when a key approaches view cap (80, 95, 100 percent)
