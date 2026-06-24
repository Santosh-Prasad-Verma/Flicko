-- Update check_dm_privacy trigger function to check for accepted friendship first
CREATE OR REPLACE FUNCTION public.check_dm_privacy()
RETURNS TRIGGER AS $$
DECLARE
  target_allow_everyone BOOLEAN;
  target_allow_server BOOLEAN;
  has_mutual_server BOOLEAN;
BEGIN
  -- Check if they are accepted friends first.
  IF EXISTS (
    SELECT 1 FROM public.friends f
    WHERE f.status = 'accepted'
      AND (
        (f.user_id = NEW.sender_id AND f.friend_id = NEW.recipient_id)
        OR (f.user_id = NEW.recipient_id AND f.friend_id = NEW.sender_id)
      )
  ) THEN
    RETURN NEW;
  END IF;

  -- For direct messages, checking sender_id and recipient_id mutual servers.
  SELECT allow_dms_from_everyone, allow_dms_from_server_members
  INTO target_allow_everyone, target_allow_server
  FROM public.user_privacy_settings
  WHERE user_id = NEW.recipient_id;

  IF NOT COALESCE(target_allow_everyone, false) THEN
    IF NOT COALESCE(target_allow_server, true) THEN
      RAISE EXCEPTION 'Target user does not accept DMs.';
    ELSE
      -- Check mutual server
      SELECT EXISTS (
        SELECT 1
        FROM public.server_members m1
        JOIN public.server_members m2 ON m1.server_id = m2.server_id
        WHERE m1.user_id = NEW.sender_id AND m2.user_id = NEW.recipient_id
      ) INTO has_mutual_server;

      IF NOT has_mutual_server THEN
        RAISE EXCEPTION 'Target user only accepts DMs from server members.';
      END IF;
    END IF;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;


-- Trigger function for inserting converse friend row
CREATE OR REPLACE FUNCTION public.handle_friend_insert_converse()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'accepted' THEN
    INSERT INTO public.friends (user_id, friend_id, status)
    VALUES (NEW.friend_id, NEW.user_id, 'accepted')
    ON CONFLICT (user_id, friend_id) DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Trigger function for deleting converse friend row
CREATE OR REPLACE FUNCTION public.handle_friend_delete_converse()
RETURNS TRIGGER AS $$
BEGIN
  DELETE FROM public.friends
  WHERE user_id = OLD.friend_id AND friend_id = OLD.user_id;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Trigger function for updating status to converse friend row
CREATE OR REPLACE FUNCTION public.handle_friend_update_converse()
RETURNS TRIGGER AS $$
BEGIN
  -- To prevent infinite recursion, only update if the status is different
  UPDATE public.friends
  SET status = NEW.status
  WHERE user_id = NEW.friend_id AND friend_id = NEW.user_id AND status != NEW.status;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Triggers for friends
DROP TRIGGER IF EXISTS trg_friend_insert_converse ON public.friends;
CREATE TRIGGER trg_friend_insert_converse
  AFTER INSERT ON public.friends
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_friend_insert_converse();

DROP TRIGGER IF EXISTS trg_friend_delete_converse ON public.friends;
CREATE TRIGGER trg_friend_delete_converse
  AFTER DELETE ON public.friends
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_friend_delete_converse();

DROP TRIGGER IF EXISTS trg_friend_update_converse ON public.friends;
CREATE TRIGGER trg_friend_update_converse
  AFTER UPDATE ON public.friends
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_friend_update_converse();


-- Trigger function for inserting converse friendship row
CREATE OR REPLACE FUNCTION public.handle_friendship_insert_converse()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.friendships (user_id, friend_id, nickname)
  VALUES (NEW.friend_id, NEW.user_id, NEW.nickname)
  ON CONFLICT (user_id, friend_id) DO NOTHING;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Trigger function for deleting converse friendship row
CREATE OR REPLACE FUNCTION public.handle_friendship_delete_converse()
RETURNS TRIGGER AS $$
BEGIN
  DELETE FROM public.friendships
  WHERE user_id = OLD.friend_id AND friend_id = OLD.user_id;
  RETURN OLD;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Trigger function for updating nickname on converse friendship row
CREATE OR REPLACE FUNCTION public.handle_friendship_update_converse()
RETURNS TRIGGER AS $$
BEGIN
  UPDATE public.friendships
  SET nickname = NEW.nickname
  WHERE user_id = NEW.friend_id AND friend_id = NEW.user_id AND COALESCE(nickname, '') != COALESCE(NEW.nickname, '');
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER SET search_path = public;

-- Triggers for friendships
DROP TRIGGER IF EXISTS trg_friendship_insert_converse ON public.friendships;
CREATE TRIGGER trg_friendship_insert_converse
  AFTER INSERT ON public.friendships
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_friendship_insert_converse();

DROP TRIGGER IF EXISTS trg_friendship_delete_converse ON public.friendships;
CREATE TRIGGER trg_friendship_delete_converse
  AFTER DELETE ON public.friendships
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_friendship_delete_converse();

DROP TRIGGER IF EXISTS trg_friendship_update_converse ON public.friendships;
CREATE TRIGGER trg_friendship_update_converse
  AFTER UPDATE ON public.friendships
  FOR EACH ROW
  EXECUTE FUNCTION public.handle_friendship_update_converse();
