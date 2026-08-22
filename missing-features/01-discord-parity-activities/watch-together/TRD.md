# Watch Together — TRD

## Architecture

```
+------------------+       +------------------+       +------------------+
|  Flutter Client  |<----->|  Azure ACS Cloud   |<----->|  Flutter Client  |
|  (Host)          |  data |  data channel    |  data |  (Viewer)        |
|                  |  ch   |  topic: wt-sync  |  ch   |                  |
+------------------+       +------------------+       +------------------+
        |                                                       |
        | REST                                                  | REST
        v                                                       v
+--------------------------------------------------------------+
|              Go Service (Chi)  /api/v1/wt/*                  |
|  - Session create/join/leave                                 |
|  - Host election & handoff                                   |
|  - Authoritative timestamp anchor every 5s                   |
+--------------------------------------------------------------+
        |                              |                      |
        v                              v                      v
+----------------+         +----------------------+   +----------------+
| Supabase       |         | Redis (Upstash)      |   | Centrifugo     |
| Postgres       |         | wt:s:{id}:state      |   | session-events |
| wt_sessions    |         | wt:s:{id}:host       |   | for non-LK UI  |
| wt_participants|         | wt:s:{id}:viewers    |   | toasts & list  |
+----------------+         +----------------------+   +----------------+
```

## Data Plane vs Control Plane
- **Data plane (low latency)** — Voice room data channel `wt-sync`, payload SyncFrame, fan-out via SFU. Used for play/pause/seek/rate/heartbeat.
- **Control plane (durable)** — REST + Centrifugo. Used for create/join/leave, chat-level events, persisted state.

## REST Routes
Base: `/api/v1/wt`

| Method | Path | Purpose |
|---|---|---|
| POST | `/sessions` | Create a session in a voice room |
| GET | `/sessions/:id` | Fetch current state |
| PATCH | `/sessions/:id` | Update media URL or settings |
| DELETE | `/sessions/:id` | End session (host only) |
| POST | `/sessions/:id/join` | Join as viewer; returns LK token |
| POST | `/sessions/:id/leave` | Leave |
| POST | `/sessions/:id/host` | Transfer host (current host only) |
| POST | `/sessions/:id/anchor` | Host pushes authoritative anchor |
| GET | `/sessions/:id/anchor` | Late joiner pulls latest anchor |
| GET | `/rooms/:roomId/sessions` | List active sessions for a voice room |

## Payload Examples

POST `/sessions`
```json
{
  "room_id": "rm_01HX...",
  "media": {
    "kind": "youtube",
    "url": "https://youtu.be/dQw4w9WgXcQ",
    "title": "auto"
  },
  "settings": { "max_viewers": 12, "allow_seek_by_viewer": false }
}
```

Response 201
```json
{
  "id": "wt_01HX...",
  "host_user_id": "u_12",
  "azure_acs_topic": "wt-sync",
  "anchor": { "position_ms": 0, "playing": false, "rate": 1.0, "ts": 1733000000123 }
}
```

Azure ACS data payload (SyncFrame, msgpack)
```json
{
  "v": 1,
  "type": "anchor|reaction|heartbeat",
  "session_id": "wt_01HX...",
  "host_id": "u_12",
  "position_ms": 184320,
  "playing": true,
  "rate": 1.0,
  "wall_clock_ms": 1733000123456,
  "seq": 41
}
```

POST `/sessions/:id/host`
```json
{ "to_user_id": "u_45" }
```

## Drift Correction Algorithm
1. Host emits anchor every 5 s on `wt-sync` (also on every play/pause/seek).
2. Viewer computes expected position:
   `expected = anchor.position_ms + (now - anchor.wall_clock_ms) * anchor.rate`
3. If `|local - expected| > 500ms` → hard seek to `expected`.
4. If between 150 and 500 ms → adjust playback rate by ±5% for up to 4 s, then revert.
5. Below 150 ms → no action.

## Host Election
- On host disconnect (LK participant left + REST timeout 3 s), oldest joined active viewer auto-promotes.
- Tie-break: smaller `user_id` lex.
- Election notification on Centrifugo `room:{id}:wt`.

## Non-Functional Requirements
- p99 anchor delivery < 200 ms across regions (SFU advantage).
- Drift p95 < 350 ms; p50 < 150 ms.
- Cold session create p95 < 600 ms (DB write + LK token).
- Capacity per session: 12 viewers + 1 host.
- Rate limits: 60 anchors / min / host; 30 reactions / min / user.
- Session TTL: 6 h idle, 12 h hard cap.

## Observability
Counters (Prometheus, scraped by Grafana Cloud free):
- `wt_sessions_created_total{kind}`
- `wt_sessions_active`
- `wt_anchors_sent_total`
- `wt_anchors_received_total{result=ok|drift_corrected|drop}`
- `wt_drift_ms_bucket` (histogram)
- `wt_host_handoffs_total{reason=manual|election}`
- `wt_join_failures_total{reason}`

Logs: structured JSON, `session_id`, `user_id`, `seq`, `latency_ms`.

Alerts:
- Drift p95 > 750 ms over 10 min.
- Anchor publish failures > 1% over 5 min.
- Azure ACS voice token mint failures > 5/min.

## Security
- Only voice-room members can create/join.
- Host action endpoints check `host_user_id == ctx.user`.
- Media URL validated against allowlist (youtube.com, youtu.be, vimeo.com, our Appwrite bucket).
- Signed URLs for Appwrite media; viewer never sees direct URL until joined.

## Failure Modes
- Azure ACS dial failure → fall back to Centrifugo `wt-sync-fallback` channel (degrades p99 to ~400 ms).
- Redis loss → state rebuilt from Postgres + last LK message; viewers stay connected.
- Postgres write fail on anchor → retain in Redis, retry async; not blocking.
