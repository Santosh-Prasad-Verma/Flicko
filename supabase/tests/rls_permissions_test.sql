-- =============================================================================
-- pgTAP: RLS BEHAVIORAL ENFORCEMENT
-- =============================================================================
-- Seeds real users + a guild, then switches to the `authenticated` role and
-- impersonates each user via request.jwt.claims (exactly how Supabase sets
-- auth.uid()). Asserts that RLS lets the right rows through and blocks the rest.
--
-- Covers (from the QA master plan, BDD-4):
--   * Non-member cannot read a private guild's messages / members / channels
--   * Owner and members CAN read their guild
--   * A member listing co-members does NOT trigger recursion (runtime guard
--     for the migration 081/155/159 bug)
--   * Users can only delete their OWN messages
--
-- Test actors (fixed UUIDs so assertions are readable):
--   OWNER   11111111-...  owns guild "Test Guild"
--   MEMBER  22222222-...  joined the guild
--   OUTSIDER 33333333-... NOT a member
--
-- Run: supabase test db
-- =============================================================================

BEGIN;

SELECT plan(10);

-- ---------------------------------------------------------------------------
-- Helper: impersonate an authenticated user the way Supabase/GoTrue does.
-- ---------------------------------------------------------------------------
CREATE OR REPLACE FUNCTION pg_temp.login_as(uid uuid) RETURNS void AS $$
BEGIN
  PERFORM set_config('role', 'authenticated', true);
  PERFORM set_config(
    'request.jwt.claims',
    json_build_object('sub', uid::text, 'role', 'authenticated')::text,
    true
  );
END;
$$ LANGUAGE plpgsql;

CREATE OR REPLACE FUNCTION pg_temp.logout() RETURNS void AS $$
BEGIN
  PERFORM set_config('role', 'postgres', true);
  PERFORM set_config('request.jwt.claims', NULL, true);
END;
$$ LANGUAGE plpgsql;

-- ---------------------------------------------------------------------------
-- Seed fixtures as superuser (RLS is bypassed for the table owner here).
-- profiles.id -> auth.users, so auth.users rows must exist first.
--
-- session_replication_role = replica disables ALL triggers for the seed phase.
-- The schema fires triggers on insert (e.g. on_auth_user_created auto-creates a
-- profiles row from auth.users; other tables may auto-populate members, etc.),
-- which collide with our explicit fixture rows. Suppressing them for seeding
-- lets us insert exactly the rows we want; we restore DEFAULT before the
-- assertions so RLS and real behaviour are exercised normally.
-- (Allowed here because pgTAP runs the test as superuser.)
-- ---------------------------------------------------------------------------
SET session_replication_role = replica;

INSERT INTO auth.users (instance_id, id, aud, role, email, encrypted_password,
                        email_confirmed_at, created_at, updated_at,
                        raw_app_meta_data, raw_user_meta_data)
VALUES
  ('00000000-0000-0000-0000-000000000000', '11111111-1111-1111-1111-111111111111',
   'authenticated', 'authenticated', 'owner@test.dev', '', now(), now(), now(), '{}', '{}'),
  ('00000000-0000-0000-0000-000000000000', '22222222-2222-2222-2222-222222222222',
   'authenticated', 'authenticated', 'member@test.dev', '', now(), now(), now(), '{}', '{}'),
  ('00000000-0000-0000-0000-000000000000', '33333333-3333-3333-3333-333333333333',
   'authenticated', 'authenticated', 'outsider@test.dev', '', now(), now(), now(), '{}', '{}');

-- discriminator is provided explicitly rather than relying on a column default,
-- so the seed is self-contained regardless of which migration adds that default.
-- ON CONFLICT: the on_auth_user_created trigger (migration 017) auto-inserts a
-- profiles row when we seed auth.users above, so the row already exists. Upsert
-- to force our known username/discriminator regardless of what the trigger set.
INSERT INTO public.profiles (id, username, discriminator, email) VALUES
  ('11111111-1111-1111-1111-111111111111', 'owner',    '0001', 'owner@test.dev'),
  ('22222222-2222-2222-2222-222222222222', 'member',   '0002', 'member@test.dev'),
  ('33333333-3333-3333-3333-333333333333', 'outsider', '0003', 'outsider@test.dev')
ON CONFLICT (id) DO UPDATE
  SET username = EXCLUDED.username,
      discriminator = EXCLUDED.discriminator,
      email = EXCLUDED.email;

INSERT INTO public.servers (id, name, owner_id) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'Test Guild',
   '11111111-1111-1111-1111-111111111111');

INSERT INTO public.server_members (server_id, user_id) VALUES
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '11111111-1111-1111-1111-111111111111'),
  ('aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', '22222222-2222-2222-2222-222222222222');

INSERT INTO public.channels (id, server_id, name, type, user_limit) VALUES
  ('cccccccc-cccc-cccc-cccc-cccccccccccc',
   'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa', 'general', 'text', 0);

INSERT INTO public.messages (id, channel_id, author_id, content) VALUES
  ('dddddddd-dddd-dddd-dddd-dddddddddddd',
   'cccccccc-cccc-cccc-cccc-cccccccccccc',
   '11111111-1111-1111-1111-111111111111', 'owner message'),
  ('eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee',
   'cccccccc-cccc-cccc-cccc-cccccccccccc',
   '22222222-2222-2222-2222-222222222222', 'member message');

-- Seed phase complete. Restore triggers BEFORE switching roles (only the
-- superuser can reset this; once we login_as authenticated we cannot).
SET session_replication_role = DEFAULT;

