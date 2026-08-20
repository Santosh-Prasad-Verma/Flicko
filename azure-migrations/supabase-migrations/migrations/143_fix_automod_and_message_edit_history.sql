-- Migration: Fix AutoMod audit table name and message edit history trigger columns.

-- 1. Fix enforce_auto_mod_rules (insert into audit_log instead of audit_logs)
CREATE OR REPLACE FUNCTION public.enforce_auto_mod_rules()
 RETURNS trigger
 LANGUAGE plpgsql
 SECURITY DEFINER
AS $function$
DECLARE
  rule RECORD;
  is_violation BOOLEAN := FALSE;
  msg_content TEXT := LOWER(NEW.content);
  blocked_words TEXT[];
  keyword TEXT;
  msg_server_id UUID;
BEGIN
  SELECT server_id INTO msg_server_id FROM public.channels WHERE id = NEW.channel_id;

  IF msg_server_id IS NULL THEN
    RETURN NEW;
  END IF;

  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'automod_rules'
  ) THEN
    RETURN NEW;
  END IF;

  FOR rule IN
    SELECT * FROM public.automod_rules
    WHERE server_id = msg_server_id AND enabled = true
  LOOP
    is_violation := FALSE;

    IF rule.trigger_type = 'keywords' OR rule.trigger_type = 'profanity' THEN
      blocked_words := ARRAY(SELECT jsonb_array_elements_text(rule.trigger_metadata->'keywords'));

      FOREACH keyword IN ARRAY blocked_words LOOP
        IF POSITION(LOWER(keyword) IN msg_content) > 0 THEN
          is_violation := TRUE;
          EXIT;
        END IF;
      END LOOP;
    ELSIF rule.trigger_type = 'links' THEN
      IF msg_content ~ 'http[s]?://(?:[a-zA-Z]|[0-9]|[$-_@.&+]|[!*\\(\\),]|(?:%[0-9a-fA-F][0-9a-fA-F]))+' THEN
        is_violation := TRUE;
      END IF;
    END IF;

    IF is_violation THEN
      INSERT INTO public.audit_log(server_id, action, target_type, target_id, reason, created_at)
      VALUES (msg_server_id, 'AUTO_MOD_TRIGGERED', 'user', NEW.author_id, 'Violated rule: ' || rule.name, NOW());

      IF rule.action_type = 'block' THEN
        RAISE EXCEPTION 'Message blocked by AutoMod rule: %', rule.name
          USING HINT = 'Modify message and try again.', ERRCODE = 'P0001';
      END IF;
    END IF;
  END LOOP;

  RETURN NEW;
END;
$function$;

-- 2. Fix handle_message_edit (insert into previous_content instead of old_content)
CREATE OR REPLACE FUNCTION handle_message_edit()
RETURNS trigger AS $$
BEGIN
  IF NEW.content <> OLD.content THEN
    NEW.edited := true;
    NEW.edited_at := NOW();
    NEW.updated_at := NOW();
    INSERT INTO public.message_edit_history (message_id, previous_content, edited_at)
    VALUES (OLD.id, OLD.content, NOW()) ON CONFLICT DO NOTHING;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Enable REPLICA IDENTITY FULL for deleted records filtering in realtime subscriptions
ALTER TABLE public.messages REPLICA IDENTITY FULL;
ALTER TABLE public.direct_messages REPLICA IDENTITY FULL;
