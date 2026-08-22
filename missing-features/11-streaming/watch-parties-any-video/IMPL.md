# Watch Parties — Implementation

## Phases
| # | Goal | Days |
|---|------|------|
| 0 | Spec | 1 |
| 1 | Migration 235 + provider table | 1 |
| 2 | URL detection + oembed probe | 2 |
| 3 | Backend service + handler | 3 |
| 4 | voice data-channel sync engine | 4 |
| 5 | Mobile UI: party tile, player, controls | 5 |
| 6 | Drift correction tuning | 2 |
| 7 | Edge case + provider matrix QA | 3 |
| 8 | Beta + GA | 3 |

## Backend
- [ ] `supabase/migrations/235_watch_parties.up.sql`
- [ ] `backend/internal/services/streaming/watchparty/service.go`
- [ ] `backend/internal/services/streaming/watchparty/providers.go` (URL → provider, id, metadata)
- [ ] `backend/internal/services/streaming/watchparty/oembed_cache.go`
- [ ] `backend/internal/services/streaming/watchparty/sweeper.go` (pg_cron 1m)
- [ ] `backend/internal/handlers/watch_party_handler.go`
- [ ] voice data-channel `wp-control` publisher in azure_acs_service.go extension
- [ ] Permission: CONNECT + SPEAK in voice channel (or CHAT_VOICE_PARTY for text-only parties)

## Mobile
- [ ] `mobile/lib/features/streaming/watch_party/`
- [ ] DTOs/Repository
- [ ] Riverpod: `watchPartyProvider(id)`, `wpDriftProvider`
- [ ] Player widgets per provider:
  - YT: `youtube_player_iframe`
  - Twitch: webview embed
  - Vimeo: iframe
  - MP4/HLS: `video_player`
- [ ] Drift correction: hard-seek if |drift|>1.5 s, else `playbackRate ±5%` for 2 s
- [ ] Chat sidebar (existing)

## Files
```
backend/internal/services/streaming/watchparty/...           (new)
backend/internal/handlers/watch_party_handler.go             (new)
mobile/lib/features/streaming/watch_party/...                (new)
supabase/migrations/235_watch_parties.up.sql                 (new)
```

## Test Plan
- Provider matrix: YT, Twitch VOD, Vimeo, MP4, HLS, Flicko VOD.
- Drift sim: 100ms / 500ms / 2s offsets; verify recovery.
- 50-viewer load test.
- Geo-block fallback message.

## Rollout
- Flag `feature.watch_parties.enabled`. Default OFF.
- Beta on 5 servers.
- Canary 1%→100% over 7d.

## Risks
| Risk | Mitigation |
|------|------------|
| DMCA on host's URL | hosts attest source; auto-stop on takedown signal |
| Drift ruins UX | server-clock + heartbeat at 5s; max gap budget 1.5s |
| Provider rate-limit | oembed cache 1h |
| Provider deprecation | pluggable provider table + tests |

## Cost
$0. No new infra. Reuses voice data channel.
