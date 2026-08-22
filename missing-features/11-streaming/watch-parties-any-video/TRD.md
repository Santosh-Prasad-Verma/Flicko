# TRD: Watch Parties for Any Video

## Architecture Overview
Watch parties are a coordination layer over existing infrastructure. Flicko never proxies media: every client fetches the source from its provider directly. The backend is responsible for party lifecycle, host election, participant tracking, and authoritative timestamps that survive host churn. voice data channels deliver low-latency sync messages; Postgres (via Supabase) is the durable store; Redis pub/sub fans out party events to the gateway WebSocket.

```
Client (Flutter)
  |- ProviderPlayer (YouTube IFrame / Twitch Embed / Vimeo / video_player)
  |- Voice DataChannel (sync ticks, reactions)
  |- Gateway WS (chat sidebar, presence, lifecycle)
Backend (Go)
  |- watch_parties module: REST + gateway events
  |- host_election worker: heartbeat scanner
  |- provider resolver: oEmbed + URL parsers
Azure ACS (data channel only for sync)
Supabase Postgres (parties, participants, providers)
```

## Services and Modules
- `backend/internal/streaming/watchparty/` Go module containing `service.go`, `host_election.go`, `provider_resolver.go`, `sync_relay.go`, `handlers.go`.
- `backend/internal/handlers/watchparty/handlers.go` HTTP layer wired into the chi router under `/api/v1/watch-parties`.
- `mobile/lib/features/watch_parties/` Flutter feature module with `data/`, `domain/`, `presentation/`, and `providers/` subtrees.

## Provider Abstraction
A single Go interface drives every provider:

```go
type Provider interface {
    Key() string
    Resolve(ctx context.Context, rawURL string) (*ResolvedMedia, error)
    Embed(rm *ResolvedMedia) EmbedDescriptor
    SupportsLive() bool
}

type ResolvedMedia struct {
    ExternalID      string
    DurationSeconds *int
    ThumbnailURL    string
    Title           string
    Live            bool
}
```

Implementations: `youtube`, `twitch`, `vimeo`, `mp4`. Registry sits in `provider_resolver.go` keyed by hostname patterns. Unknown URLs fall through to `mp4` with a `HEAD` probe to validate `Content-Type`. The resolved record is cached in `watch_party_providers` for 24 hours so a repeated paste does not retrigger oEmbed calls.

## Sync Protocol
The host emits a `tick` payload every 2 seconds on the voice data channel topic `wp.sync`:

```json
{
  "type": "tick",
  "party_id": "wp_01HX...",
  "position_ms": 174320,
  "playback_rate": 1.0,
  "state": "playing",
  "wall_clock_ms": 1716998412345,
  "host_id": "user_01HW...",
  "seq": 8421
}
```

Clients compute expected position as `position_ms + (now - wall_clock_ms) * playback_rate` and compare with the player's actual position. Drift handling:
- `< 200 ms`: ignore.
- `200 to 600 ms`: nudge by setting `playbackRate` to 0.95 or 1.05 for two seconds.
- `> 600 ms`: hard seek to expected position.
- `> 5000 ms` and persistent: surface a "Resync" toast and request a manual rejoin.

A `command` payload travels the same channel for host-initiated events (`pause`, `resume`, `seek`, `set_rate`, `change_source`). The backend mirrors every command into Postgres so late joiners can reconstruct state on join.

## Host Election
A backend goroutine scans `watch_party_participants` every second for parties whose host has not heartbeat in 8 seconds. The candidate is the participant with the smallest `joined_at` whose `last_heartbeat_at` is within the last 5 seconds. The election is committed via a conditional update (`UPDATE watch_parties SET host_id = $new WHERE id = $party AND host_id = $old`) to make it CAS-safe. The winner publishes a `host_changed` event and resumes tick emission. Clients accept ticks only from the current `host_id`, refusing stale tickers from a deposed host.

## REST Endpoints
- `POST /api/v1/watch-parties/resolve` body `{url}` returns provider metadata.
- `POST /api/v1/watch-parties` body `{server_id, channel_id, provider, external_id, scheduled_for?}` creates a party, returns its ID and the Azure ACS voice token.
- `POST /api/v1/watch-parties/:id/join` returns a join token and the latest authoritative tick.
- `POST /api/v1/watch-parties/:id/command` body `{command, payload}` host-only commands.
- `POST /api/v1/watch-parties/:id/leave` removes the participant; if host, triggers immediate election.
- `GET /api/v1/watch-parties/:id` returns party plus the last 50 chat messages.
- `DELETE /api/v1/watch-parties/:id` host or moderator only, sets state `ended`.

All endpoints require the existing `Authorization: Bearer <session>` JWT and run through the standard rate limiter (`30 req/min` for resolve, `10 req/min` for create).

## Gateway Events
Pushed over the existing WebSocket gateway:
- `watch_party.created`, `watch_party.started`, `watch_party.ended`
- `watch_party.participant_joined`, `watch_party.participant_left`
- `watch_party.host_changed`
- `watch_party.command` (mirror of host commands for late joiners)

## Performance and Capacity
- Tick fan-out is handled by Azure ACS; backend cost is fixed per party at roughly 0.5 RPS for heartbeats.
- 250 concurrent participants per party. Beyond that, reactions are aggregated server-side every 2 seconds into bucketed counters.
- Provider resolver cache hit ratio target above 80 percent within a server.

## Failure Modes
- **Provider down**: resolver returns `provider_unavailable`; client suggests retry with a different URL.
- **Live source ends**: client emits `source_ended`; backend pauses party and prompts host.
- **voice data channel disconnect**: client falls back to gateway WS sync ticks at 1 Hz with a banner indicating degraded sync.
- **Postgres write failure during election**: election retries up to 3 times with jittered backoff; failure marks the party `paused`.

## Security
- Server-level RLS on every table (`watch_parties`, `watch_party_participants`, `watch_party_providers`) keyed on `server_id` and member roles.
- Embed descriptors are sanitized server-side; only known providers may emit iframe descriptors.
- The MP4 resolver only accepts HTTPS URLs and refuses anything resolving to private IP ranges (SSRF guard via `netip` checks).

## Observability
Metrics: `watchparty.party.active`, `watchparty.tick.skew_ms`, `watchparty.election.count`, `watchparty.resolve.latency_ms{provider}`. Logs are structured JSON with `party_id` and `server_id`. Sentry breadcrumbs include the last 20 ticks for every player error.

## Migrations
- `235_watch_parties.sql` creates `watch_parties` and `watch_party_participants`.
- `236_watch_party_providers.sql` adds the resolver cache table and indices.
- `237_watch_party_engagements.sql` is reserved for reaction aggregates and not landed in v1.
