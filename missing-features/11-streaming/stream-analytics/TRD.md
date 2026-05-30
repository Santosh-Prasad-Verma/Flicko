# Stream Analytics — TRD

## Architecture
```
client → stream_event (join/leave/tick) → NATS flicko.stream.events.* →
  ┌─ live aggregator (in-memory + Redis) → Centrifugo `stream-stats:<id>`
  └─ batch worker → MV refresh (5 min)  → Postgres analytics tables → REST
```

## Components
- Backend: `backend/internal/services/streaming/analytics/{ingest.go, aggregator.go, mv_refresher.go, exporter.go}`
- Handler: `analytics_handler.go` — GET /streams/:id/analytics, GET /streams/:id/analytics/export.csv
- Realtime: Centrifugo channel `stream-stats:<id>`
- Cache: Redis sorted-set `stream:viewers:<id>` (member=user_id, score=last_seen_unix)

## API
```
GET /streams/:id/analytics?range=live|24h|7d|30d
→ {peak,unique,avg_watch_sec,drop_off:[{t,viewers}],chat_per_min,donations_cents,...}

GET /streams/:id/analytics/export.csv (Plus only)

WS sub stream-stats:<id>
→ {concurrent: 142, ts: 1717000000}
```

## NFRs
| NFR | Target |
|-----|--------|
| live counter latency | p99 <5s |
| MV refresh cadence | every 5 min |
| event ingest | 5k/s |
| CSV export | <30s for 1M events |

## Observability
- `flicko_stream_analytics_events_total{type}`
- `flicko_stream_analytics_mv_refresh_seconds`
- `flicko_stream_analytics_export_seconds`
- Alert if MV stale >15 min.

## Failure
| Failure | Mitigation |
|---------|------------|
| NATS down | events queue in Redis as fallback |
| MV refresh slow | partial views per metric |
| Hot stream skews aggregator | sharded by stream_id |
