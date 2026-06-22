-- CRIT-7: Postgres triggers that fire pg_notify('flicko_events', json)
-- whenever a row is inserted into server_members, messages, or reactions.
-- The Go backend's PgListener picks these up and publishes into the EventBus
-- so bots (welcome, automod, leveling, starboard) can react to real activity.

-- ─── Helper function ────────────────────────────────────────────────────────

CREATE OR REPLACE FUNCTION public.notify_flicko_event()
RETURNS trigger AS $$
DECLARE
  payload JSONB;
  event_type TEXT;
  server_id_val UUID;
  channel_id_val UUID;
  user_id_val UUID;
BEGIN
  -- Determine event type and extract IDs based on the source table.
  CASE TG_TABLE_NAME
    WHEN 'server_members' THEN
      IF TG_OP = 'INSERT' THEN
        event_type := 'MEMBER_JOIN';
      ELSIF TG_OP = 'DELETE' THEN
        event_type := 'MEMBER_LEAVE';
      END IF;
      server_id_val := COALESCE(NEW.server_id, OLD.server_id);
      user_id_val := COALESCE(NEW.user_id, OLD.user_id);
      channel_id_val := NULL;

    WHEN 'messages' THEN
      IF TG_OP = 'INSERT' THEN
        event_type := 'MESSAGE_CREATE';
      ELSIF TG_OP = 'UPDATE' THEN
        event_type := 'MESSAGE_UPDATE';
      ELSIF TG_OP = 'DELETE' THEN
        event_type := 'MESSAGE_DELETE';
      END IF;
      channel_id_val := COALESCE(NEW.channel_id, OLD.channel_id);
      user_id_val := COALESCE(NEW.author_id, OLD.author_id);
      -- Resolve server_id from the channel
      SELECT c.server_id INTO server_id_val
        FROM public.channels c
        WHERE c.id = channel_id_val;

    WHEN 'reactions' THEN
      IF TG_OP = 'INSERT' THEN
        event_type := 'REACTION_ADD';
      ELSIF TG_OP = 'DELETE' THEN
        event_type := 'REACTION_REMOVE';
      END IF;
      user_id_val := COALESCE(NEW.user_id, OLD.user_id);
      -- Resolve channel and server from the message
      SELECT m.channel_id, c.server_id
        INTO channel_id_val, server_id_val
        FROM public.messages m
        JOIN public.channels c ON c.id = m.channel_id
        WHERE m.id = COALESCE(NEW.message_id, OLD.message_id);
  END CASE;

  -- Skip system messages (author_id NULL) to avoid infinite loops when bots
  -- insert messages that would re-trigger automod/leveling.
  IF TG_TABLE_NAME = 'messages' AND user_id_val IS NULL THEN
    RETURN COALESCE(NEW, OLD);
  END IF;

  -- Build the payload
  payload := jsonb_build_object(
    'event', event_type,
    'server_id', server_id_val,
    'channel_id', channel_id_val,
    'user_id', user_id_val,
    'data', CASE
      WHEN TG_TABLE_NAME = 'messages' AND NEW IS NOT NULL THEN
        jsonb_build_object(
          'message_id', NEW.id,
          'content', NEW.content,
          'author_id', NEW.author_id
        )
      WHEN TG_TABLE_NAME = 'reactions' AND NEW IS NOT NULL THEN
        jsonb_build_object(
          'message_id', NEW.message_id,
          'emoji', NEW.emoji
        )
      ELSE '{}'::jsonb
    END
  );

  -- Fire the notification (best-effort; if the backend isn't listening, it's a no-op).
  PERFORM pg_notify('flicko_events', payload::text);

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- ─── Triggers ───────────────────────────────────────────────────────────────

-- server_members: JOIN and LEAVE
DROP TRIGGER IF EXISTS trg_flicko_member_join ON public.server_members;
CREATE TRIGGER trg_flicko_member_join
  AFTER INSERT ON public.server_members
  FOR EACH ROW EXECUTE FUNCTION public.notify_flicko_event();

DROP TRIGGER IF EXISTS trg_flicko_member_leave ON public.server_members;
CREATE TRIGGER trg_flicko_member_leave
  AFTER DELETE ON public.server_members
  FOR EACH ROW EXECUTE FUNCTION public.notify_flicko_event();

-- messages: CREATE, UPDATE, DELETE
DROP TRIGGER IF EXISTS trg_flicko_message_create ON public.messages;
CREATE TRIGGER trg_flicko_message_create
  AFTER INSERT ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.notify_flicko_event();

DROP TRIGGER IF EXISTS trg_flicko_message_delete ON public.messages;
CREATE TRIGGER trg_flicko_message_delete
  AFTER DELETE ON public.messages
  FOR EACH ROW EXECUTE FUNCTION public.notify_flicko_event();

-- reactions: ADD and REMOVE
DROP TRIGGER IF EXISTS trg_flicko_reaction_add ON public.reactions;
CREATE TRIGGER trg_flicko_reaction_add
  AFTER INSERT ON public.reactions
  FOR EACH ROW EXECUTE FUNCTION public.notify_flicko_event();

DROP TRIGGER IF EXISTS trg_flicko_reaction_remove ON public.reactions;
CREATE TRIGGER trg_flicko_reaction_remove
  AFTER DELETE ON public.reactions
  FOR EACH ROW EXECUTE FUNCTION public.notify_flicko_event();

