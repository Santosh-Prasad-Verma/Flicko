# Achievement System — TRD

## Architecture

```
+------------------+     event     +------------------+      +-----------------+
|  Flicko clients  | ------------> |  ingress (HTTP)  | ---> | NATS: events.*  |
|  (mobile/web)    |               |  /v1/events      |      +-----------------+
+------------------+               +------------------+              |
                                                                     v
+----------------------+   read    +-----------------------+   write +------------------+
| profile-shelf API    | <-------- | achievement-engine    | <----- | Postgres counters |
| /v1/users/:id/ach    |           | (Go service)          |        | (user_progress)  |
+----------------------+           +-----------------------+        +------------------+
         |                                  |                               |
         v                                  v                               v
   Redis cache                        rules.yaml (60 defs)             cron: rarity %
   shelf:{user_id} 1m                 evaluator (in-process)           Redis: rarity:{ach_id}
```

The engine consumes events, increments per-user counters, and evaluates rules. On a threshold cross, it inserts into `user_achievements` and emits `achievement.unlocked`.

## REST routes

| Method | Path | Purpose | Auth |
|---|---|---|---|
| GET | /v1/achievements | List all definitions (with i18n) | bearer |
| GET | /v1/users/:id/achievements | List unlocked + progress | bearer |
| GET | /v1/users/:id/achievements/shelf | Pinned 6 + ordered rest | public |
| PUT | /v1/users/:id/achievements/shelf | Reorder shelf (self only) | bearer |
| POST | /v1/servers/:id/achievements | Owner adds from catalog | bearer + role |
| GET | /v1/servers/:id/achievements/:uid | Server-scoped progress | bearer |
| POST | /v1/internal/events | NATS bridge (cluster only) | mTLS |

## Event taxonomy

Events flow as `{user_id, server_id?, type, payload, occurred_at, idempotency_key}`. Types:
`voice.minute_active`, `text.message_sent`, `clip.published`, `clip.viewed`, `friend.added`, `gaming.session_started`, `gaming.session_ended`, `esports.minute_watched`, `account.linked`, `presence.streak_day`.

Engine deduplicates on idempotency_key (Redis SETNX, 24h TTL).

## Rule evaluation

Rules in `rules.yaml`:

```yaml
- id: voice_warrior
  category: voice
  rarity: rare
  hidden: false
  trigger: voice.minute_active
  window: total
  threshold: 6000
  i18n:
    en: { name: "Voice Warrior", desc: "Spend 100 hours in voice" }
```

Windows: `total`, `daily`, `weekly`, `rolling_7d`, `streak_n`. Engine maintains separate Postgres rows per (user, achievement, window).

## OAuth flows

OAuth lives in `game-stats-integration`. Engine listens for `account.linked` events to award the "Linked Up" achievement. No direct OAuth handling.

## NFRs

- p95 event-to-unlock latency: < 5s.
- Throughput: 2k events/s sustained; bursts 10k/s with NATS buffer.
- Storage: O(users × achievements) bounded at 60M rows for 1M users.
- Availability: 99.5% (eventual consistency acceptable).
- Backfill replay: must process 10M historical events in < 30 min.
- $0 ceiling: Postgres on Supabase free tier (500MB), Redis on Upstash free tier (10k cmd/day), NATS embedded.

## Observability

- Metrics: `ach_events_consumed_total`, `ach_unlocks_total{rarity}`, `ach_eval_duration_ms`, `ach_dedupe_hits_total`.
- Logs: structured JSON, sampled at 1% on the eval hot path.
- Traces: OpenTelemetry on `/v1/users/:id/achievements/shelf` (cache miss path only).
- Dashboards: Grafana Cloud free tier; alerts on lag > 60s.

## Failure modes

- NATS outage: events buffered to local SQLite, drained on recovery.
- Postgres write contention: counters use `INSERT ... ON CONFLICT DO UPDATE`, with row-level locks; engine partitions by `user_id % 16` workers.
- Rule reload: SIGHUP rereads `rules.yaml`; running evals finish on old rules (no abort).
- Rarity recompute: nightly cron computes `unlocks / total_users` per achievement, writes to Redis with 25h TTL.

## Security

- RLS on `user_achievements`: user can read own, anyone can read public-flagged unlocked rows.
- Server-scoped achievements: only server members can read.
- Event ingestion is internal-only (mTLS); client never POSTs to engine directly. Clients emit through their feature service which forwards.

## Migration 150

See `SCHEMA.md`.
