# Gartic Phone — TRD

## Architecture

```
+------------------+        +-------------------+        +------------------+
|  Player A        |  data  |  LiveKit Cloud    |  data  |  Player B        |
|  (Flutter)       |<------>|  topic: gp-sync   |<------>|  (Flutter)       |
+--------+---------+        +-----+-------------+        +--------+---------+
         |                        |                              |
         | REST submit            | round transition fanout      | REST submit
         v                        v                              v
+--------------------------------------------------------------+
|        Go Service /api/v1/gp/* (Chi router)                  |
|  - Session orchestrate                                       |
|  - Round controller (timer-driven)                           |
|  - Chain assembler (graph traversal)                         |
|  - Reveal builder                                            |
+--------------------------------------------------------------+
        |                              |                      |
        v                              v                      v
+----------------+         +----------------------+   +----------------+
| Postgres       |         | Redis (Upstash)      |   | Centrifugo     |
| gp_sessions    |         | gp:s:{id}:state      |   | round events   |
| gp_rounds      |         | gp:s:{id}:timer_lock |   | reveal events  |
| gp_drawings    |         | gp:s:{id}:submissions|   |                |
+----------------+         +----------------------+   +----------------+
        |
        v
+-------------------+
|  Appwrite Storage |
|  bucket gp-art    |
|  (PNG snapshots)  |
+-------------------+
```

## REST Routes
Base: `/api/v1/gp`

| Method | Path | Purpose |
|---|---|---|
| POST | `/sessions` | Create session |
| GET | `/sessions/:id` | Fetch state |
| PATCH | `/sessions/:id` | Update settings (rounds, timer) |
| DELETE | `/sessions/:id` | End |
| POST | `/sessions/:id/join` | Join lobby |
| POST | `/sessions/:id/leave` | Leave |
| POST | `/sessions/:id/start` | Host starts session |
| POST | `/sessions/:id/rounds/:roundId/submit` | Submit caption or drawing |
| GET | `/sessions/:id/rounds/:roundId/prompt` | Fetch the prompt for current player |
| GET | `/sessions/:id/reveal` | Reveal data (chains assembled) |
| POST | `/sessions/:id/reveal/react` | React to a chain step |
| POST | `/sessions/:id/report` | Report inappropriate content |

## Payload Examples

POST `/sessions`
```json
{
  "room_id": "rm_01HX...",
  "settings": {
    "round_count": 8,
    "timer_seconds": 60,
    "min_players": 4,
    "max_players": 12,
    "audience_mode": false
  }
}
```

POST `/sessions/:id/rounds/:roundId/submit` (caption)
```json
{
  "kind": "caption",
  "text": "A cat in a top hat reading the paper"
}
```

POST `/sessions/:id/rounds/:roundId/submit` (drawing)
```json
{
  "kind": "drawing",
  "strokes": [
    {"color":"#000","width":4,"points":[[10,12],[12,18],[18,22]]},
    ...
  ],
  "snapshot_storage_key": "gp/sess_id/round_id/user_id.png"
}
```

LiveKit data payload (RoundEvent)
```json
{
  "v": 1,
  "type": "round_started|round_ended|reveal_started|reveal_step",
  "session_id": "gp_01HX...",
  "round_index": 3,
  "deadline_wall_ms": 1733000189000,
  "seq": 9
}
```

GET `/sessions/:id/reveal`
```json
{
  "chains": [
    {
      "origin_user_id": "u_12",
      "steps": [
        {"kind":"caption","by":"u_12","text":"my dog wins a marathon"},
        {"kind":"drawing","by":"u_45","snapshot_url":"https://.../u_45.png"},
        {"kind":"caption","by":"u_77","text":"a goat doing yoga"}
      ]
    }
  ]
}
```

## Round Engine
- Server is the round-clock authority. Clients display a synced countdown using `deadline_wall_ms`.
- On round_start: server precomputes assignment graph. With N players over R rounds, each player gets one prompt per round; chain is a derangement so no player sees their own work.
- Submissions stored in Redis hash `gp:s:{id}:r:{roundIdx}` keyed by `user_id`.
- Round ends when all players submit OR `deadline_wall_ms` passes (timer-driven).
- Server flushes submissions to Postgres in a single transaction.
- Server emits `round_ended`; LK fans out, Centrifugo as fallback.

## Chain Assembly
- Sequence of players forms a chain: `(p0 → p1 → p2 → ... → pR-1)` where r alternates caption/drawing.
- Use a Latin square so every pair (player, round_index) is unique and each chain visits each player once.
- Origin player == receiver of final step (full circle).

## NFRs
- Round-event delivery p99 < 200 ms.
- Submission write p95 < 250 ms.
- Reveal assembly p95 < 500 ms (8 rounds × 8 players).
- Drawing payload p95 < 30 KB compressed.
- Session create p95 < 600 ms.

## Observability
Counters:
- `gp_sessions_created_total`
- `gp_sessions_completed_total`
- `gp_rounds_total{result=submitted|skipped}`
- `gp_submissions_total{kind=drawing|caption}`
- `gp_reveal_completed_total`
- `gp_reports_total`
- `gp_round_latency_ms_bucket`

Logs: `session_id`, `round_index`, `user_id`, `submission_size`.

Alerts:
- Session abandonment rate > 40% over 24 h.
- Submission failures > 2% over 10 min.

## Security
- Voice-room membership gate on create/join.
- Submission endpoint validates `(session_id, round_id, user_id)` triple matches assignment.
- Drawing payloads capped at 50 KB; reject larger.
- Inappropriate content report flow logs to admin moderation queue.
- Rate limits: 1 submission per round; 30 reactions/min.

## Failure Modes
- **Player AFK** — auto-skip on timer; chain placeholder "Missed turn" shown.
- **Submission too late** — accepted up to 2 s grace, otherwise 410 Gone.
- **Rejoin mid-round** — server returns current prompt + remaining time.
- **Reveal interrupted** — client replays from server snapshot on rejoin.
- **Drawing parse error** — fallback to PNG snapshot stored in Appwrite.
