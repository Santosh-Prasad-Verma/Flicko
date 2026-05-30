# Stream Analytics — IMPL

## Phases
| # | Goal | Days |
|---|------|------|
| 0 | Spec + privacy review | 2 |
| 1 | Migration 234 + partitioning | 2 |
| 2 | NATS ingest + Redis live aggregator | 4 |
| 3 | MV refresh job | 2 |
| 4 | REST handler + WS push | 2 |
| 5 | CSV exporter | 2 |
| 6 | Dashboard UI | 5 |
| 7 | QA + load test | 3 |
| 8 | Beta + GA | 3 |

## Backend
- [ ] `supabase/migrations/234_stream_analytics.up.sql` (with pg_partman)
- [ ] `backend/internal/services/streaming/analytics/{ingest,aggregator,mv_refresher,exporter}.go`
- [ ] `backend/internal/handlers/analytics_handler.go`
- [ ] LiveKit webhook subscription in existing `webhook_service.go`
- [ ] Permission: `STREAM_VIEW_ANALYTICS` (default streamer + admin)
- [ ] Metrics + Sentry hooks

## Mobile
- [ ] `mobile/lib/features/streaming/analytics/`
- [ ] `LiveCounterWidget`, `PostStreamSummaryScreen`, `AnalyticsDashboardScreen`, `DropOffChart`
- [ ] Riverpod providers
- [ ] CSV download via existing `download_service`
- [ ] L10n + golden tests

## Files
```
backend/internal/services/streaming/analytics/...           (new)
backend/internal/handlers/analytics_handler.go              (new)
mobile/lib/features/streaming/analytics/...                 (new)
supabase/migrations/234_stream_analytics.up.sql             (new)
```

## Test Plan
- Load: 10k events/s for 5 min via k6.
- Correctness: replay synthetic stream, verify peak/unique/watch.
- Privacy: opted-out viewer not in user_id.
- CSV: 1M-row export under 30s.

## Rollout
- Flag `feature.stream_analytics.enabled`. Default ON for stream owners.
- Plus tier unlocks 30-day history + CSV.

## Risks
| Risk | Mitigation |
|------|------------|
| Hot streams overload aggregator | shard Redis key by stream prefix |
| MV refresh slow on big tables | partitioned tables, 30d retention |
| Privacy regression | opt-out enforced at ingest |

## Cost
$0. Reuses NATS + Redis + Postgres free tiers.
