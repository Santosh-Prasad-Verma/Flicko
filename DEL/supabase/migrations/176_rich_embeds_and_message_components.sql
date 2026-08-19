-- Migration 176: Rich Embeds & Interactive Message Components

ALTER TABLE public.messages 
ADD COLUMN IF NOT EXISTS embeds JSONB DEFAULT '[]'::JSONB,
ADD COLUMN IF NOT EXISTS components JSONB DEFAULT '[]'::JSONB;

-- Table to log interactive component callbacks (e.g. Button clicks, Dropdown selects)
CREATE TABLE IF NOT EXISTS public.message_component_interactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    message_id UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
    custom_id TEXT NOT NULL,
    user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
    selected_values TEXT[],
    created_at TIMESTAMPTZ NOT NULL DEFAULT timezone('utc'::text, now())
);

ALTER TABLE public.message_component_interactions ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users interact with message components" ON public.message_component_interactions
    FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "Users view component interactions" ON public.message_component_interactions
    FOR SELECT USING (user_id = auth.uid());
