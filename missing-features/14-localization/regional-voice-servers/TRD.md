# Regional Voice Servers — Technical Requirements

## 1. Architecture Overview

```
                          ┌──────────────────┐
                          │ Cloudflare Edge  │
                          │ /health/<region> │
                          └────────┬─────────┘
                                   │
        ┌──────────────────────────┼──────────────────────────────┐
        │                          │                              │
        ▼                          ▼                              ▼
┌──────────────┐           ┌──────────────┐              ┌──────────────┐
│ LiveKit      │           │ LiveKit      │              │ LiveKit      │
│ na-east      │  feder.   │ eu-west      │     feder.   │ ap-southeast │
│ (us-east-1)  │◀─────────▶│ (Frankfurt)  │◀────────────▶│ (Tokyo)      │
└──────┬───────┘           └──────┬───────┘              └──────┬───────┘
       │                          │                             │
       └──────────────┬───────────┴─────────────┬──────────────┘
                      │                         │
                      ▼                         ▼
              ┌──────────────┐         ┌──────────────────────┐
              │ Go Backend   │         │ Mobile (Flutter)      │
              │ /voice/*     │         │ ping test + WebRTC   │
              └──────┬───────┘         └──────────────────────┘
                     │
                     ▼
              ┌──────────────┐
              │ Postgres     │
              │ voice_regions│
              │ session_metrics │
              └──────────────┘
```

Six regions:
- `na-east` (us-east-1)
- `na-west` (us-west-1)
- `eu-west` (Frankfurt)
- `ap-southeast` (Tokyo)
- `ap-south` (Mumbai)
- `sa-east` (Sao Paulo)

## 2. Components

### Backend (Go)
- **Service:** `backend/internal/services/i18n/regional-voice-servers/service.go`
  - `PickRegion(participantScores map[string]map[string]Score) string` — aggregate decision
  - `IsHealthy(region string) (bool, reason string)`
  - `IssueToken(roomName, region, identity string) (string, error)`
- **Worker:** `backend/internal/services/i18n/regional-voice-servers/health_worker.go` (every 30s)
- **Handlers:** `backend/internal/handlers/voice/sessions_handler.go`, `regions_handler.go`
- **Repo:** `voice_regions_repo.go`, `voice_session_metrics_repo.go`
- **LiveKit SDK:** `github.com/livekit/server-sdk-go v2.0`

### Mobile (Flutter)
- **Cross-cutting:** `mobile/lib/core/voice/`
  - `data/voice_region_repository.dart`
  - `application/region_picker_provider.dart`
  - `application/voice_session_provider.dart`
  - `presentation/voice_settings_screen.dart`
  - `presentation/quality_banner.dart`
- **LiveKit SDK:** `livekit_client: ^2.4.0`
- **Ping test util:** `mobile/lib/core/voice/ping/ping_test.dart` — parallel HTTPS HEAD with `Stopwatch`

### Infra (Terraform / Kubernetes manifests in `infra/`)
- `infra/livekit/<region>/`: per-region cluster (helm values, ingress)
- Cloudflare DNS: `<region>.voice.flicko.app` → regional ingress
- TURN server: bundled with LiveKit
- Health check: `/health` returns JSON with version + load
- Regional Redis for LiveKit session state

## 3. API Contracts

### REST

```
GET    /api/v1/voice/regions                       list candidate regions + health
POST   /api/v1/voice/sessions                      create / join session
DELETE /api/v1/voice/sessions/:id                  leave
GET    /api/v1/voice/sessions/:id/metrics          live metrics (pull every 5s)
PATCH  /api/v1/voice/preferences                   user override pin
PATCH  /api/v1/servers/:id/voice-pref              admin override pin
POST   /api/v1/voice/sessions/:id/failover         move room to next-best region
```

### Payloads

```jsonc
// GET /voice/regions
{
  "regions": [
    { "code":"na-east","name":"NA East","ws":"wss://na-east.voice.flicko.app",
      "healthy":true,  "load_pct":34, "draining":false },
    { "code":"na-west","name":"NA West","ws":"wss://na-west.voice.flicko.app",
      "healthy":true,  "load_pct":18, "draining":false },
    { "code":"eu-west","name":"EU West","ws":"wss://eu-west.voice.flicko.app",
      "healthy":true,  "load_pct":62, "draining":false },
    { "code":"ap-southeast","name":"APAC SE","ws":"wss://ap-southeast.voice.flicko.app",
      "healthy":true,  "load_pct":51, "draining":false },
    { "code":"ap-south","name":"APAC S","ws":"wss://ap-south.voice.flicko.app",
      "healthy":true,  "load_pct":29, "draining":false },
    { "code":"sa-east","name":"SA East","ws":"wss://sa-east.voice.flicko.app",
      "healthy":true,  "load_pct":12, "draining":false }
  ]
}

// POST /voice/sessions
{
  "channel_id": "uuid",
  "scores": {
    "na-east": { "rtt_ms": 240, "loss_pct": 0.1 },
    "ap-southeast": { "rtt_ms": 42, "loss_pct": 0.0 }
  },
  "region_pref": "ap-southeast"   // optional override
}

// Response
{
  "session_id":"uuid",
  "region":"ap-southeast",
  "ws":"wss://ap-southeast.voice.flicko.app",
  "token":"<lk-jwt>",
  "expires_at":"..."
}

// PATCH /voice/preferences
{ "pinned_region": "ap-southeast" }
```

