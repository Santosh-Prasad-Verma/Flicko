# AI Semantic Search — PRD

> **One-line:** Search messages by meaning, not just keywords, using vector embeddings (Qdrant + nomic-embed) alongside Meilisearch lexical search.
> **Effort:** M · **Priority:** P1

## Problem
Lexical search misses paraphrases, code-switched text, and conceptual queries ("the time we discussed pricing"). Semantic search finds intent, not just exact matches.

## Users
- Power users hunting an old conversation.
- Mods researching rule violations.
- Newcomers asking "has this been answered?"

JTBDs:
1. Find a half-remembered thread by meaning.
2. Answer "what did we decide about X" without scrolling.
3. Surface duplicate questions before they're asked.

## Goals
- Hybrid: lexical + semantic, scored together.
- Sub-300ms p99.
- Top-10 quality MRR ≥0.7 vs labelled set.
- No reading of E2EE messages.

## Scope
- [ ] Background embedding worker for new messages
- [ ] Hybrid query planner
- [ ] UI: "Smart" toggle in search
- [ ] Per-server opt-in; per-message opt-out
- [ ] Privacy: never embed E2EE content

## Metrics
- Smart-search adoption: 25% of search-using DAU.
- Query MRR ≥0.7.
- Cost <$0.0001 per indexed message.

## Risks
- Vector drift on model upgrade. Mitigation: re-embed on version bump.
- Privacy: encrypted DMs must never be embedded.
- Storage. Mitigation: 90d hot, prune older or summarize.

## Competitive
| Product | Take | Gap |
|---------|------|-----|
| Discord | lexical | semantic |
| Slack | basic | better quality |
| Notion AI Search | strong but paid | free |
