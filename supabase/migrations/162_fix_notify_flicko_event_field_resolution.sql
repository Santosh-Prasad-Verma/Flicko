-- =============================================================================
-- 162: Fix notify_flicko_event() static field-resolution crash
-- =============================================================================
-- PROBLEM
-- notify_flicko_event() (migration 135) is a SINGLE trigger function attached to
-- three tables with different row shapes: messages, reactions, server_members.
-- Its payload builder referenced typed NEW fields inside a CASE:
--
--     'data', CASE
--       WHEN TG_TABLE_NAME = 'messages'  AND NEW IS NOT NULL THEN
--         jsonb_build_object('message_id', NEW.id, 'content', NEW.content, ...)
--       WHEN TG_TABLE_NAME = 'reactions' AND NEW IS NOT NULL THEN
--         jsonb_build_object('message_id', NEW.message_id, 'emoji', NEW.emoji)
--       ELSE '{}'::jsonb
--     END
--
-- PL/pgSQL resolves NEW.<field> against the trigger row's DECLARED composite type
-- at plan time, NOT at branch-evaluation time. When the trigger fires on
-- `messages`, NEW is of type `messages`, which has no `message_id` column, so the
-- (logically unreachable) reactions branch still fails to plan with:
--     ERROR: record "new" has no field "message_id"
-- Result: message INSERT/DELETE raises a hard error on a clean build (and message
-- DELETE already errors on databases at migration 135+). Core messaging breaks.
--
-- FIX
-- Access row fields through to_jsonb(NEW) / to_jsonb(OLD) and pull values with the
-- ->> operator. to_jsonb() accepts any composite type, and ->> returns NULL for an
-- absent key instead of failing static field resolution. Behaviour is otherwise
-- identical: same event types, same payload keys, same pg_notify channel.
-- Also make the DELETE path explicit by reading from OLD when NEW is absent, so the
-- MESSAGE_DELETE / REACTION_REMOVE / MEMBER_LEAVE payloads keep their data instead
-- of collapsing to '{}'.
-- =============================================================================

CREATE OR REPLACE FUNCTION public.notify_flicko_event()
RETURNS trigger AS $$
DECLARE
  payload JSONB;
  event_type TEXT;
  server_id_val UUID;
  channel_id_val UUID;
  user_id_val UUID;
  row_json JSONB;       -- to_jsonb of the affected row (NEW on ins/upd, OLD on del)
  data_json JSONB;
BEGIN
  -- The row we describe: NEW for INSERT/UPDATE, OLD for DELETE.
  row_json := to_jsonb(COALESCE(NEW, OLD));

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

  -- Build the per-table data payload from the jsonb view of the row. Using
  -- row_json->>'key' (rather than NEW.<field>) avoids PL/pgSQL static field
  -- resolution against a rowtype that lacks the column, which is what crashed
  -- the messages trigger on the (unreachable) reactions branch. Absent keys
  -- resolve to NULL instead of raising.
  IF TG_TABLE_NAME = 'messages' THEN
    data_json := jsonb_build_object(
      'message_id', row_json->>'id',
      'content',    row_json->>'content',
      'author_id',  row_json->>'author_id'
    );
  ELSIF TG_TABLE_NAME = 'reactions' THEN
    data_json := jsonb_build_object(
      'message_id', row_json->>'message_id',
      'emoji',      row_json->>'emoji'
    );
  ELSE
    data_json := '{}'::jsonb;
  END IF;

  payload := jsonb_build_object(
    'event', event_type,
    'server_id', server_id_val,
    'channel_id', channel_id_val,
    'user_id', user_id_val,
    'data', data_json
  );

  -- Fire the notification (best-effort; if the backend isn't listening, it's a no-op).
  PERFORM pg_notify('flicko_events', payload::text);

  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;
