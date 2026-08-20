-- 031_community_domain_tables.sql

-- 1. Create communities table
CREATE TABLE IF NOT EXISTS public.communities (
  server_id UUID PRIMARY KEY REFERENCES public.servers(id) ON DELETE CASCADE,
  is_verified BOOLEAN NOT NULL DEFAULT false,
  category TEXT,
  tags TEXT[],
  rules_channel_id UUID REFERENCES public.channels(id) ON DELETE SET NULL,
  member_count INTEGER NOT NULL DEFAULT 0,
  activity_score NUMERIC NOT NULL DEFAULT 0.0,
  growth_rate NUMERIC NOT NULL DEFAULT 0.0,
  is_discoverable BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_communities_is_discoverable ON public.communities(is_discoverable);
CREATE INDEX idx_communities_category ON public.communities(category);
CREATE INDEX idx_communities_activity_score ON public.communities(activity_score);
-- GIN index for tags array
CREATE INDEX idx_communities_tags ON public.communities USING GIN (tags);

-- 2. Create community_events table
CREATE TABLE IF NOT EXISTS public.community_events (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
  creator_id UUID NOT NULL REFERENCES auth.users(id),
  name TEXT NOT NULL,
  description TEXT,
  event_type TEXT NOT NULL CHECK (event_type IN ('voice', 'stage', 'external', 'text')),
  location TEXT,
  status TEXT NOT NULL DEFAULT 'scheduled' CHECK (status IN ('scheduled', 'active', 'completed', 'cancelled')),
  start_time TIMESTAMPTZ NOT NULL,
  end_time TIMESTAMPTZ,
  recurrence_rule TEXT,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_community_events_server_id ON public.community_events(server_id);
CREATE INDEX idx_community_events_start_time ON public.community_events(start_time);
CREATE INDEX idx_community_events_status ON public.community_events(status);

-- 3. Create event_participants table
CREATE TABLE IF NOT EXISTS public.event_participants (
  event_id UUID NOT NULL REFERENCES public.community_events(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status TEXT NOT NULL CHECK (status IN ('interested', 'attending')),
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (event_id, user_id)
);

CREATE INDEX idx_event_participants_user_id ON public.event_participants(user_id);

-- 4. Create announcements table
CREATE TABLE IF NOT EXISTS public.announcements (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
  channel_id UUID NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,
  author_id UUID NOT NULL REFERENCES auth.users(id),
  title TEXT NOT NULL,
  content TEXT NOT NULL,
  announcement_type TEXT NOT NULL DEFAULT 'news' CHECK (announcement_type IN ('news', 'update', 'alert', 'event')),
  priority INTEGER NOT NULL DEFAULT 0,
  is_pinned BOOLEAN NOT NULL DEFAULT false,
  view_count INTEGER NOT NULL DEFAULT 0,
  published_at TIMESTAMPTZ,
  scheduled_for TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_announcements_server_id ON public.announcements(server_id);
CREATE INDEX idx_announcements_channel_id ON public.announcements(channel_id);
CREATE INDEX idx_announcements_published_at ON public.announcements(published_at);
CREATE INDEX idx_announcements_scheduled_for ON public.announcements(scheduled_for);
