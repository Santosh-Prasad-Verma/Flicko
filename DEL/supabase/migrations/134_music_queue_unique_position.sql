-- HIGH-3: Prevent duplicate queue positions from concurrent /play commands.
-- The bot already uses a single-statement INSERT with subquery MAX+1, but
-- without a UNIQUE constraint two concurrent inserts can still race.

CREATE TABLE IF NOT EXISTS public.music_queues (
    id               UUID        PRIMARY KEY DEFAULT gen_random_uuid(),
    server_id        UUID        NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
    title            TEXT        NOT NULL,
    url              TEXT        NOT NULL,
    duration_seconds INTEGER     DEFAULT 0,
    requested_by     UUID        REFERENCES public.profiles(id) ON DELETE SET NULL,
    position         INTEGER     NOT NULL DEFAULT 0,
    created_at       TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE UNIQUE INDEX IF NOT EXISTS idx_music_queues_server_position
  ON public.music_queues (server_id, position);

