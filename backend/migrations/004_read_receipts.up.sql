CREATE TABLE IF NOT EXISTS public.read_states (
    channel_id UUID NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    last_read_message_id UUID NOT NULL REFERENCES public.messages(id) ON DELETE CASCADE,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW(),
    
    -- Prevents multiple read trackers in the same channel for the same user
    -- Allows ON CONFLICT to seamlessly UPDATE
    PRIMARY KEY (channel_id, user_id)
);

-- Index user_id for fetching a user's unread badges across their sidebar
CREATE INDEX idx_read_states_user_id ON public.read_states(user_id);
