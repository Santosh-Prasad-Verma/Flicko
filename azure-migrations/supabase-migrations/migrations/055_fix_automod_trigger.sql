-- ════════════════════════════════════════════════════════════════════════════════
-- Migration 055: Fix enforce_auto_mod_rules() trigger
--
-- Migration 051 renamed auto_mod_rules → automod_rules and several columns,
-- but never updated the trigger function body. Every INSERT on messages
-- fails with: relation "public.auto_mod_rules" does not exist
-- ════════════════════════════════════════════════════════════════════════════════

-- Recreate the function with corrected table/column references
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
    RETURN NEW; -- Skip DMs / orphan channels
  END IF;

  -- Check if automod_rules table exists (defensive)
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.tables
    WHERE table_schema = 'public' AND table_name = 'automod_rules'
  ) THEN
    RETURN NEW;
  END IF;

  -- Loop through enabled rules for the server
  -- Column mapping from 051: rule_type→trigger_type, trigger_config→trigger_metadata,
  --   is_enabled→enabled, action_type stays action_type
  FOR rule IN
    SELECT * FROM public.automod_rules
    WHERE server_id = msg_server_id AND enabled = true
  LOOP
    is_violation := FALSE;

    -- Evaluate rule types
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
      -- Audit log
      INSERT INTO public.audit_logs(server_id, action_type, target_type, target_id, reason, created_at)
      VALUES (msg_server_id, 'AUTO_MOD_TRIGGERED', 'user', NEW.author_id, 'Violated rule: ' || rule.name, NOW());

      -- Execute action
      IF rule.action_type = 'block' THEN
        RAISE EXCEPTION 'Message blocked by AutoMod rule: %', rule.name
          USING HINT = 'Modify message and try again.', ERRCODE = 'P0001';
      END IF;
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- The trigger itself doesn't need recreation (it points to the function name,
-- which hasn't changed), but let's ensure it exists:
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM pg_trigger WHERE tgname = 'tr_enforce_auto_mod_rules'
  ) THEN
    CREATE TRIGGER tr_enforce_auto_mod_rules
    BEFORE INSERT ON public.messages
    FOR EACH ROW
    EXECUTE FUNCTION public.enforce_auto_mod_rules();
  END IF;
END $$;
