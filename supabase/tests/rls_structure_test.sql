-- =============================================================================
-- pgTAP: RLS STRUCTURAL GUARDS
-- =============================================================================
-- Fast, seed-free assertions about the *shape* of the security model:
--   1. RLS is actually enabled on every security-critical table.
--   2. The SECURITY DEFINER helper functions that break the server_members
--      recursion cycle exist and are still SECURITY DEFINER.
--
-- Why this matters: migrations 081 / 155 / 159 fixed infinite-recursion in the
-- server_members RLS policy by moving the membership check into a
-- SECURITY DEFINER function (is_server_member). If someone ever redefines that
-- function as SECURITY INVOKER, or references server_members directly in the
-- policy again, the recursion returns as a 500 at runtime. These tests fail
-- loudly at CI time instead.
--
-- Run: supabase test db
-- =============================================================================

BEGIN;

SELECT plan(14);

-- --- RLS enabled on the core guild/permission tables ------------------------
SELECT ok(
  (SELECT relrowsecurity FROM pg_class WHERE oid = 'public.servers'::regclass),
  'RLS is enabled on servers'
);
SELECT ok(
  (SELECT relrowsecurity FROM pg_class WHERE oid = 'public.server_members'::regclass),
  'RLS is enabled on server_members'
);
SELECT ok(
  (SELECT relrowsecurity FROM pg_class WHERE oid = 'public.channels'::regclass),
  'RLS is enabled on channels'
);
SELECT ok(
  (SELECT relrowsecurity FROM pg_class WHERE oid = 'public.messages'::regclass),
  'RLS is enabled on messages'
);
SELECT ok(
  (SELECT relrowsecurity FROM pg_class WHERE oid = 'public.roles'::regclass),
  'RLS is enabled on roles'
);

-- --- The anti-recursion helper functions exist ------------------------------
SELECT has_function(
  'public', 'is_server_member', ARRAY['uuid','uuid'],
  'is_server_member(uuid, uuid) exists'
);
SELECT has_function(
  'public', 'has_server_permission', ARRAY['uuid','uuid','text'],
  'has_server_permission(uuid, uuid, text) exists'
);
SELECT has_function(
  'public', 'check_user_can_view_message', ARRAY['uuid','uuid'],
  'check_user_can_view_message(uuid, uuid) exists'
);
SELECT has_function(
  'public', 'check_slowmode_allowed', ARRAY['uuid','uuid'],
  'check_slowmode_allowed(uuid, uuid) exists'
);

-- --- ...and are still SECURITY DEFINER (the actual recursion fix) ------------
-- If any of these flips to INVOKER, the RLS policy that calls it will hit
-- server_members under RLS again and recurse. This is the regression guard.
SELECT ok(
  (SELECT prosecdef FROM pg_proc
     WHERE oid = 'public.is_server_member(uuid,uuid)'::regprocedure),
  'is_server_member is SECURITY DEFINER (breaks recursion cycle)'
);
SELECT ok(
  (SELECT prosecdef FROM pg_proc
     WHERE oid = 'public.has_server_permission(uuid,uuid,text)'::regprocedure),
  'has_server_permission is SECURITY DEFINER'
);
SELECT ok(
  (SELECT prosecdef FROM pg_proc
     WHERE oid = 'public.check_user_can_view_message(uuid,uuid)'::regprocedure),
  'check_user_can_view_message is SECURITY DEFINER'
);

-- --- server_members must keep a SELECT policy that does NOT self-reference ---
-- The SELECT policy should route through is_server_member(), not an inline
-- EXISTS against server_members (which is what caused the recursion).
SELECT ok(
  EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'server_members'
      AND cmd = 'SELECT'
      AND qual LIKE '%is_server_member%'
  ),
  'server_members SELECT policy routes through is_server_member() helper'
);
SELECT ok(
  NOT EXISTS (
    SELECT 1 FROM pg_policies
    WHERE schemaname = 'public'
      AND tablename = 'server_members'
      AND cmd = 'SELECT'
      AND qual ~* 'FROM\s+server_members'
  ),
  'server_members SELECT policy does NOT inline-reference server_members (no recursion)'
);

SELECT * FROM finish();

ROLLBACK;
