-- =============================================================================
-- 161: Fix message INSERT access bypass via the slowmode policy
-- =============================================================================
-- PROBLEM
-- The messages table had TWO PERMISSIVE INSERT policies:
--   * "Users can send messages in accessible channels"
--       WITH CHECK (auth.uid() = author_id AND check_user_can_view_message(...))
--   * "enforce_slowmode_on_send"
--       WITH CHECK (check_slowmode_allowed(channel_id, auth.uid()))
--
-- PostgreSQL combines multiple PERMISSIVE policies for the same command with OR.
-- check_slowmode_allowed() returns TRUE whenever a channel has
-- slowmode_seconds = 0 (the default for nearly every channel), so the effective
-- INSERT check collapsed to:
--       (access control) OR TRUE  =  TRUE
-- i.e. ANY authenticated user could insert messages into ANY non-slowmode
-- channel regardless of guild membership, and could spoof author_id.
--
-- FIX
-- Slowmode is a RESTRICTION, not a grant. It must be a RESTRICTIVE policy so it
-- is AND-ed with the access-control policy instead of OR-ed:
--       (access control) AND (slowmode)
-- PERMISSIVE/RESTRICTIVE cannot be changed with ALTER POLICY, so we drop and
-- recreate. Behaviour is otherwise identical (same WITH CHECK expression).
-- =============================================================================

BEGIN;

DROP POLICY IF EXISTS enforce_slowmode_on_send ON public.messages;

CREATE POLICY enforce_slowmode_on_send
  ON public.messages
  AS RESTRICTIVE
  FOR INSERT
  TO public
  WITH CHECK (check_slowmode_allowed(channel_id, auth.uid()));

COMMENT ON POLICY enforce_slowmode_on_send ON public.messages IS
  'RESTRICTIVE: AND-ed with the access-control INSERT policy. Must stay '
  'RESTRICTIVE — as PERMISSIVE it OR-s open a membership bypass (see mig 161).';

COMMIT;
