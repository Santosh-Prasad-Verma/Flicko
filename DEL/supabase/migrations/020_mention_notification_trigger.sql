-- Migration: Mention notification trigger
-- Description: Automatically creates notifications when users are mentioned in messages
-- Requirements: 16.1

-- Create function to handle message mentions
CREATE OR REPLACE FUNCTION public.handle_message_mention()
RETURNS TRIGGER AS $$
BEGIN
  -- Extract mentioned user IDs from content (simplified)
  -- In production, use proper mention parsing
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

-- Create trigger on messages table
CREATE TRIGGER on_message_mention
  AFTER INSERT ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.handle_message_mention();
