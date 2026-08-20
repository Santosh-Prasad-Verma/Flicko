-- Migration 170: Add View Once (One-Time Media) support and WhatsApp-style formatted DM notification previews

ALTER TABLE public.direct_messages ADD COLUMN IF NOT EXISTS is_view_once BOOLEAN DEFAULT FALSE;
ALTER TABLE public.direct_messages ADD COLUMN IF NOT EXISTS is_viewed BOOLEAN DEFAULT FALSE;

ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS is_view_once BOOLEAN DEFAULT FALSE;
ALTER TABLE public.messages ADD COLUMN IF NOT EXISTS is_viewed BOOLEAN DEFAULT FALSE;

-- Update DM notification trigger to format media type previews (WhatsApp style)
CREATE OR REPLACE FUNCTION public.handle_direct_message_notification()
RETURNS TRIGGER AS $$
DECLARE
  sender_username TEXT;
  receiver_preferences JSONB;
  allow_dm BOOLEAN;
  preview_text TEXT;
  attachment_item JSONB;
  file_url TEXT;
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
    -- Determine WhatsApp-style formatted preview
    IF NEW.is_view_once IS TRUE THEN
      preview_text := '📷 View Once Media';
    ELSIF NEW.attachments IS NOT NULL AND jsonb_array_length(NEW.attachments) > 0 THEN
      attachment_item := NEW.attachments->0;
      file_url := LOWER(COALESCE(attachment_item->>'url', attachment_item->>'path', ''));
      
      IF file_url LIKE '%.png' OR file_url LIKE '%.jpg' OR file_url LIKE '%.jpeg' OR file_url LIKE '%.webp' OR file_url LIKE '%/avatars/%' OR file_url LIKE '%/attachments/%' THEN
        preview_text := '📷 Photo';
      ELSIF file_url LIKE '%.gif' OR file_url LIKE '%tenor.com%' OR file_url LIKE '%giphy.com%' THEN
        preview_text := '👾 GIF';
      ELSIF file_url LIKE '%.mp4' OR file_url LIKE '%.mov' OR file_url LIKE '%.webm' THEN
        preview_text := '🎥 Video';
      ELSIF file_url LIKE '%.aac' OR file_url LIKE '%.m4a' OR file_url LIKE '%.ogg' OR file_url LIKE '%.mp3' OR file_url LIKE '%voice%' THEN
        preview_text := '🎤 Voice message';
      ELSE
        preview_text := '📄 File';
      END IF;
    ELSIF NEW.content LIKE '%[sticker:%' OR NEW.content LIKE '%/stickers/%' THEN
      preview_text := '👾 Sticker';
    ELSIF NEW.content LIKE '%tenor.com%' OR NEW.content LIKE '%giphy.com%' THEN
      preview_text := '👾 GIF';
    ELSIF NEW.content LIKE 'http://%' OR NEW.content LIKE 'https://%' THEN
      IF NEW.content LIKE '%.png' OR NEW.content LIKE '%.jpg' OR NEW.content LIKE '%.jpeg' OR NEW.content LIKE '%.webp' THEN
        preview_text := '📷 Photo';
      ELSIF NEW.content LIKE '%.mp4' OR NEW.content LIKE '%.mov' THEN
        preview_text := '🎥 Video';
      ELSE
        preview_text := CASE WHEN length(NEW.content) > 100 THEN left(NEW.content, 97) || '...' ELSE NEW.content END;
      END IF;
    ELSE
      preview_text := CASE WHEN length(NEW.content) > 100 THEN left(NEW.content, 97) || '...' ELSE NEW.content END;
    END IF;

    INSERT INTO public.notifications (user_id, type, content, read)
    VALUES (
      NEW.recipient_id,
      'dm',
      jsonb_build_object(
        'userId', NEW.sender_id,
        'userName', sender_username,
        'content', 'sent you a message',
        'preview', preview_text
      ),
      false
    );
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
