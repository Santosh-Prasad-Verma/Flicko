-- 025_messaging_domain_tables.sql

-- 1. Create attachments table
CREATE TABLE IF NOT EXISTS public.attachments (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
  filename TEXT NOT NULL,
  size BIGINT NOT NULL,
  mime_type TEXT NOT NULL,
  url TEXT NOT NULL,
  width INTEGER,
  height INTEGER,
  is_malware BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_attachments_message_id ON public.attachments(message_id);

-- 2. Create embeds table
CREATE TABLE IF NOT EXISTS public.embeds (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
  type TEXT NOT NULL DEFAULT 'link',
  title TEXT,
  description TEXT,
  url TEXT,
  image_url TEXT,
  video_url TEXT,
  color INTEGER,
  fields JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_embeds_message_id ON public.embeds(message_id);

-- 3. Create mentions table
CREATE TABLE IF NOT EXISTS public.mentions (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
  mention_type TEXT NOT NULL CHECK (mention_type IN ('user', 'role', 'channel', 'everyone', 'here')),
  target_id UUID, -- Can be NULL for @everyone or @here
  is_read BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_mentions_message_id ON public.mentions(message_id);
CREATE INDEX idx_mentions_target_id ON public.mentions(target_id);
CREATE INDEX idx_mentions_is_read ON public.mentions(is_read);

-- 4. Create message_flags table
CREATE TABLE IF NOT EXISTS public.message_flags (
  message_id UUID PRIMARY KEY REFERENCES public.messages(id) ON DELETE CASCADE,
  is_crossposted BOOLEAN NOT NULL DEFAULT false,
  is_urgent BOOLEAN NOT NULL DEFAULT false,
  is_failed BOOLEAN NOT NULL DEFAULT false,
  is_ephemeral BOOLEAN NOT NULL DEFAULT false,
  is_loading BOOLEAN NOT NULL DEFAULT false
);

-- 5. Create message_edit_history table
CREATE TABLE IF NOT EXISTS public.message_edit_history (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  message_id UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
  previous_content TEXT NOT NULL,
  edited_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_message_edit_history_message_id ON public.message_edit_history(message_id);

-- 6. Create pinned_messages table
CREATE TABLE IF NOT EXISTS public.pinned_messages (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  channel_id UUID NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,
  message_id UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
  pinned_by UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  pinned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(channel_id, message_id)
);

CREATE INDEX idx_pinned_messages_channel_id ON public.pinned_messages(channel_id);
CREATE INDEX idx_pinned_messages_pinned_at ON public.pinned_messages(pinned_at);
