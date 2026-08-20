-- 030_server_management_tables.sql

-- 1. Create invites table
DROP TABLE IF EXISTS public.invites CASCADE;
CREATE TABLE IF NOT EXISTS public.invites (
  code TEXT PRIMARY KEY,
  server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
  channel_id UUID REFERENCES public.channels(id) ON DELETE CASCADE,
  inviter_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  max_uses INTEGER NOT NULL DEFAULT 0,
  uses INTEGER NOT NULL DEFAULT 0,
  expires_at TIMESTAMPTZ,
  is_expired BOOLEAN NOT NULL DEFAULT false,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_invites_server_id ON public.invites(server_id);
CREATE INDEX idx_invites_channel_id ON public.invites(channel_id);
CREATE INDEX idx_invites_inviter_id ON public.invites(inviter_id);

-- 2. Create invite_usage table
CREATE TABLE IF NOT EXISTS public.invite_usage (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  invite_code TEXT NOT NULL, -- Logical reference
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  used_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_invite_usage_invite_code ON public.invite_usage(invite_code);
CREATE INDEX idx_invite_usage_user_id ON public.invite_usage(user_id);

-- 3. Create stickers table
CREATE TABLE IF NOT EXISTS public.stickers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  description TEXT,
  tags TEXT[],
  image_url TEXT NOT NULL,
  creator_id UUID NOT NULL REFERENCES auth.users(id),
  usage_count INTEGER NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_stickers_server_id ON public.stickers(server_id);
CREATE INDEX idx_stickers_creator_id ON public.stickers(creator_id);

-- 4. Create server_templates table
CREATE TABLE IF NOT EXISTS public.server_templates (
  code TEXT PRIMARY KEY,
  source_server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
  creator_id UUID NOT NULL REFERENCES auth.users(id),
  name TEXT NOT NULL,
  description TEXT,
  usage_count INTEGER NOT NULL DEFAULT 0,
  template_data JSONB NOT NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_server_templates_source_server_id ON public.server_templates(source_server_id);
CREATE INDEX idx_server_templates_creator_id ON public.server_templates(creator_id);

-- 5. Create permission_overwrites table
CREATE TABLE IF NOT EXISTS public.permission_overwrites (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  channel_id UUID NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,
  target_type TEXT NOT NULL CHECK (target_type IN ('role', 'user')),
  target_id UUID NOT NULL, -- References either roles(id) or users(id)
  allow BIGINT NOT NULL DEFAULT 0,
  deny BIGINT NOT NULL DEFAULT 0,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(channel_id, target_type, target_id)
);

CREATE INDEX idx_permission_overwrites_channel_id ON public.permission_overwrites(channel_id);
CREATE INDEX idx_permission_overwrites_target_id ON public.permission_overwrites(target_id);

-- 6. Create member_roles table
CREATE TABLE IF NOT EXISTS public.member_roles (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  role_id UUID NOT NULL REFERENCES public.roles(id) ON DELETE CASCADE,
  assigned_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  UNIQUE(user_id, role_id)
);

CREATE INDEX idx_member_roles_server_id ON public.member_roles(server_id);
CREATE INDEX idx_member_roles_user_id ON public.member_roles(user_id);
CREATE INDEX idx_member_roles_role_id ON public.member_roles(role_id);
