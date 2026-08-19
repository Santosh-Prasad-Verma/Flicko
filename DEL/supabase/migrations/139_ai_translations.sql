-- 139_ai_translations.sql
-- Auto-translate per-message: cache, request log, user/server prefs, glossary.
-- See missing-features/03-ai/ai-auto-translate/SCHEMA.md
BEGIN;

CREATE TABLE IF NOT EXISTS public.translations_cache (
  id               UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  text_sha256      TEXT NOT NULL,
  src_lang         CHAR(2) NOT NULL,
  tgt_lang         CHAR(2) NOT NULL,
  translated_text  TEXT NOT NULL,
  provider         TEXT NOT NULL CHECK (provider IN ('libre','deepl','noop')),
  glossary_version INT NOT NULL DEFAULT 0,
  hit_count        INT NOT NULL DEFAULT 0,
  created_at       TIMESTAMPTZ NOT NULL DEFAULT now(),
  last_seen_at     TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (text_sha256, src_lang, tgt_lang, glossary_version)
);
CREATE INDEX IF NOT EXISTS idx_trans_cache_pair     ON public.translations_cache(src_lang, tgt_lang);
CREATE INDEX IF NOT EXISTS idx_trans_cache_lastseen ON public.translations_cache(last_seen_at);

CREATE TABLE IF NOT EXISTS public.translations_log (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  requested_by  UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  server_id     UUID REFERENCES public.servers(id) ON DELETE CASCADE,
  channel_id    UUID REFERENCES public.channels(id) ON DELETE CASCADE,
  message_id    UUID,
  text_sha256   TEXT NOT NULL,
  src_lang      CHAR(2) NOT NULL,
  tgt_lang      CHAR(2) NOT NULL,
  provider      TEXT NOT NULL,
  cached        BOOLEAN NOT NULL,
  latency_ms    INT NOT NULL,
  char_count    INT NOT NULL,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX IF NOT EXISTS idx_trans_log_user_day ON public.translations_log(requested_by, created_at);
CREATE INDEX IF NOT EXISTS idx_trans_log_server   ON public.translations_log(server_id, created_at);

CREATE TABLE IF NOT EXISTS public.translate_user_settings (
  user_id            UUID PRIMARY KEY REFERENCES auth.users(id) ON DELETE CASCADE,
  target_lang        CHAR(2) NOT NULL DEFAULT 'en',
  fluent_langs       TEXT[] NOT NULL DEFAULT ARRAY['en']::TEXT[],
  behavior           TEXT NOT NULL DEFAULT 'ask'
                     CHECK (behavior IN ('always','ask','never')),
  show_provider_chip BOOLEAN NOT NULL DEFAULT true,
  updated_at         TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE TABLE IF NOT EXISTS public.translate_server_settings (
  server_id         UUID PRIMARY KEY REFERENCES public.servers(id) ON DELETE CASCADE,
  enabled           BOOLEAN NOT NULL DEFAULT false,
  auto_translate    BOOLEAN NOT NULL DEFAULT false,
  channel_allowlist UUID[],
  glossary_version  INT NOT NULL DEFAULT 0,
  updated_at        TIMESTAMPTZ NOT NULL DEFAULT now()
);

ALTER TABLE public.translations_cache         ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.translations_log           ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.translate_user_settings    ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.translate_server_settings  ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS trans_cache_read ON public.translations_cache;
CREATE POLICY trans_cache_read ON public.translations_cache
  FOR SELECT USING (auth.role() = 'authenticated');

DROP POLICY IF EXISTS trans_log_self ON public.translations_log;
CREATE POLICY trans_log_self ON public.translations_log
  FOR SELECT USING (requested_by = auth.uid());
DROP POLICY IF EXISTS trans_log_self_insert ON public.translations_log;
CREATE POLICY trans_log_self_insert ON public.translations_log
  FOR INSERT WITH CHECK (requested_by = auth.uid());

DROP POLICY IF EXISTS trans_user_settings_self ON public.translate_user_settings;
CREATE POLICY trans_user_settings_self ON public.translate_user_settings
  FOR ALL USING (user_id = auth.uid()) WITH CHECK (user_id = auth.uid());

DROP POLICY IF EXISTS trans_server_settings_admin ON public.translate_server_settings;
CREATE POLICY trans_server_settings_admin ON public.translate_server_settings
  FOR ALL USING (
    server_id IN (SELECT server_id FROM public.server_members
                  WHERE user_id = auth.uid())
  );

GRANT SELECT, INSERT, UPDATE, DELETE
  ON public.translations_cache, public.translations_log,
     public.translate_user_settings, public.translate_server_settings
  TO authenticated;

COMMIT;
