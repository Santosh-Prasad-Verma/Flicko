-- Games table
CREATE TABLE games (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  game_type   TEXT NOT NULL,
  status      TEXT NOT NULL DEFAULT 'active',  -- 'active' | 'completed' | 'abandoned'
  player_a    UUID REFERENCES users(id),
  player_b    UUID REFERENCES users(id),
  is_bot_game BOOLEAN DEFAULT FALSE,
  bot_id      UUID,
  bot_diff    TEXT,
  created_at  TIMESTAMPTZ DEFAULT now(),
  updated_at  TIMESTAMPTZ DEFAULT now()
);

-- Game state snapshots — partitioned by month for archival
CREATE TABLE game_states (
  id         UUID NOT NULL DEFAULT gen_random_uuid(),
  game_id    UUID NOT NULL REFERENCES games(id) ON DELETE CASCADE,
  state      JSONB NOT NULL,
  move_num   INTEGER NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT now()
) PARTITION BY RANGE (created_at);

-- Create partitions for next couple of months (dynamic creation needed later)
CREATE TABLE game_states_2026_05 PARTITION OF game_states FOR VALUES FROM ('2026-05-01') TO ('2026-06-01');
CREATE TABLE game_states_2026_06 PARTITION OF game_states FOR VALUES FROM ('2026-06-01') TO ('2026-07-01');

CREATE INDEX idx_game_states_game_id ON game_states (game_id, move_num DESC);
CREATE INDEX idx_games_status ON games (status) WHERE status = 'active';

-- Results table
CREATE TABLE game_results (
  id         UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  game_id    UUID REFERENCES games(id),
  winner_id  UUID,
  loser_id   UUID,
  reason     TEXT,   -- 'checkmate' | 'stalemate' | 'timeout' | 'resign' | 'abandoned' | 'draw'
  created_at TIMESTAMPTZ DEFAULT now()
);

-- Users extension (Assume users table exists, add ELO)
ALTER TABLE users ADD COLUMN IF NOT EXISTS elo INTEGER DEFAULT 1200;
