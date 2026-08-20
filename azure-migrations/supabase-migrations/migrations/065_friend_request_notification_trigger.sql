-- Create trigger function to handle friend request notifications
CREATE OR REPLACE FUNCTION public.handle_friend_request_notification()
RETURNS TRIGGER AS $$
DECLARE
  sender_username TEXT;
BEGIN
  -- We only create/update notifications when a friend request is pending
  IF NEW.status = 'pending' THEN
    -- Get sender's display_name or username
    SELECT COALESCE(display_name, username, 'Someone') INTO sender_username
    FROM public.profiles
    WHERE id = NEW.sender_id;

    -- Clean up any old unread friend_request notification from the same sender
    DELETE FROM public.notifications 
    WHERE user_id = NEW.receiver_id 
      AND type = 'friend_request' 
      AND (content->>'userId') = NEW.sender_id::text;

    -- Insert new notification matching notifications_screen.dart requirements
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
    -- When the request is accepted or declined, mark any matching notification as read
    UPDATE public.notifications
    SET read = true
    WHERE user_id = NEW.receiver_id
      AND type = 'friend_request'
      AND (content->>'userId') = NEW.sender_id::text;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to execute on friend_requests changes
CREATE OR REPLACE TRIGGER tr_on_friend_request_notification
AFTER INSERT OR UPDATE ON public.friend_requests
FOR EACH ROW
EXECUTE FUNCTION public.handle_friend_request_notification();
