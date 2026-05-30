# AI Semantic Search — IMPL

## Phases
| # | Goal | Days |
|---|------|------|
| 0 | Spec + privacy review | 3 |
| 1 | Migration 140 + Qdrant collection | 1 |
| 2 | Embedder worker | 4 |
| 3 | Query planner + rerank | 4 |
| 4 | Search UI mode toggle | 2 |
| 5 | Eval harness with seeded queries | 3 |
| 6 | Backfill historical messages | 3 |
| 7 | QA + privacy gating | 2 |
| 8 | Beta + GA | 4 |

## Backend
- [ ] `supabase/migrations/140_ai_semantic_search.up.sql`
- [ ] `backend/internal/services/ai/semantic_search/{embedder,query_planner,reranker,backfiller}.go`
- [ ] Existing `search_service` extended
- [ ] NATS consumer durable name `semsearch-embedder`
- [ ] Metrics + Sentry

## Mobile
- [ ] `mobile/lib/features/search/ai/`
- [ ] `SearchModeToggle`, `MatchBadge`
- [ ] Riverpod
- [ ] Settings opt-in toggle
- [ ] L10n + golden tests

## Files
```
backend/internal/services/ai/semantic_search/...   (new)
backend/internal/services/search_service.go        (edit, hybrid)
mobile/lib/features/search/ai/...                  (new)
supabase/migrations/140_ai_semantic_search.up.sql  (new)
```

## Test
- MRR ≥0.7 against labelled set.
- E2EE messages absent in vector index.
- Edit/delete propagation tested.
- Lag alarm at 5 min.

## Rollout
- Flag `feature.ai_semsearch.enabled`. Default OFF.
- Beta on 5 servers; backfill at off-peak.

## Risks
| Risk | Mitigation |
|------|------------|
| Embedder backlog after launch | rate-shaped backfill, priority for new msgs |
| Vector storage scale | 90d hot, prune older or summarize |
| Reranker latency | timeout + skip |

## Cost
- Self-hosted Ollama for embeddings; Qdrant self-hosted; Meilisearch self-hosted. $0.
