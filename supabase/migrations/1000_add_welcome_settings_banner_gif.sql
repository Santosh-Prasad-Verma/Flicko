ALTER TABLE public.welcome_settings ADD COLUMN IF NOT EXISTS welcome_banner_url TEXT;
ALTER TABLE public.welcome_settings ADD COLUMN IF NOT EXISTS welcome_gif_url TEXT;

ALTER TABLE public.servers ADD COLUMN IF NOT EXISTS onboarding_config JSONB DEFAULT '{}'::jsonb;