## 4. Permissions & Auth

- All voice endpoints require user JWT.
- LiveKit access tokens minted server-side with strict TTL (1h, refresh on demand).
- Server admin pin: requires `voice.admin` server role.
- Health endpoint public (only returns boolean + load%).

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| `/voice/regions` p99 latency | <50ms |
| `/voice/sessions` create | <300ms p95 |
| Ping test wallclock | <800ms (parallel timeout) |
| Region pick wrong (post-call review) | <5% |
| Session connect time | <2s p95 |
| Failover time | <5s detect + reconnect |
| Health check fan-out | every 30s, 6 regions |
| Cost increase vs single-region | <2x |

## 6. Dependencies

### Existing
- `auth_service` (JWT)
- `servers_service` (admin pin)
- `profile_service` (user pin)

### New libraries
- Go: `github.com/livekit/server-sdk-go v2.0` — token + room mgmt
- Flutter: `livekit_client: ^2.4.0`
- Flutter: `http: ^1.2.0` for ping test (already in project)

### External
- LiveKit Cloud (or self-hosted on Hetzner) for media plane
- Cloudflare for edge DNS + health proxy
- (Optional) Hetzner / Fly.io for self-host edges later

## 7. Observability

- Metrics:
  - `flicko_voice_session_total{region,outcome}` — counter
  - `flicko_voice_region_score_ms{region,percentile}` — histogram (post-call)
  - `flicko_voice_health_failures_total{region}` — counter
  - `flicko_voice_failover_total{from,to}` — counter
  - `flicko_voice_session_duration_seconds{region}` — histogram
- Logs: WARN on health-check fail; ERROR on no-region-available
- Traces: OTel span on session-create wrapping picker → token-mint → LiveKit-call
- Dashboards: Grafana board "voice.regions" — health, load, picks, failover

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| All regions report down (false positive) | no calls | "default to na-east, accept risk" with banner |
| Single region overloaded | slow connects | mark draining; redirect joins |
| Federation breaks | cross-region calls fail | fallback: pick aggregate-best single region |
| Picker bug picks worst | bad UX | telemetry + manual override always available |
| Token expiry mid-call | disconnect | silent refresh 5 min before expiry |

## 9. Implementation Notes

### Picker scoring
```go
type Score struct { RTTms float64; LossPct float64; Jitter float64 }

// per-participant per-region score (lower = better)
func score(s Score) float64 { return s.RTTms*0.7 + s.LossPct*100*0.2 + s.Jitter*0.1 }

// pick region minimizing the worst-affected participant
func PickRegion(scores map[participantID]map[regionCode]Score, healthy []string) string {
    best := ""; bestWorst := math.Inf(1)
    for _, r := range healthy {
        worst := 0.0
        for _, byRegion := range scores {
            if s, ok := byRegion[r]; ok { worst = math.Max(worst, score(s)) }
        }
        if worst < bestWorst { bestWorst, best = worst, r }
    }
    return best
}
```

### Health check
- Run from Cloudflare Worker every 30s; cache result in KV.
- Per-region `/health` returns `{ ok: true, load: 0.34, version: "...", uptime: ... }`.
- Backend pulls KV every 30s, updates `voice_regions` table.

### Federation
- LiveKit Cloud: federation auto.
- Self-host: configure inter-cluster mesh via NATS-JetStream + media bridge.

### Token issuance
- Generate fresh per-session, 1h TTL, identity = user_id, room = channel_id, permissions = participant.
- Refresh endpoint signs a new token if user still has access.

### Mobile ping flow
```dart
Future<Map<String, Score>> pingAll(List<Region> regions) async {
  final futures = regions.map((r) => _pingOnce(r));
  final results = await Future.wait(futures, eagerError: false);
  return Map.fromIterables(regions.map((r) => r.code), results);
}

Future<Score> _pingOnce(Region r) async {
  try {
    final sw = Stopwatch()..start();
    await http.head(Uri.parse(r.healthUrl)).timeout(const Duration(milliseconds: 800));
    return Score(rttMs: sw.elapsedMilliseconds.toDouble(), lossPct: 0);
  } catch (_) { return Score(rttMs: 9999, lossPct: 100); }
}
```

## 10. Testing Strategy

- Unit (Go): picker correctness on randomized scores; assert "worst case" minimization.
- Integration: spin LiveKit dev cluster; assert tokens work cross-region.
- Load: k6 — 1000 simultaneous joins from synthetic clients across 3 regions.
- Failover drill: kill one region in staging; assert failover < 5s.
- E2E (Maestro): join voice channel from emulator with location override; assert region selected.
- Quality: post-call MoS score (Mean Opinion Score) computed; track distribution by region.