-- Ensure the authenticated/anon roles hold base table privileges. On a clean
-- CI build from committed migrations these GRANTs may be missing (prod has them
-- from out-of-band setup), which surfaces as "permission denied for table"
-- rather than an RLS decision. Granting here (as superuser, rolled back with
-- the txn) lets RLS — not missing privileges — be what the assertions measure.
GRANT USAGE ON SCHEMA public TO authenticated, anon;
GRANT SELECT, INSERT, UPDATE, DELETE ON ALL TABLES IN SCHEMA public TO authenticated;
GRANT SELECT ON ALL TABLES IN SCHEMA public TO anon;

-- ===========================================================================
-- SCENARIO A: A member can read their guild's channels (no recursion).
-- ===========================================================================
SELECT pg_temp.login_as('22222222-2222-2222-2222-222222222222');

SELECT is(
  (SELECT count(*)::int FROM public.channels
     WHERE server_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  1,
  'MEMBER can see the 1 channel in their guild'
);

-- RECURSION REGRESSION GUARD (runtime): listing co-members must return rows,
-- not error out with "infinite recursion detected in policy".
SELECT is(
  (SELECT count(*)::int FROM public.server_members
     WHERE server_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  2,
  'MEMBER can list all 2 co-members without RLS recursion'
);

SELECT is(
  (SELECT count(*)::int FROM public.messages
     WHERE channel_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'),
  2,
  'MEMBER can read both messages in an accessible channel'
);

-- ===========================================================================
-- SCENARIO B: An outsider is blocked from the private guild's data.
-- ===========================================================================
SELECT pg_temp.login_as('33333333-3333-3333-3333-333333333333');

SELECT is(
  (SELECT count(*)::int FROM public.channels
     WHERE server_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  0,
  'OUTSIDER cannot see any channels in a guild they are not a member of'
);

SELECT is(
  (SELECT count(*)::int FROM public.messages
     WHERE channel_id = 'cccccccc-cccc-cccc-cccc-cccccccccccc'),
  0,
  'OUTSIDER cannot read messages in an inaccessible channel'
);

SELECT is(
  (SELECT count(*)::int FROM public.server_members
     WHERE server_id = 'aaaaaaaa-aaaa-aaaa-aaaa-aaaaaaaaaaaa'),
  0,
  'OUTSIDER cannot enumerate members of a guild they are not in'
);

-- ===========================================================================
-- SCENARIO C: Message ownership on delete (BDD-4 scenario 2).
-- ===========================================================================
-- MEMBER attempts to delete the OWNER's message -> RLS USING(author_id=uid)
-- filters the row out, so 0 rows are affected (message survives).
SELECT pg_temp.login_as('22222222-2222-2222-2222-222222222222');

DELETE FROM public.messages
  WHERE id = 'dddddddd-dddd-dddd-dddd-dddddddddddd';  -- owner's message

SELECT pg_temp.logout();
SELECT is(
  (SELECT count(*)::int FROM public.messages
     WHERE id = 'dddddddd-dddd-dddd-dddd-dddddddddddd'),
  1,
  'MEMBER cannot delete another user''s message (row survives)'
);

-- MEMBER deletes their OWN message -> succeeds.
SELECT pg_temp.login_as('22222222-2222-2222-2222-222222222222');

DELETE FROM public.messages
  WHERE id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee';  -- member's own message

SELECT pg_temp.logout();
SELECT is(
  (SELECT count(*)::int FROM public.messages
     WHERE id = 'eeeeeeee-eeee-eeee-eeee-eeeeeeeeeeee'),
  0,
  'MEMBER can delete their own message'
);

-- ===========================================================================
-- SCENARIO D: Insert authorization on messages.
-- ===========================================================================
-- OUTSIDER cannot post into a channel they cannot view (WITH CHECK blocks it).
--
-- !!! KNOWN-FAILING UNTIL THE SLOWMODE POLICY IS FIXED !!!
-- messages has TWO permissive INSERT policies:
--   * "Users can send messages in accessible channels"  (access control)
--   * "enforce_slowmode_on_send"                         (rate limit)
-- Permissive policies are OR'd. check_slowmode_allowed() returns TRUE for any
-- channel with slowmode_seconds = 0 (the default), so the effective check
-- collapses to `(access control) OR TRUE` = TRUE and this INSERT SUCCEEDS,
-- letting a non-member post into a private channel (and spoof author_id).
--
-- FIX: make the slowmode policy RESTRICTIVE so it ANDs instead of ORs:
--   ALTER POLICY enforce_slowmode_on_send ON public.messages AS RESTRICTIVE;
-- After that fix, this test passes. It is intentionally left asserting the
-- CORRECT behavior so CI stays red until the bypass is closed.
SELECT pg_temp.login_as('33333333-3333-3333-3333-333333333333');

SELECT throws_ok(
  $$ INSERT INTO public.messages (channel_id, author_id, content)
     VALUES ('cccccccc-cccc-cccc-cccc-cccccccccccc',
             '33333333-3333-3333-3333-333333333333', 'intruder') $$,
  '42501',  -- insufficient_privilege (RLS WITH CHECK violation)
  NULL,
  'OUTSIDER cannot insert a message into an inaccessible channel'
);

-- MEMBER can post into their own accessible channel.
SELECT pg_temp.login_as('22222222-2222-2222-2222-222222222222');

SELECT lives_ok(
  $$ INSERT INTO public.messages (channel_id, author_id, content)
     VALUES ('cccccccc-cccc-cccc-cccc-cccccccccccc',
             '22222222-2222-2222-2222-222222222222', 'hello from member') $$,
  'MEMBER can insert a message into their accessible channel'
);

SELECT pg_temp.logout();
SELECT * FROM finish();

ROLLBACK;
