-- ============================================
-- Migration 116: Voice spatial settings
-- ============================================
-- Story P4-E2-S1-T1

CREATE TABLE IF NOT EXISTS public.voice_spatial_settings (
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
  channel_id UUID NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,
  spatial_enabled BOOLEAN NOT NULL DEFAULT false,
  position_x NUMERIC(8,3) NOT NULL DEFAULT 0 CHECK (position_x >= -1000 AND position_x <= 1000),
  position_y NUMERIC(8,3) NOT NULL DEFAULT 0 CHECK (position_y >= -1000 AND position_y <= 1000),
  position_z NUMERIC(8,3) NOT NULL DEFAULT 0 CHECK (position_z >= -1000 AND position_z <= 1000),
  orientation_yaw NUMERIC(8,3) NOT NULL DEFAULT 0 CHECK (orientation_yaw >= -180 AND orientation_yaw <= 180),
  gain_db NUMERIC(8,3) NOT NULL DEFAULT 0 CHECK (gain_db >= -60 AND gain_db <= 12),
  attenuation_factor NUMERIC(8,3) NOT NULL DEFAULT 1 CHECK (attenuation_factor >= 0 AND attenuation_factor <= 4),
  metadata JSONB NOT NULL DEFAULT '{}'::jsonb,
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, channel_id)
);

CREATE INDEX IF NOT EXISTS idx_voice_spatial_settings_channel
  ON public.voice_spatial_settings(channel_id, spatial_enabled);
CREATE INDEX IF NOT EXISTS idx_voice_spatial_settings_server_user
  ON public.voice_spatial_settings(server_id, user_id);

DROP TRIGGER IF EXISTS tr_voice_spatial_settings_updated_at ON public.voice_spatial_settings;
CREATE TRIGGER tr_voice_spatial_settings_updated_at
  BEFORE UPDATE ON public.voice_spatial_settings
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_updated_at();

ALTER TABLE public.voice_spatial_settings ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can read spatial settings for joined servers" ON public.voice_spatial_settings;
CREATE POLICY "Users can read spatial settings for joined servers"
  ON public.voice_spatial_settings FOR SELECT
  USING (
    EXISTS (
      SELECT 1
      FROM public.server_members sm
      WHERE sm.server_id = voice_spatial_settings.server_id
        AND sm.user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "Users can insert own spatial settings" ON public.voice_spatial_settings;
CREATE POLICY "Users can insert own spatial settings"
  ON public.voice_spatial_settings FOR INSERT
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can update own spatial settings" ON public.voice_spatial_settings;
CREATE POLICY "Users can update own spatial settings"
  ON public.voice_spatial_settings FOR UPDATE
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS "Users can delete own spatial settings" ON public.voice_spatial_settings;
CREATE POLICY "Users can delete own spatial settings"
  ON public.voice_spatial_settings FOR DELETE
  USING (user_id = auth.uid());
