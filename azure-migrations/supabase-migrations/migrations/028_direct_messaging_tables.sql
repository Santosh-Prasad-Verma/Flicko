-- 028_direct_messaging_tables.sql

-- 1. Create group_dms table
CREATE TABLE IF NOT EXISTS public.group_dms (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  name TEXT,
  icon TEXT,
  owner_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  is_active BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Create group_dm_participants table
CREATE TABLE IF NOT EXISTS public.group_dm_participants (
  group_dm_id UUID NOT NULL REFERENCES public.group_dms(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  joined_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (group_dm_id, user_id)
);

CREATE INDEX idx_group_dm_participants_user_id ON public.group_dm_participants(user_id);

-- 3. Create dm_messages table
CREATE TABLE IF NOT EXISTS public.dm_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  conversation_id UUID NOT NULL, -- Logical ID to group DMs or refer to group_dm_id
  author_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  content TEXT NOT NULL CHECK (char_length(content) <= 2000),
  type TEXT NOT NULL DEFAULT 'default' CHECK (type IN ('default', 'system', 'reply')),
  reply_to_id UUID REFERENCES public.dm_messages(id) ON DELETE SET NULL,
  edited_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_dm_messages_conversation_id ON public.dm_messages(conversation_id);
CREATE INDEX idx_dm_messages_author_id ON public.dm_messages(author_id);

-- 4. Create dm_read_states table
CREATE TABLE IF NOT EXISTS public.dm_read_states (
  conversation_id UUID NOT NULL,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  last_read_message_id UUID REFERENCES public.dm_messages(id) ON DELETE SET NULL,
  last_read_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (conversation_id, user_id)
);

CREATE INDEX idx_dm_read_states_user_id ON public.dm_read_states(user_id);
