# Ludo - Backend Schema

**Last updated:** 2026-05-29

## 1. Tables (PostgreSQL)

All Ludo data uses the existing `games`, `game_states`, `game_results`, and `users` tables defined in `backend/migrations/070_gaming_hub_schema.up.sql`. No new tables are required for v1.

### 1.1 `games`

```sql
CREATE TABLE games (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  game_type   TEXT NOT NULL,                 -- 'ludo' | 'chess'
  status      TEXT NOT NULL DEFAULT 'active', -- 'active' | 'completed' | 'abandoned'
  player_a    UUID REFERENCES users(id),
  player_b    UUID REFERENCES users(id),
  is_bot_game BOOLEAN DEFAULT FALSE,
  bot_id      UUID,
  bot_diff    TEXT,
  created_at  TIMESTAMPTZ DEFAULT now(),
  updated_at  TIMESTAMPTZ DEFAULT now()
);
```

**Notes for Ludo:**
- `player_a` and `player_b` are the only direct FK columns; for 4-player Ludo seats 3 and 4 are tracked through `game_results` rows + the JSONB game state.
- `bot_diff` will hold `easy|medium|hard` once difficulty tiers ship (deferred to v1.3).

### 1.2 `game_states` (partitioned)

```sql
CREATE TABLE game_states (
  id         UUID NOT NULL DEFAULT gen_random_uuid(),
  game_id    UUID NOT NULL REFERENCES games(id) ON DELETE CASCADE,
  state      JSONB NOT NULL,
  move_num   INTEGER NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
) PARTITION BY RANGE (created_at);
```

**Ludo state JSONB shape:**

```json
{
  "chancePlayer": 1,
  "diceNo": 4,
  "isDiceRolled": false,
  "fireworks": false,
  "winner": null,
  "seats": [
    {"kind": "human", "userId": "...", "displayName": "Nayan"},
    {"kind": "bot", "userId": null, "displayName": "CPU"},
    {"kind": "remote", "userId": "...", "displayName": "Aurora"},
    {"kind": "remote", "userId": "...", "displayName": "Star"}
  ],
  "pieces": {
    "1": [{"id": "A1", "pos": 14, "travelCount": 14}, ...],
    "2": [{"id": "B1", "pos": 0, "travelCount": 0}, ...],
    "3": [...],
    "4": [...]
  }
}
```

### 1.3 `game_results`

```sql
CREATE TABLE game_results (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id    UUID REFERENCES games(id),
  winner_id  UUID,
  loser_id   UUID,
  reason     TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);
```

For Ludo we always set `reason = 'home_win'` (or `'abandoned'`/`'timeout'` for incomplete games). One row per (winner, loser) pair, so a 4-player game produces 3 rows.

### 1.4 `users.elo`

```sql
ALTER TABLE users ADD COLUMN IF NOT EXISTS elo INTEGER DEFAULT 1200;
```

Shared with Chess; Ludo uses simpler rules (see §3).

## 2. Endpoints

### 2.1 POST `/api/v1/gaming/ludo/score`

**Auth:** required (`userID` from JWT context).

**Request:**
```json
{
  "game_id": "<uuid or empty>",
  "winner_id": "<uuid>",
  "loser_ids": ["<uuid>", "<uuid>", "<uuid>"],
  "is_bot_game": false,
  "reason": "home_win"
}
```

**Behaviour:**
1. If `game_id` is empty, INSERT a synthetic `games` row with `game_type='ludo'`, `status='completed'`, `player_a=<userID from auth>`. Capture the new id.
2. INSERT one `game_results` row per loser (winner, loser, reason).
3. If `is_bot_game = false`: bump winner ELO by +12, decrement each loser by -8 (floor at 800).
4. COMMIT. On any failure, rollback and return `{"ok": true, "persisted": false}` so the client UX is never blocked.

**Response:**
```json
{ "ok": true, "persisted": true, "game_id": "..." }
```

### 2.2 GET `/api/v1/gaming/ludo/leaderboard`

**Auth:** none required (public read).

**Query:**
```sql
SELECT u.id, COALESCE(u.username, u.email, u.id::text) AS name,
       COALESCE(u.elo, 1200) AS elo,
       (SELECT COUNT(*) FROM game_results gr
         JOIN games g ON g.id = gr.game_id
         WHERE g.game_type = 'ludo' AND gr.winner_id = u.id) AS wins,
       (SELECT COUNT(*) FROM games g
         WHERE g.game_type = 'ludo'
           AND (g.player_a = u.id OR g.player_b = u.id)) AS total
FROM users u
ORDER BY elo DESC, wins DESC
LIMIT 50
```

**Response:**
```json
{
  "entries": [
    { "user_id": "...", "name": "NayanX", "elo": 1842, "wins": 124, "total": 198 }
  ]
}
```

### 2.3 POST `/api/v1/gaming/ludo/roll` (existing)

**Authoritative dice.** Server uses `internal/services/rng.NewRNGService()` to generate the value, persists it to the game state, broadcasts on the Centrifugo channel. Body: `{ "game_id": "..." }`. Response: `{ "dice": 4 }`.

### 2.4 POST `/api/v1/gaming/ludo/move` (existing)

**Authoritative move.** Validates against `internal/services/game/ludo_validator.go`, applies, broadcasts. Body: `{ "game_id": "...", "piece_id": "A1", "target_pos": 14 }`.

## 3. ELO algorithm

v1 is intentionally simple to keep the leaderboard moving:

- **Win** (non-bot): `elo += 12`
- **Loss** (non-bot, per loser): `elo = max(800, elo - 8)`
- **Bot games:** no change (game still recorded for stats).

This drifts upward over time; v1.2 will switch to a proper elo formula:

```
expected_a = 1 / (1 + 10^((elo_b - elo_a) / 400))
elo_a' = elo_a + K * (score_a - expected_a)   // K=24 for ranked
```

## 4. Centrifugo channels

| Channel | Direction | Payload |
|---|---|---|
| `games/<game_id>` | server -> all subscribers | `{type: "dice", playerNo, value}` |
| `games/<game_id>` | server -> all subscribers | `{type: "move", playerNo, pieceId, fromPos, toPos, travelCount}` |
| `games/<game_id>` | server -> all subscribers | `{type: "capture", playerNo, pieceId}` |
| `games/<game_id>` | server -> all subscribers | `{type: "winner", playerNo}` |
| `matchmaking/<user_id>` | server -> single user | `{type: "match_found", game_id, seats}` |

Auth is enforced through the existing centrifugo proxy hook (`/centrifugo/subscribe`) which checks the user is a participant in the game.

## 5. Migrations

No new migrations required. v1.3 may add:

```sql
-- Per-game-type ELO so Chess and Ludo don't share ratings.
ALTER TABLE users ADD COLUMN IF NOT EXISTS elo_ludo INTEGER DEFAULT 1200;
```

## 6. Indexes

Existing:
- `idx_game_states_game_id (game_id, move_num DESC)`
- `idx_games_status (status) WHERE status = 'active'`

To add when leaderboard volume grows:
```sql
CREATE INDEX idx_game_results_winner_id_lookup
  ON game_results (winner_id) INCLUDE (game_id);
CREATE INDEX idx_games_lookup
  ON games (game_type, player_a, player_b);
```
