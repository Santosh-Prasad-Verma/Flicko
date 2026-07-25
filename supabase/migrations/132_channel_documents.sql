-- 132_channel_documents.sql
-- Create channel_documents table for Yjs CRDT real-time collaborative document editing

CREATE TABLE IF NOT EXISTS public.channel_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    channel_id UUID NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,
    title VARCHAR(255) NOT NULL DEFAULT 'Untitled Document',
    state_vector BYTEA,
    ydoc_binary BYTEA,
    created_by UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Index for fast channel document lookup
CREATE INDEX IF NOT EXISTS idx_channel_documents_channel_id ON public.channel_documents(channel_id);

-- RLS Security Policies
ALTER TABLE public.channel_documents ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view documents in channels they belong to"
    ON public.channel_documents FOR SELECT
    USING (auth.uid() IN (
        SELECT user_id FROM public.channel_members WHERE channel_id = public.channel_documents.channel_id
    ));

CREATE POLICY "Users can update documents in channels they belong to"
    ON public.channel_documents FOR UPDATE
    USING (auth.uid() IN (
        SELECT user_id FROM public.channel_members WHERE channel_id = public.channel_documents.channel_id
    ));

CREATE POLICY "Users can create documents in channels they belong to"
    ON public.channel_documents FOR INSERT
    WITH CHECK (auth.uid() IN (
        SELECT user_id FROM public.channel_members WHERE channel_id = public.channel_documents.channel_id
    ));
