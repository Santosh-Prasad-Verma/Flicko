-- Migration 168: Private User Notes table and RLS policies

CREATE TABLE IF NOT EXISTS public.user_notes (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    target_user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    owner_id UUID REFERENCES auth.users(id) ON DELETE CASCADE,
    target_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE,
    note TEXT,
    content TEXT,
    created_at TIMESTAMPTZ DEFAULT NOW(),
    updated_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE public.user_notes ADD COLUMN IF NOT EXISTS user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE;
ALTER TABLE public.user_notes ADD COLUMN IF NOT EXISTS target_user_id UUID REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE public.user_notes ADD COLUMN IF NOT EXISTS note TEXT;

UPDATE public.user_notes SET user_id = owner_id WHERE user_id IS NULL AND owner_id IS NOT NULL;
UPDATE public.user_notes SET target_user_id = target_id WHERE target_user_id IS NULL AND target_id IS NOT NULL;
UPDATE public.user_notes SET note = content WHERE note IS NULL AND content IS NOT NULL;

ALTER TABLE public.user_notes ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "Users can manage their own private notes" ON public.user_notes;

CREATE POLICY "Users can manage their own private notes"
ON public.user_notes FOR ALL
USING (auth.uid() = COALESCE(user_id, owner_id))
WITH CHECK (auth.uid() = COALESCE(user_id, owner_id));
