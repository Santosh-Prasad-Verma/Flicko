-- 036_automation_triggers.sql

-- 1. Create update_thread_archive_time() trigger (Task 1.19)
CREATE OR REPLACE FUNCTION public.update_thread_archive_time()
RETURNS TRIGGER AS $$
DECLARE
  is_thread BOOLEAN;
BEGIN
  -- Check if the message's channel is actually a thread
  SELECT type = 'public_thread' OR type = 'private_thread' INTO is_thread 
  FROM public.channels WHERE id = NEW.channel_id;

  IF is_thread THEN
    UPDATE public.threads 
    SET archive_at = NOW() + auto_archive_duration 
    WHERE id = NEW.channel_id;
  END IF;
  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Trigger to execute on INSERT to messages
CREATE TRIGGER tr_update_thread_archive_time
AFTER INSERT ON public.messages
FOR EACH ROW
EXECUTE FUNCTION public.update_thread_archive_time();


-- 2. Create track_invite_usage() trigger (Task 1.19)
CREATE OR REPLACE FUNCTION public.track_invite_usage()
RETURNS TRIGGER AS $$
DECLARE
  current_uses INTEGER;
  maximum_uses INTEGER;
BEGIN
  -- Increment usage count
  UPDATE public.invites
  SET uses = uses + 1
  WHERE code = NEW.invite_code
  RETURNING uses, max_uses INTO current_uses, maximum_uses;

  -- Mark expired if max uses reached and max uses > 0 (0 = infinite)
  IF maximum_uses > 0 AND current_uses >= maximum_uses THEN
    UPDATE public.invites SET is_expired = TRUE WHERE code = NEW.invite_code;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER tr_track_invite_usage
AFTER INSERT ON public.invite_usage
FOR EACH ROW
EXECUTE FUNCTION public.track_invite_usage();


-- 3. Create update_server_boost_level() trigger (Task 1.19)
CREATE OR REPLACE FUNCTION public.update_server_boost_level()
RETURNS TRIGGER AS $$
DECLARE
  active_boost_count INTEGER;
  new_level INTEGER;
  target_server_id UUID;
BEGIN
  -- Determine the server ID that was affected
  IF TG_OP = 'DELETE' THEN
    target_server_id := OLD.server_id;
  ELSE
    target_server_id := NEW.server_id;
  END IF;

  -- Count total active boosts for the server
  SELECT COUNT(*) INTO active_boost_count
  FROM public.server_boosts
  WHERE server_id = target_server_id AND is_active = true AND expires_at > NOW();

  -- Calculate boost level
  IF active_boost_count >= 14 THEN
    new_level := 3;
  ELSIF active_boost_count >= 7 THEN
    new_level := 2;
  ELSIF active_boost_count >= 2 THEN
    new_level := 1;
  ELSE
    new_level := 0;
  END IF;

  -- Upsert status
  INSERT INTO public.server_boost_status (server_id, boost_count, boost_level, updated_at)
  VALUES (target_server_id, active_boost_count, new_level, NOW())
  ON CONFLICT (server_id) 
  DO UPDATE 
    SET boost_count = EXCLUDED.boost_count,
        boost_level = EXCLUDED.boost_level,
        updated_at = EXCLUDED.updated_at;

  RETURN NULL; -- AFTER triggers can return NULL
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER tr_update_server_boost_level
AFTER INSERT OR UPDATE OR DELETE ON public.server_boosts
FOR EACH ROW
EXECUTE FUNCTION public.update_server_boost_level();


-- 4. Create enforce_auto_mod_rules() trigger (Task 1.19)
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

  -- Loop through enabled rules for the server
  FOR rule IN 
    SELECT * FROM public.auto_mod_rules 
    WHERE server_id = msg_server_id AND is_enabled = true 
  LOOP
    is_violation := FALSE;

    -- Evaluate rule types
    IF rule.rule_type = 'keywords' OR rule.rule_type = 'profanity' THEN
      -- Extract keywords array from trigger config, e.g. {"keywords": ["badword", "slur"]}
      blocked_words := ARRAY(SELECT jsonb_array_elements_text(rule.trigger_config->'keywords'));
      
      FOREACH keyword IN ARRAY blocked_words LOOP
        IF POSITION(LOWER(keyword) IN msg_content) > 0 THEN
          is_violation := TRUE;
          EXIT; -- Found a violation
        END IF;
      END LOOP;
    ELSIF rule.rule_type = 'links' THEN
      IF msg_content ~ 'http[s]?://(?:[a-zA-Z]|[0-9]|[$-_@.&+]|[!*\\(\\),]|(?:%[0-9a-fA-F][0-9a-fA-F]))+' THEN
        is_violation := TRUE;
      END IF;
    -- Add more rule validation logic here as needed (spam, mentions, etc)
    END IF;

    -- If a violation triggered
    IF is_violation THEN
      -- 1. Create audit log
      INSERT INTO public.audit_logs(server_id, action_type, target_type, target_id, reason, created_at)
      VALUES (msg_server_id, 'AUTO_MOD_TRIGGERED', 'user', NEW.author_id, 'Violated rule: ' || rule.name, NOW());
      
      -- 2. Execute action
      IF rule.action_type = 'block' THEN
        RAISE EXCEPTION 'Message blocked by AutoMod rule: %', rule.name
          USING HINT = 'Modify message and try again.', ERRCODE = 'P0001';
      ELSIF rule.action_type = 'timeout' THEN
        -- Future: Issue a timeout here
      END IF;
    END IF;
  END LOOP;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER tr_enforce_auto_mod_rules
BEFORE INSERT ON public.messages
FOR EACH ROW
EXECUTE FUNCTION public.enforce_auto_mod_rules();
