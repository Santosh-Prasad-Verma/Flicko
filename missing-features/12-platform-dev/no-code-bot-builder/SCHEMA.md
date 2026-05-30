# SCHEMA: No-Code Bot Builder

## Migration 243
File: `backend/migrations/243_bot_builder.sql`.

```sql
-- Bot configurations (latest revision per bot)
CREATE TABLE bot_dsl_configs (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    server_id     UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
    name          TEXT NOT NULL,
    description   TEXT,
    dsl_json      JSONB NOT NULL,
    version       INT NOT NULL DEFAULT 1,
    enabled       BOOLEAN NOT NULL DEFAULT FALSE,
    created_by    UUID NOT NULL REFERENCES users(id),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    last_run_at   TIMESTAMPTZ,
    UNIQUE (server_id, name)
);
CREATE INDEX idx_bot_dsl_configs_server_enabled ON bot_dsl_configs (server_id, enabled);
CREATE INDEX idx_bot_dsl_configs_dsl_triggers ON bot_dsl_configs
    USING GIN ((dsl_json -> 'triggers'));

-- Append-only revision history
CREATE TABLE bot_dsl_revisions (
    bot_id        UUID NOT NULL REFERENCES bot_dsl_configs(id) ON DELETE CASCADE,
    version       INT NOT NULL,
    dsl_json      JSONB NOT NULL,
    diff_summary  TEXT,
    author_id     UUID NOT NULL REFERENCES users(id),
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (bot_id, version)
);

-- One row per execution
CREATE TABLE bot_runs (
    id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    bot_id          UUID NOT NULL REFERENCES bot_dsl_configs(id) ON DELETE CASCADE,
    server_id       UUID NOT NULL,
    bot_version     INT NOT NULL,
    trigger_type    TEXT NOT NULL,
    trigger_event   JSONB NOT NULL,
    status          TEXT NOT NULL CHECK (status IN
                       ('queued','running','success','failed',
                        'timed_out','rate_limited','crashed','orphaned')),
    started_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
    ended_at        TIMESTAMPTZ,
    duration_ms     INT,
    nodes_executed  INT NOT NULL DEFAULT 0,
    error           TEXT
);
CREATE INDEX idx_bot_runs_bot_started ON bot_runs (bot_id, started_at DESC);
CREATE INDEX idx_bot_runs_status ON bot_runs (status) WHERE status IN ('queued','running');

-- Per-node trace
CREATE TABLE bot_run_logs (
    run_id        UUID NOT NULL REFERENCES bot_runs(id) ON DELETE CASCADE,
    seq           INT NOT NULL,
    node_id       TEXT NOT NULL,
    node_type     TEXT NOT NULL,
    input         JSONB,
    output        JSONB,
    duration_ms   INT NOT NULL,
    error         TEXT,
    PRIMARY KEY (run_id, seq)
);

-- Bot-scoped variable storage (e.g., counters)
CREATE TABLE bot_variables (
    bot_id        UUID NOT NULL REFERENCES bot_dsl_configs(id) ON DELETE CASCADE,
    name          TEXT NOT NULL,
    value         JSONB NOT NULL,
    updated_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
    PRIMARY KEY (bot_id, name)
);

-- Audit log for management actions
CREATE TABLE bot_audit_events (
    id            BIGSERIAL PRIMARY KEY,
    bot_id        UUID NOT NULL,
    actor_id      UUID NOT NULL,
    action        TEXT NOT NULL,
    metadata      JSONB,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_bot_audit_bot_created ON bot_audit_events (bot_id, created_at DESC);
```

## DSL JSON Schema (snippet)

```json
{
  "$schema": "http://json-schema.org/draft-07/schema#",
  "type": "object",
  "required": ["version", "name", "nodes", "edges"],
  "properties": {
    "version": {"type": "integer", "minimum": 1},
    "name": {"type": "string", "maxLength": 100},
    "variables": {
      "type": "object",
      "patternProperties": {
        "^[a-zA-Z_][a-zA-Z0-9_]*$": {
          "type": "object",
          "properties": {
            "type": {"enum": ["string","int","bool","list_string"]},
            "default": {}
          }
        }
      }
    },
    "nodes": {
      "type": "array",
      "maxItems": 50,
      "items": {
        "type": "object",
        "required": ["id","type","params"],
        "properties": {
          "id": {"type": "string"},
          "type": {"type": "string"},
          "params": {"type": "object"},
          "position": {
            "type": "object",
            "properties": {
              "x": {"type": "number"},
              "y": {"type": "number"}
            }
          }
        }
      }
    },
    "edges": {
      "type": "array",
      "items": {
        "type": "object",
        "required": ["source","target"],
        "properties": {
          "source": {"type": "string"},
          "target": {"type": "string"},
          "source_handle": {
            "enum": ["default","true","false"],
            "default": "default"
          }
        }
      }
    }
  }
}
```

## Retention
- `bot_runs` and `bot_run_logs`: 30 days, partitioned monthly. Older partitions detached and archived to S3 in Parquet.
- `bot_dsl_revisions`: kept for the lifetime of the bot.
- `bot_audit_events`: 365 days.

## Row Level Security
RLS on `bot_dsl_configs` and `bot_runs`: users can read where they have `bot.read` permission on `server_id`, and write where they have `bot.manage`. Enforced via Supabase policies.

## Realtime
Centrifugo channels:
- `bots:{server_id}` for bot list updates.
- `bot:{bot_id}:runs` for live run feed.
Server emits to these channels on every insert into `bot_runs` and `bot_dsl_configs`.
