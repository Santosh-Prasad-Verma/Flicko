-- 032_moderation_domain_tables.sql

-- 1. Create audit_logs table
CREATE TABLE IF NOT EXISTS public.audit_logs (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
  actor_id UUID REFERENCES auth.users(id) ON DELETE SET NULL, -- Can be null for system actions
  action_type TEXT NOT NULL,
  target_type TEXT NOT NULL,
  target_id UUID,
  reason TEXT,
  changes JSONB,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_audit_logs_server_id ON public.audit_logs(server_id);
CREATE INDEX idx_audit_logs_actor_id ON public.audit_logs(actor_id);
CREATE INDEX idx_audit_logs_action_type ON public.audit_logs(action_type);
CREATE INDEX idx_audit_logs_target_id ON public.audit_logs(target_id);

-- 2. Create auto_mod_rules table
CREATE TABLE IF NOT EXISTS public.auto_mod_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
  name TEXT NOT NULL,
  rule_type TEXT NOT NULL CHECK (rule_type IN ('spam', 'profanity', 'mentions', 'links', 'keywords')),
  trigger_config JSONB NOT NULL,
  action_type TEXT NOT NULL CHECK (action_type IN ('block', 'timeout', 'kick', 'ban')),
  action_config JSONB NOT NULL,
  exempt_roles UUID[] DEFAULT '{}',
  exempt_channels UUID[] DEFAULT '{}',
  is_enabled BOOLEAN NOT NULL DEFAULT true,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_auto_mod_rules_server_id ON public.auto_mod_rules(server_id);
CREATE INDEX idx_auto_mod_rules_is_enabled ON public.auto_mod_rules(is_enabled);

-- 3. Create reports table
CREATE TABLE IF NOT EXISTS public.reports (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id UUID REFERENCES public.servers(id) ON DELETE CASCADE, -- Can be null for global DMs
  reporter_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  report_type TEXT NOT NULL CHECK (report_type IN ('harassment', 'spam', 'inappropriate_content', 'other')),
  target_type TEXT NOT NULL CHECK (target_type IN ('message', 'user', 'server')),
  target_id UUID NOT NULL,
  description TEXT NOT NULL CHECK (char_length(description) >= 10),
  evidence JSONB,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'under_review', 'resolved', 'dismissed')),
  reviewed_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  reviewed_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_reports_server_id ON public.reports(server_id);
CREATE INDEX idx_reports_reporter_id ON public.reports(reporter_id);
CREATE INDEX idx_reports_status ON public.reports(status);
CREATE INDEX idx_reports_target_id ON public.reports(target_id);

-- 4. Create warnings table
CREATE TABLE IF NOT EXISTS public.warnings (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  moderator_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  reason TEXT NOT NULL,
  severity TEXT NOT NULL DEFAULT 'low' CHECK (severity IN ('low', 'medium', 'high', 'critical')),
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX idx_warnings_server_id ON public.warnings(server_id);
CREATE INDEX idx_warnings_user_id ON public.warnings(user_id);
CREATE INDEX idx_warnings_moderator_id ON public.warnings(moderator_id);
