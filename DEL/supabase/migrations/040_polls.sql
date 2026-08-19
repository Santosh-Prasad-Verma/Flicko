-- Migration 040: Polls System Tables
-- Adds support for inline polls in channels with multi-select voting and expiration.

-- ============================================================================
-- POLLS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.polls (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
  channel_id UUID NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,
  creator_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  question TEXT NOT NULL CHECK (char_length(question) BETWEEN 1 AND 500),
  allow_multiselect BOOLEAN NOT NULL DEFAULT false,
  duration_hours INTEGER,
  expires_at TIMESTAMPTZ,
  ended_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(message_id)
);

CREATE INDEX idx_polls_channel ON public.polls(channel_id);
CREATE INDEX idx_polls_creator ON public.polls(creator_id);
CREATE INDEX idx_polls_expires_at ON public.polls(expires_at) WHERE expires_at IS NOT NULL;

-- ============================================================================
-- POLL OPTIONS TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.poll_options (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  poll_id UUID NOT NULL REFERENCES public.polls(id) ON DELETE CASCADE,
  option_text TEXT NOT NULL CHECK (char_length(option_text) BETWEEN 1 AND 200),
  position INTEGER NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_poll_options_poll ON public.poll_options(poll_id);

-- ============================================================================
-- POLL VOTES TABLE
-- ============================================================================
CREATE TABLE IF NOT EXISTS public.poll_votes (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  poll_id UUID NOT NULL REFERENCES public.polls(id) ON DELETE CASCADE,
  option_id UUID NOT NULL REFERENCES public.poll_options(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  voted_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(poll_id, option_id, user_id)
);

CREATE INDEX idx_poll_votes_poll ON public.poll_votes(poll_id);
CREATE INDEX idx_poll_votes_user ON public.poll_votes(user_id);
CREATE INDEX idx_poll_votes_option ON public.poll_votes(option_id);

-- ============================================================================
-- ROW LEVEL SECURITY
-- ============================================================================
ALTER TABLE public.polls ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.poll_options ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.poll_votes ENABLE ROW LEVEL SECURITY;

-- Polls: anyone in the channel can view, creator can manage
CREATE POLICY "polls_select" ON public.polls
  FOR SELECT USING (true);

CREATE POLICY "polls_insert" ON public.polls
  FOR INSERT WITH CHECK (auth.uid() = creator_id);

CREATE POLICY "polls_update" ON public.polls
  FOR UPDATE USING (auth.uid() = creator_id);

-- Poll options: viewable by all, insertable by poll creator
CREATE POLICY "poll_options_select" ON public.poll_options
  FOR SELECT USING (true);

CREATE POLICY "poll_options_insert" ON public.poll_options
  FOR INSERT WITH CHECK (
    EXISTS (SELECT 1 FROM public.polls WHERE id = poll_id AND creator_id = auth.uid())
  );

-- Poll votes: viewable by all, users can manage their own votes
CREATE POLICY "poll_votes_select" ON public.poll_votes
  FOR SELECT USING (true);

CREATE POLICY "poll_votes_insert" ON public.poll_votes
  FOR INSERT WITH CHECK (auth.uid() = user_id);

CREATE POLICY "poll_votes_delete" ON public.poll_votes
  FOR DELETE USING (auth.uid() = user_id);
