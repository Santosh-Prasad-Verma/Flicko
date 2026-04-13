-- 027_voice_video_tables.sql

-- 1. Create voice_states table
CREATE TABLE IF NOT EXISTS public.voice_states (
  user_id UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  channel_id UUID NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,
  server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
  session_id TEXT NOT NULL UNIQUE,
  is_muted BOOLEAN NOT NULL DEFAULT false,
  is_deafened BOOLEAN NOT NULL DEFAULT false,
  is_self_muted BOOLEAN NOT NULL DEFAULT false,
  is_self_deafened BOOLEAN NOT NULL DEFAULT false,
  is_streaming BOOLEAN NOT NULL DEFAULT false,
  is_video BOOLEAN NOT NULL DEFAULT false,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_voice_states_channel_id ON public.voice_states(channel_id);
CREATE INDEX idx_voice_states_server_id ON public.voice_states(server_id);
CREATE INDEX idx_voice_states_session_id ON public.voice_states(session_id);

-- 2. Create screen_shares table
CREATE TABLE IF NOT EXISTS public.screen_shares (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  channel_id UUID NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,
  session_id TEXT NOT NULL REFERENCES public.voice_states(session_id) ON DELETE CASCADE,
  share_type TEXT NOT NULL CHECK (share_type IN ('screen', 'window', 'tab')),
  resolution TEXT NOT NULL,
  frame_rate INTEGER NOT NULL,
  viewer_count INTEGER NOT NULL DEFAULT 0,
  started_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  ended_at TIMESTAMPTZ
);

CREATE INDEX idx_screen_shares_channel_id ON public.screen_shares(channel_id);
CREATE INDEX idx_screen_shares_session_id ON public.screen_shares(session_id);
CREATE INDEX idx_screen_shares_active ON public.screen_shares(ended_at) WHERE ended_at IS NULL;

-- 3. Create drawing_strokes table
CREATE TABLE IF NOT EXISTS public.drawing_strokes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  screen_share_id UUID NOT NULL REFERENCES public.screen_shares(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  tool TEXT NOT NULL CHECK (tool IN ('pen', 'highlighter', 'eraser', 'shape')),
  color TEXT NOT NULL,
  width INTEGER NOT NULL,
  opacity NUMERIC NOT NULL CHECK (opacity >= 0 AND opacity <= 1),
  coordinates JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_drawing_strokes_screen_share_id ON public.drawing_strokes(screen_share_id);
