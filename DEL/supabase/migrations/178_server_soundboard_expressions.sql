-- Migration 178: Server Soundboard Sounds & Audio Expressions

CREATE TABLE IF NOT EXISTS public.server_soundboard_sounds (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    server_id UUID NOT NULL REFERENCES public.servers(id) ON DELETE CASCADE,
    uploader_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    sound_name TEXT NOT NULL,
    audio_url TEXT NOT NULL,
    emoji TEXT NOT NULL DEFAULT '🔊',
    volume DOUBLE PRECISION NOT NULL DEFAULT 1.0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.server_soundboard_sounds ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Server members view soundboard sounds" ON public.server_soundboard_sounds
    FOR SELECT USING (
        EXISTS (
            SELECT 1 FROM public.server_members sm
            WHERE sm.server_id = server_soundboard_sounds.server_id
            AND sm.user_id = auth.uid()
        )
    );

CREATE POLICY "Server admins manage soundboard sounds" ON public.server_soundboard_sounds
    FOR ALL USING (
        EXISTS (
            SELECT 1 FROM public.servers s
            WHERE s.id = server_soundboard_sounds.server_id
            AND s.owner_id = auth.uid()
        )
    );
