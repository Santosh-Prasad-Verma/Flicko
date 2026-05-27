-- HIGH-3: Prevent duplicate queue positions from concurrent /play commands.
-- The bot already uses a single-statement INSERT with subquery MAX+1, but
-- without a UNIQUE constraint two concurrent inserts can still race.
CREATE UNIQUE INDEX IF NOT EXISTS idx_music_queues_server_position
  ON public.music_queues (server_id, position);
