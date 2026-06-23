-- Add preferences JSONB column to profiles
ALTER TABLE public.profiles ADD COLUMN IF NOT EXISTS preferences JSONB DEFAULT '{}'::jsonb;

-- Register tables in the supabase_realtime publication safely
DO $$
BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'notifications'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.notifications;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM pg_publication_tables 
    WHERE pubname = 'supabase_realtime' AND schemaname = 'public' AND tablename = 'friend_requests'
  ) THEN
    ALTER PUBLICATION supabase_realtime ADD TABLE public.friend_requests;
  END IF;
END;
$$;

-- Create trigger function for Direct Message notifications
CREATE OR REPLACE FUNCTION public.handle_direct_message_notification()
RETURNS TRIGGER AS $$
DECLARE
  sender_username TEXT;
  receiver_preferences JSONB;
  allow_dm BOOLEAN;
BEGIN
  -- Get sender's display_name or username
  SELECT COALESCE(display_name, username, 'Someone') INTO sender_username
  FROM public.profiles
  WHERE id = NEW.sender_id;

  -- Get receiver's notification preferences
  SELECT preferences INTO receiver_preferences
  FROM public.profiles
  WHERE id = NEW.recipient_id;

  -- Check if user has disabled DMs. If preference not set, default to true
  allow_dm := COALESCE((receiver_preferences->>'direct_messages')::boolean, true);

  IF allow_dm THEN
    INSERT INTO public.notifications (user_id, type, content, read)
    VALUES (
      NEW.recipient_id,
      'dm',
      jsonb_build_object(
        'userId', NEW.sender_id,
        'userName', sender_username,
        'content', 'sent you a direct message',
        'preview', CASE WHEN length(NEW.content) > 100 THEN left(NEW.content, 97) || '...' ELSE NEW.content END
      ),
      false
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to execute on direct_messages insert
CREATE OR REPLACE TRIGGER tr_on_direct_message_notification
AFTER INSERT ON public.direct_messages
FOR EACH ROW
EXECUTE FUNCTION public.handle_direct_message_notification();

-- Re-implementation of mention trigger to parse @username and @uuid
CREATE OR REPLACE FUNCTION public.handle_message_mention()
RETURNS TRIGGER AS $$
DECLARE
  mention_match RECORD;
  mentioned_user_id UUID;
  sender_username TEXT;
  receiver_preferences JSONB;
  allow_mentions BOOLEAN;
  cleaned_token TEXT;
BEGIN
  -- Get sender's display_name or username
  SELECT COALESCE(display_name, username, 'Someone') INTO sender_username
  FROM public.profiles
  WHERE id = NEW.author_id;

  -- Find all matches for @something in the message content
  FOR mention_match IN 
    SELECT DISTINCT (regexp_matches(NEW.content, '@([A-Za-z0-9_.-]+)', 'g'))[1] AS token
  LOOP
    mentioned_user_id := NULL;
    receiver_preferences := NULL;
    cleaned_token := mention_match.token;

    -- 1. Try parsing as UUID if it matches UUID pattern
    IF cleaned_token ~ '^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$' THEN
      BEGIN
        mentioned_user_id := cleaned_token::UUID;
        SELECT preferences INTO receiver_preferences
        FROM public.profiles
        WHERE id = mentioned_user_id;
      EXCEPTION WHEN OTHERS THEN
        mentioned_user_id := NULL;
      END;
    END IF;

    -- 2. If not found by UUID, try lookup by username
    IF mentioned_user_id IS NULL THEN
      SELECT id, preferences INTO mentioned_user_id, receiver_preferences
      FROM public.profiles
      WHERE LOWER(username) = LOWER(cleaned_token)
      LIMIT 1;
    END IF;

    -- 3. If a user is found, and they are not the sender, create the notification
    IF mentioned_user_id IS NOT NULL AND mentioned_user_id != NEW.author_id THEN
      allow_mentions := COALESCE((receiver_preferences->>'mentions')::boolean, true);

      IF allow_mentions THEN
        -- Check duplicate
        IF NOT EXISTS (
          SELECT 1 FROM public.notifications 
          WHERE user_id = mentioned_user_id 
            AND type = 'mention' 
            AND (content->>'messageId') = NEW.id::text
        ) THEN
          INSERT INTO public.notifications (user_id, type, content, read)
          VALUES (
            mentioned_user_id,
            'mention',
            jsonb_build_object(
              'userId', NEW.author_id,
              'userName', sender_username,
              'content', 'mentioned you in a message',
              'preview', CASE WHEN length(NEW.content) > 100 THEN left(NEW.content, 97) || '...' ELSE NEW.content END,
              'messageId', NEW.id,
              'channelId', NEW.channel_id,
              'authorId', NEW.author_id
            ),
            false
          );
        END IF;
      END IF;
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
