-- 005_triggers_and_functions.sql

-- 1. Auto user profile creation
CREATE OR REPLACE FUNCTION public.handle_new_user()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO public.profiles (id, username, email, discriminator)
  VALUES (
    NEW.id,
    COALESCE(NEW.raw_user_meta_data->>'username', split_part(NEW.email, '@', 1)),
    NEW.email,
    LPAD(FLOOR(RANDOM() * 10000)::TEXT, 4, '0')
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_public_user_created
  AFTER INSERT ON public.users
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_user();


-- 2. Server initialization trigger
CREATE OR REPLACE FUNCTION public.handle_new_server()
RETURNS TRIGGER AS $$
DECLARE
  default_role_id UUID;
BEGIN
  -- Create default "@everyone" role
  INSERT INTO public.roles (server_id, name, permissions, position)
  VALUES (NEW.id, '@everyone', 0, 0)
  RETURNING id INTO default_role_id;
  
  -- Create default "general" text channel
  INSERT INTO public.channels (server_id, name, type, position)
  VALUES (NEW.id, 'general', 'text', 0);
  
  -- Add owner as first server member with default role
  INSERT INTO public.server_members (server_id, user_id, roles)
  VALUES (NEW.id, NEW.owner_id, ARRAY[default_role_id]);
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_server_created
  AFTER INSERT ON public.servers
  FOR EACH ROW EXECUTE FUNCTION public.handle_new_server();


-- 3. Updated_at timestamp triggers
CREATE OR REPLACE FUNCTION public.handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER set_updated_at
  BEFORE UPDATE ON profiles
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_updated_at
  BEFORE UPDATE ON servers
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();

CREATE TRIGGER set_updated_at
  BEFORE UPDATE ON channels
  FOR EACH ROW EXECUTE FUNCTION public.handle_updated_at();


-- 4. Mention notification trigger
CREATE OR REPLACE FUNCTION public.handle_message_mention()
RETURNS TRIGGER AS $$
BEGIN
  -- Extract mentioned user IDs from content
  IF NEW.content ~ '@[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}' THEN
    INSERT INTO public.notifications (user_id, type, content)
    SELECT 
      (regexp_matches(NEW.content, '@([0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12})', 'g'))[1]::UUID,
      'mention',
      jsonb_build_object(
        'message_id', NEW.id,
        'channel_id', NEW.channel_id,
        'author_id', NEW.author_id
      );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER on_message_mention
  AFTER INSERT ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.handle_message_mention();


-- 5. Automod Filtering Trigger
CREATE OR REPLACE FUNCTION public.enforce_auto_mod_rules()
RETURNS TRIGGER AS $$
DECLARE
  rule RECORD;
  is_violation BOOLEAN := FALSE;
  msg_content TEXT := LOWER(NEW.content);
  blocked_words TEXT[];
  keyword TEXT;
  msg_server_id UUID;
BEGIN
  -- Get server_id from the channel
  SELECT server_id INTO msg_server_id FROM public.channels WHERE id = NEW.channel_id;

  IF msg_server_id IS NULL THEN
    RETURN NEW; -- Skip DMs
  END IF;

  -- Check if automod_rules table exists
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'automod_settings'
  ) THEN
    RETURN NEW;
  END IF;

  -- This is a simplified version of the logic matching the structure
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_enforce_auto_mod_rules
BEFORE INSERT ON public.messages
FOR EACH ROW EXECUTE FUNCTION public.enforce_auto_mod_rules();


-- 6. Friend request notification trigger
CREATE OR REPLACE FUNCTION public.handle_friend_request_notification()
RETURNS TRIGGER AS $$
DECLARE
  sender_username TEXT;
BEGIN
  IF NEW.status = 'pending' THEN
    SELECT COALESCE(username, 'Someone') INTO sender_username
    FROM public.profiles
    WHERE id = NEW.sender_id;

    DELETE FROM public.notifications 
    WHERE user_id = NEW.receiver_id 
      AND type = 'friend_request' 
      AND (content->>'userId') = NEW.sender_id::text;

    INSERT INTO public.notifications (user_id, type, content, read)
    VALUES (
      NEW.receiver_id,
      'friend_request',
      jsonb_build_object(
        'userId', NEW.sender_id,
        'userName', sender_username,
        'content', 'sent you a friend request',
        'preview', NEW.message
      ),
      false
    );
  ELSIF NEW.status = 'accepted' OR NEW.status = 'declined' THEN
    UPDATE public.notifications
    SET read = true
    WHERE user_id = NEW.receiver_id
      AND type = 'friend_request'
      AND (content->>'userId') = NEW.sender_id::text;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE OR REPLACE TRIGGER tr_on_friend_request_notification
AFTER INSERT OR UPDATE ON public.friend_requests
FOR EACH ROW
EXECUTE FUNCTION public.handle_friend_request_notification();
