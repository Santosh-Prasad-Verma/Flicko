-- Migration 144: Fix reactions replica identity and map enforce_auto_mod_rules to audit_logs (plural)

-- 1. Enable REPLICA IDENTITY FULL on reactions and dm_reactions for realtime delete payloads
ALTER TABLE public.reactions REPLICA IDENTITY FULL;
ALTER TABLE public.dm_reactions REPLICA IDENTITY FULL;

-- 2. Enable RLS on audit_logs and its partitions
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs_default ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs_y2026m05 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs_y2026m06 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs_y2026m07 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs_y2026m08 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs_y2026m09 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs_y2026m10 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs_y2026m11 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs_y2026m12 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs_y2027m01 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs_y2027m02 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs_y2027m03 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs_y2027m04 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs_y2027m05 ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs_y2027m06 ENABLE ROW LEVEL SECURITY;

-- 3. Update enforce_auto_mod_rules to insert into partitioned public.audit_logs (plural)
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
      INSERT INTO public.audit_logs(server_id, actor_id, action_type, target_type, target_id, reason, created_at)
      VALUES (msg_server_id, NEW.author_id, 'AUTO_MOD_TRIGGERED', 'user', NEW.author_id, 'Violated rule: ' || rule.name, NOW());

      IF rule.action_type = 'block' THEN
        RAISE EXCEPTION 'Message blocked by AutoMod rule: %', rule.name
          USING HINT = 'Modify message and try again.', ERRCODE = 'P0001';
      END IF;
    END IF;
  END LOOP;

  RETURN NEW;
END;
$function$;
