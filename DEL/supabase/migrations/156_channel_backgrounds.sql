-- Migration 156: Channel Backgrounds
-- Schema, RLS policies, and triggers for custom background images per channel.

BEGIN;

CREATE TABLE IF NOT EXISTS public.channel_backgrounds (
  id                  UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  channel_id          UUID NOT NULL UNIQUE REFERENCES public.channels(id) ON DELETE CASCADE,
  server_id           UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
  uploader_id         UUID REFERENCES public.profiles(id) ON DELETE SET NULL,

  file_id_original    TEXT NOT NULL,
  file_id_mobile      TEXT,
  file_id_blurred     TEXT,
  blurhash            TEXT NOT NULL,

  width_px            INTEGER NOT NULL,
  height_px           INTEGER NOT NULL,
  bytes_original      INTEGER NOT NULL,
  mime_type           TEXT NOT NULL CHECK (mime_type IN ('image/jpeg','image/png','image/webp')),
  sha256              TEXT NOT NULL,

  dominant_color      TEXT NOT NULL,         -- '#3A2D58'
  mean_luminance      REAL NOT NULL,         -- 0..1
  min_text_contrast   REAL,                  -- worst-case contrast vs white text
  focal_x             REAL NOT NULL DEFAULT 0.5,  -- 0..1
  focal_y             REAL NOT NULL DEFAULT 0.5,

  status              TEXT NOT NULL DEFAULT 'processing'
                       CHECK (status IN ('processing','ready','original_only','failed')),

  created_at          TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at          TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_channel_bg_server   ON public.channel_backgrounds(server_id);
CREATE INDEX IF NOT EXISTS idx_channel_bg_uploader ON public.channel_backgrounds(uploader_id);
CREATE INDEX IF NOT EXISTS idx_channel_bg_sha      ON public.channel_backgrounds(sha256);
CREATE INDEX IF NOT EXISTS idx_channel_bg_status   ON public.channel_backgrounds(status) WHERE status <> 'ready';

CREATE TABLE IF NOT EXISTS public.channel_background_blob_deletions (
  id           UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  file_id      TEXT NOT NULL,
  enqueued_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  attempts     SMALLINT NOT NULL DEFAULT 0,
  last_error   TEXT
);

CREATE INDEX IF NOT EXISTS idx_bg_deletions_pending
  ON public.channel_background_blob_deletions(enqueued_at)
  WHERE attempts < 5;

CREATE TABLE IF NOT EXISTS public.channel_background_user_overrides (
  user_id     UUID NOT NULL REFERENCES public.profiles(id) ON DELETE CASCADE,
  channel_id  UUID NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,
  opacity     REAL NOT NULL CHECK (opacity BETWEEN 0 AND 0.8),
  enabled     BOOLEAN NOT NULL DEFAULT TRUE,
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (user_id, channel_id)
);

CREATE INDEX IF NOT EXISTS idx_bg_overrides_user ON public.channel_background_user_overrides(user_id);

-- Enable Row-Level Security
ALTER TABLE public.channel_backgrounds ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.channel_background_user_overrides ENABLE ROW LEVEL SECURITY;

-- Select policies
DROP POLICY IF EXISTS "channel members can read backgrounds" ON public.channel_backgrounds;
CREATE POLICY "channel members can read backgrounds"
  ON public.channel_backgrounds FOR SELECT
  USING (
    EXISTS (
      SELECT 1 FROM public.server_members
      WHERE server_id = channel_backgrounds.server_id
        AND user_id = auth.uid()
    )
  );

-- Write policies
DROP POLICY IF EXISTS "channel admins can insert backgrounds" ON public.channel_backgrounds;
CREATE POLICY "channel admins can insert backgrounds"
  ON public.channel_backgrounds FOR INSERT
  WITH CHECK (public.has_permission(auth.uid(), channel_id, 'MANAGE_CHANNEL'));

DROP POLICY IF EXISTS "channel admins can update backgrounds" ON public.channel_backgrounds;
CREATE POLICY "channel admins can update backgrounds"
  ON public.channel_backgrounds FOR UPDATE
  USING (public.has_permission(auth.uid(), channel_id, 'MANAGE_CHANNEL'));

DROP POLICY IF EXISTS "channel admins can delete backgrounds" ON public.channel_backgrounds;
CREATE POLICY "channel admins can delete backgrounds"
  ON public.channel_backgrounds FOR DELETE
  USING (public.has_permission(auth.uid(), channel_id, 'MANAGE_CHANNEL'));

-- Overrides RLS policies
DROP POLICY IF EXISTS "users own override" ON public.channel_background_user_overrides;
CREATE POLICY "users own override"
  ON public.channel_background_user_overrides FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());

-- Triggers for updated_at
CREATE OR REPLACE FUNCTION public.fn_enqueue_bg_blob_delete() RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.channel_background_blob_deletions(file_id) VALUES
    (OLD.file_id_original);
  IF OLD.file_id_mobile IS NOT NULL THEN
    INSERT INTO public.channel_background_blob_deletions(file_id) VALUES (OLD.file_id_mobile);
  END IF;
  IF OLD.file_id_blurred IS NOT NULL THEN
    INSERT INTO public.channel_background_blob_deletions(file_id) VALUES (OLD.file_id_blurred);
  END IF;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS channel_backgrounds_after_delete ON public.channel_backgrounds;
CREATE TRIGGER channel_backgrounds_after_delete
  AFTER DELETE ON public.channel_backgrounds
  FOR EACH ROW EXECUTE FUNCTION public.fn_enqueue_bg_blob_delete();

-- Grant permissions
GRANT SELECT, INSERT, UPDATE, DELETE ON public.channel_backgrounds TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON public.channel_background_user_overrides TO authenticated;

-- Create storage bucket for channel-backgrounds
INSERT INTO storage.buckets (id, name, public)
VALUES ('channel-backgrounds', 'channel-backgrounds', true)
ON CONFLICT (id) DO NOTHING;

DROP POLICY IF EXISTS "Channel backgrounds are publicly accessible" ON storage.objects;
CREATE POLICY "Channel backgrounds are publicly accessible"
ON storage.objects FOR SELECT
USING (bucket_id = 'channel-backgrounds');

DROP POLICY IF EXISTS "Authenticated users can upload channel backgrounds" ON storage.objects;
CREATE POLICY "Authenticated users can upload channel backgrounds"
ON storage.objects FOR INSERT
WITH CHECK (
  bucket_id = 'channel-backgrounds' AND
  auth.role() = 'authenticated'
);

DROP POLICY IF EXISTS "Users can update channel backgrounds" ON storage.objects;
CREATE POLICY "Users can update channel backgrounds"
ON storage.objects FOR UPDATE
USING (
  bucket_id = 'channel-backgrounds' AND
  auth.role() = 'authenticated'
)
WITH CHECK (
  bucket_id = 'channel-backgrounds' AND
  auth.role() = 'authenticated'
);

DROP POLICY IF EXISTS "Users can delete channel backgrounds" ON storage.objects;
CREATE POLICY "Users can delete channel backgrounds"
ON storage.objects FOR DELETE
USING (
  bucket_id = 'channel-backgrounds' AND
  auth.role() = 'authenticated'
);

COMMIT;
