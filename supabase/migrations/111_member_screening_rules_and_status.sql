-- ============================================
-- Migration 111: Member screening rules and status
-- ============================================
-- Story P3-E1-S2-T3

CREATE TABLE IF NOT EXISTS public.screening_rules (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
  title TEXT NOT NULL,
  description TEXT,
  is_required BOOLEAN NOT NULL DEFAULT TRUE,
  position INTEGER NOT NULL DEFAULT 0,
  is_enabled BOOLEAN NOT NULL DEFAULT TRUE,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_by UUID REFERENCES auth.users(id) ON DELETE SET NULL,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_screening_rules_server_id
  ON public.screening_rules(server_id, is_enabled, position);

DROP TRIGGER IF EXISTS tr_screening_rules_updated_at ON public.screening_rules;
CREATE TRIGGER tr_screening_rules_updated_at
  BEFORE UPDATE ON public.screening_rules
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

CREATE TABLE IF NOT EXISTS public.member_screening_status (
  server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  status TEXT NOT NULL DEFAULT 'pending' CHECK (status IN ('pending', 'accepted')),
  accepted_at TIMESTAMPTZ,
  last_prompted_at TIMESTAMPTZ,
  accepted_rules JSONB NOT NULL DEFAULT '[]'::jsonb,
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (server_id, user_id)
);

CREATE INDEX IF NOT EXISTS idx_member_screening_status_user_id
  ON public.member_screening_status(user_id, status);

DROP TRIGGER IF EXISTS tr_member_screening_status_updated_at ON public.member_screening_status;
CREATE TRIGGER tr_member_screening_status_updated_at
  BEFORE UPDATE ON public.member_screening_status
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.screening_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.member_screening_status ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read screening rules for joined servers" ON public.screening_rules;
CREATE POLICY "Users can read screening rules for joined servers"
  ON public.screening_rules FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM public.server_members sm
      WHERE sm.server_id = screening_rules.server_id
        AND sm.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Server owners can create screening rules" ON public.screening_rules;
CREATE POLICY "Server owners can create screening rules"
  ON public.screening_rules FOR INSERT
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.servers s
      WHERE s.id = screening_rules.server_id
        AND s.owner_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Server owners can update screening rules" ON public.screening_rules;
CREATE POLICY "Server owners can update screening rules"
  ON public.screening_rules FOR UPDATE
  USING (
    EXISTS (
      SELECT 1
      FROM public.servers s
      WHERE s.id = screening_rules.server_id
        AND s.owner_id = auth.uid()
    )
  )
  WITH CHECK (
    EXISTS (
      SELECT 1
      FROM public.servers s
      WHERE s.id = screening_rules.server_id
        AND s.owner_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Server owners can delete screening rules" ON public.screening_rules;
CREATE POLICY "Server owners can delete screening rules"
  ON public.screening_rules FOR DELETE
  USING (
    EXISTS (
      SELECT 1
      FROM public.servers s
      WHERE s.id = screening_rules.server_id
        AND s.owner_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can read own member screening status" ON public.member_screening_status;
CREATE POLICY "Users can read own member screening status"
  ON public.member_screening_status FOR SELECT
  USING (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can create own member screening status" ON public.member_screening_status;
CREATE POLICY "Users can create own member screening status"
  ON public.member_screening_status FOR INSERT
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can update own member screening status" ON public.member_screening_status;
CREATE POLICY "Users can update own member screening status"
  ON public.member_screening_status FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete own member screening status" ON public.member_screening_status;
CREATE POLICY "Users can delete own member screening status"
  ON public.member_screening_status FOR DELETE
  USING (user_id = auth.uid());
