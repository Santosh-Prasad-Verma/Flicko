# Karaoke Night — TRD

## Architecture

```
+------------------+        +-------------------+        +------------------+
|  Singer (Flutter)|  audio |  LiveKit Cloud    |  audio |  Listener        |
|  mic publish     |<------>|  (voice channel + |<------>|  ear monitor +   |
|                  |  data  |   data: kk-sync)  |  data  |  lyric sync      |
+--------+---------+        +-----+-------------+        +------------------+
         |                        |
         | publish mix to         | data anchors (lyric line idx, ts)
         | recording egress       |
         v                        v
+----------------+        +-------------------+        +-------------------+
| LiveKit Egress |  WAV   | Go API /api/v1/kk |<-----> | Postgres          |
| (track recorder|------->|                   |        | karaoke_*         |
|   to S3-compat |        +---+---------------+        +-------------------+
|   = Appwrite)  |            |
+----------------+            v
                       +-------------------+
                       |  Pitch Worker     |
                       |  Python+librosa   |
                       |  (Fly.io free VM) |
                       |  redis queue:     |
                       |  kk:score:jobs    |
                       +---+---------------+
                           |
                           v
                       returns score JSON to API
                           |
                           v
                       Centrifugo broadcast "score-ready"
```

## REST Routes
Base: `/api/v1/kk`

| Method | Path | Purpose |
|---|---|---|
| POST | `/sessions` | Create session in voice room |
| GET | `/sessions/:id` | Fetch state |
| PATCH | `/sessions/:id` | Update settings (rotation, scoring_visibility) |
| DELETE | `/sessions/:id` | End session |
| POST | `/sessions/:id/join` | Join as listener |
| POST | `/sessions/:id/queue` | Sign up to sing a song |
| GET | `/sessions/:id/queue` | Singer queue |
| DELETE | `/sessions/:id/queue/:itemId` | Drop from queue |
| POST | `/sessions/:id/start` | Start currently-cued song (host or singer) |
| POST | `/sessions/:id/stop` | Stop early |
| POST | `/sessions/:id/anchor` | Singer pushes lyric anchor (line index + ts) |
| GET | `/songs` | Search catalog |
| GET | `/songs/:id` | Get song with LRC + backing track URL |
| POST | `/songs` | Upload user song (admin reviewed) |
| POST | `/sessions/:id/scoring/result` | Internal: pitch worker returns score |
| GET | `/sessions/:id/leaderboard` | Aggregate scores for voice room |

## Payload Examples

POST `/sessions/:id/queue`
```json
{
  "song_id": "song_creep_radiohead_pd",
  "user_id": "u_12",
  "stealth": false
}
```

LiveKit data payload (LyricAnchor)
```json
{
  "v": 1,
  "type": "lyric_anchor|state|cue|score_ready",
  "session_id": "kk_01HX...",
  "song_id": "song_creep_radiohead_pd",
  "line_index": 14,
  "line_position_ms": 3420,
  "wall_clock_ms": 1733000123456,
  "seq": 88
}
```

POST `/sessions/:id/scoring/result` (internal)
```json
{
  "session_id": "kk_01HX...",
  "song_id": "song_creep_radiohead_pd",
  "singer_user_id": "u_12",
  "score": 84,
  "breakdown": {
    "pitch_accuracy": 0.82,
    "timing": 0.86,
    "completeness": 0.91
  },
  "duration_ms": 198400
}
```

## Pitch Scoring Worker
- Language: Python 3.11, libs `librosa`, `numpy`, `scipy`, `redis`.
- Runs on Fly.io free VM (256 MB RAM is tight; cap concurrent jobs at 1).
- Input: mono 16 kHz WAV from Egress (LiveKit records track to Appwrite Storage), reference pitch sequence from song's LRC + MIDI guide track.
- Pipeline: VAD → pitch estimate (pyin) → DTW align to reference → per-line accuracy → weighted score.
- Output: 0-100 + breakdown.
- Job queue: Redis list `kk:score:jobs`; worker pops, processes, posts to API.

## NFRs
- Lyric anchor delivery p99 < 200 ms.
- Lyric drift p95 across listeners < 250 ms.
- Session create p95 < 600 ms.
- Score job p95 end-to-end (song end to score broadcast) < 10 s.
- Catalog search p95 < 250 ms.
- Worker queue depth alarm at > 5.

## Observability
Counters:
- `kk_sessions_created_total`
- `kk_songs_played_total{result=completed|skipped|errored}`
- `kk_score_jobs_total{result=ok|fail|timeout}`
- `kk_score_latency_seconds_bucket`
- `kk_lyric_drift_ms_bucket`
- `kk_singer_signups_total`
- `kk_catalog_search_total`

Logs: `session_id`, `song_id`, `singer_user_id`, `score`, `worker_node`.

Alerts:
- Score job failure rate > 5% over 10 min.
- Worker queue depth > 5 for > 2 min.
- Lyric drift p95 > 400 ms.

## Security
- Backing track URLs signed (Appwrite tokens, 30 min TTL).
- Egress recording bucket private; only worker has read.
- User uploads attestation logged; admin review queue before catalog publish.
- Rate limits: 10 catalog searches / 10 s / user; 1 sign-up / 10 s / user.

## Failure Modes
- **Worker offline** — Score returned as `pending`, retried on worker recovery; user sees "Scoring..." indicator that resolves later.
- **LRC missing** — Song flagged unscoreable, only scrolling lyrics; "Score not available for this track".
- **Singer mic drop** — auto-stop song after 5 s of silence; partial score with `completeness` reflecting it.
- **Song longer than 6 min** — clipped at 6 min on free tier to keep worker job manageable.
- **Egress fails** — fall back to no scoring; song still played, lyrics still scroll.
