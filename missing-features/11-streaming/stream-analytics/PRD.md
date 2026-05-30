# Stream Analytics — PRD

> **One-line:** Real-time + historical analytics for stream owners — viewers, watch-time, drop-off, chat density, donations.
> **Status:** Missing
> **Category:** 11-streaming
> **Effort:** L
> **Priority:** P1

## 1. Problem
Streamers can't see who watched, when they dropped off, peak concurrent, chat heat, donations earned. Twitch/YouTube give this. Without it, growth and tuning are guesswork.

## 2. Users
- **Primary:** Streamers monetizing or growing audience.
- **Secondary:** Server owners running events.

JTBDs:
1. As a streamer, I want post-stream stats so I can improve.
2. As a streamer, I want live concurrents so I know my reach.
3. As a server owner, I want event recap to share.

## 3. Goals
- Real-time concurrent viewer count (≤5s latency)
- Per-stream summary within 60s of end
- 30-day historical with daily aggregates
- Export CSV

Non-goals: Per-viewer demographics (privacy).

## 4. Scope (v1)
- [ ] Concurrent viewers (live)
- [ ] Peak, total unique viewers
- [ ] Average watch-time
- [ ] Drop-off curve
- [ ] Chat messages/min density
- [ ] Donations summary
- [ ] CSV export

## 5. Metrics
| Metric | Target |
|--------|--------|
| Adoption | 80% of streamers view dashboard within 24h |
| Latency p99 | <5s for live counters |
| Aggregate freshness | <60s after stream end |
| Cost | <$0.01 per stream |

## 6. Risks
- High write volume from join/leave events.
- PII concerns — anonymize aggregates.

## 7. Competitive
| Product | Take | Gap |
|---------|------|-----|
| Twitch | Rich, post-stream | Native to Flicko streams |
| YouTube | Days-late detail | Real-time-first |
| Discord | None | (massive) |

## 8. Rollout
- Flag `feature.stream_analytics.enabled`. Streamer dashboard tab.
- Gradual: free tier shows live + 7d; Plus tier 30d + CSV.
