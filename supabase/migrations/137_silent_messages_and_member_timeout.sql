-- 137_silent_messages_and_member_timeout.sql
--
-- Mirrors backend/migrations/068_infrastructure_tier1.up.sql for environments
-- provisioned via `supabase db push` (which only runs files under
-- supabase/migrations/). Without these columns, the message handler's
-- INSERT fails because the `messages.is_silent` column is missing, and
-- the timed-out-member check in the same handler errors on
-- `server_members.timeout_until`.

-- Silent messages: set by the client to suppress push notifications for a send.
ALTER TABLE public.messages
    ADD COLUMN IF NOT EXISTS is_silent BOOLEAN NOT NULL DEFAULT false;

-- Per-member temporary timeout. NULL means not timed out.
ALTER TABLE public.server_members
    ADD COLUMN IF NOT EXISTS timeout_until TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_server_members_timeout_until
    ON public.server_members (server_id, user_id)
    WHERE timeout_until IS NOT NULL;
