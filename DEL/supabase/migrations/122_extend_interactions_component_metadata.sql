-- ============================================
-- Migration 122: Extend interactions for component/modal payloads
-- ============================================
-- Story P6-E2-S1-T3

ALTER TABLE public.interactions
  ADD COLUMN IF NOT EXISTS interaction_kind TEXT
    CHECK (interaction_kind IN ('component', 'modal', 'context', 'file_upload')),
  ADD COLUMN IF NOT EXISTS component_payload JSONB DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS modal_payload JSONB DEFAULT '{}'::jsonb,
  ADD COLUMN IF NOT EXISTS attachment_payload JSONB DEFAULT '[]'::jsonb,
  ADD COLUMN IF NOT EXISTS source_message_id UUID REFERENCES public.messages(id) ON DELETE SET NULL;

CREATE INDEX IF NOT EXISTS idx_interactions_kind_created
  ON public.interactions(interaction_kind, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_interactions_source_message
  ON public.interactions(source_message_id)
  WHERE source_message_id IS NOT NULL;
