-- Migration 063: Fix foreign keys to reference profiles instead of auth.users
-- PostgREST can only resolve joins within the public schema.
-- Tables that use `profiles!column` syntax in Supabase client queries need
-- FKs pointing to public.profiles, not auth.users.

-- voice_states.user_id → profiles(id)
ALTER TABLE public.voice_states DROP CONSTRAINT IF EXISTS voice_states_user_id_fkey;
ALTER TABLE public.voice_states
  ADD CONSTRAINT voice_states_user_id_fkey
  FOREIGN KEY (user_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

-- friend_requests.sender_id & receiver_id → profiles(id)
ALTER TABLE public.friend_requests DROP CONSTRAINT IF EXISTS friend_requests_sender_id_fkey;
ALTER TABLE public.friend_requests DROP CONSTRAINT IF EXISTS friend_requests_receiver_id_fkey;
ALTER TABLE public.friend_requests
  ADD CONSTRAINT friend_requests_sender_id_fkey
  FOREIGN KEY (sender_id) REFERENCES public.profiles(id) ON DELETE CASCADE;
ALTER TABLE public.friend_requests
  ADD CONSTRAINT friend_requests_receiver_id_fkey
  FOREIGN KEY (receiver_id) REFERENCES public.profiles(id) ON DELETE CASCADE;

-- stickers.creator_id → profiles(id)
ALTER TABLE public.stickers DROP CONSTRAINT IF EXISTS stickers_creator_id_fkey;
ALTER TABLE public.stickers
  ADD CONSTRAINT stickers_creator_id_fkey
  FOREIGN KEY (creator_id) REFERENCES public.profiles(id) ON DELETE SET NULL;

-- Reload PostgREST schema cache
NOTIFY pgrst, 'reload schema';
