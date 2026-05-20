-- 026_thread_domain_tables.sql

-- 1. Create threads table
CREATE TABLE IF NOT EXISTS public.threads (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
  parent_channel_id UUID NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,
  parent_message_id UUID REFERENCES public.messages(id) ON DELETE SET NULL,
  name TEXT NOT NULL,
  creator_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type TEXT NOT NULL CHECK (type IN ('public', 'private', 'announcement')),
  message_count INTEGER NOT NULL DEFAULT 0,
  member_count INTEGER NOT NULL DEFAULT 0,
  is_archived BOOLEAN NOT NULL DEFAULT false,
  auto_archive_duration INTERVAL NOT NULL DEFAULT '24 hours'::interval,
  archive_at TIMESTAMPTZ NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_threads_server_id ON public.threads(server_id);
CREATE INDEX idx_threads_parent_channel_id ON public.threads(parent_channel_id);
CREATE INDEX idx_threads_parent_message_id ON public.threads(parent_message_id);
CREATE INDEX idx_threads_creator_id ON public.threads(creator_id);
CREATE INDEX idx_threads_is_archived ON public.threads(is_archived);
CREATE INDEX idx_threads_archive_at ON public.threads(archive_at);

-- 2. Create thread_members table
CREATE TABLE IF NOT EXISTS public.thread_members (
  thread_id UUID NOT NULL REFERENCES public.threads(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  last_read_message_id UUID REFERENCES public.messages(id) ON DELETE SET NULL,
  notification_settings JSONB NOT NULL DEFAULT '{"all_messages": false, "mentions_only": true}',
  PRIMARY KEY (thread_id, user_id)
);

CREATE INDEX idx_thread_members_user_id ON public.thread_members(user_id);
