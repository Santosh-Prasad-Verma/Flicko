-- 083_schema_alignment.up.sql
-- Aligns servers, channels, and server_members tables for complete backend and frontend compatibility.

-- 1. Servers table columns
ALTER TABLE public.servers
  ADD COLUMN IF NOT EXISTS icon_url TEXT,
  ADD COLUMN IF NOT EXISTS banner_url TEXT,
  ADD COLUMN IF NOT EXISTS system_channel_id UUID,
  ADD COLUMN IF NOT EXISTS rules_channel_id UUID,
  ADD COLUMN IF NOT EXISTS public_updates_channel_id UUID,
  ADD COLUMN IF NOT EXISTS preferred_locale TEXT DEFAULT 'en-US',
  ADD COLUMN IF NOT EXISTS default_message_notifications INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS explicit_content_filter INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS mfa_level INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS nsfw_level INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS premium_tier INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS premium_subscription_count INTEGER DEFAULT 0,
  ADD COLUMN IF NOT EXISTS vanity_url_code TEXT,
  ADD COLUMN IF NOT EXISTS discovery_enabled BOOLEAN DEFAULT FALSE;

-- 2. Sync icon/banner with icon_url/banner_url
UPDATE public.servers SET icon_url = icon WHERE icon_url IS NULL AND icon IS NOT NULL;
UPDATE public.servers SET banner_url = banner WHERE banner_url IS NULL AND banner IS NOT NULL;

CREATE OR REPLACE FUNCTION sync_server_icon_banner()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.icon_url IS NOT NULL AND NEW.icon IS NULL THEN
    NEW.icon := NEW.icon_url;
  ELSIF NEW.icon IS NOT NULL AND NEW.icon_url IS NULL THEN
    NEW.icon_url := NEW.icon;
  END IF;

  IF NEW.banner_url IS NOT NULL AND NEW.banner IS NULL THEN
    NEW.banner := NEW.banner_url;
  ELSIF NEW.banner IS NOT NULL AND NEW.banner_url IS NULL THEN
    NEW.banner_url := NEW.banner;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS tr_sync_server_icon_banner ON public.servers;
CREATE TRIGGER tr_sync_server_icon_banner
BEFORE INSERT OR UPDATE ON public.servers
FOR EACH ROW EXECUTE FUNCTION sync_server_icon_banner();

-- 3. Channels table columns
ALTER TABLE public.channels
  ADD COLUMN IF NOT EXISTS default_thread_auto_archive INTEGER DEFAULT 4320;

-- 4. Server members table columns
ALTER TABLE public.server_members
  ADD COLUMN IF NOT EXISTS timeout_until TIMESTAMPTZ;
