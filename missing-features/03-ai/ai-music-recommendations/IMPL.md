# AI Music Recommendations — IMPL

## Phases
| # | Goal | Days |
|---|------|------|
| 0 | Spec | 2 |
| 1 | Migration 139 + pgvector | 1 |
| 2 | Listening event ingest | 3 |
| 3 | Taste vector worker | 3 |
| 4 | Picker service | 4 |
| 5 | Music-party hooks | 2 |
| 6 | Vibe prompt UI | 2 |
| 7 | Personal digest | 2 |
| 8 | Eval + tuning | 3 |
| 9 | Beta + GA | 3 |

## Backend
- [ ] `supabase/migrations/139_ai_music_recs.up.sql`
- [ ] `backend/internal/services/ai/music_recs/{taste_vector,room_vector,picker,validator}.go`
- [ ] Existing music-party queue handler hooked to call picker on `queue_low`
- [ ] Spotify catalog cache (24h)
- [ ] Metrics + Sentry

## Mobile
- [ ] `mobile/lib/features/sonic_music/ai_recs/`
- [ ] `AutoQueueBadge`, `VibeSheet`, `RationaleTooltip`, `WeeklyMixCard`
- [ ] L10n + golden tests

## Files
```
backend/internal/services/ai/music_recs/...           (new)
mobile/lib/features/sonic_music/ai_recs/...           (new)
supabase/migrations/139_ai_music_recs.up.sql          (new)
```

## Test
- Eval: 50 sessions, verify ≥70% auto-queue acceptance.
- Cold start: empty vectors fall back to genre seeds.
- Catalog miss: invalid URIs skipped without error to user.

## Rollout
- Flag `feature.music_recs.enabled`. Default ON inside music-party only.
- Personal digest opt-in.

## Risks
- Echo chamber: mitigate via ε-greedy exploration (10% wildcard pick).
- Skewed taste vector after long abandoned session: time-decay rolling 30d.

## Cost
- Groq free; Spotify free public endpoint; pgvector built-in. $0.
