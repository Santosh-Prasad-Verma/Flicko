-- 051_align_schema_with_services.sql
--
-- Comprehensive migration to align the Supabase schema with the shared service layer.
-- Fixes table renames, column renames, missing columns, missing tables, and CHECK
-- constraint mismatches between the mobile app services and the database.
--
-- Affected services:
--   channelService, autoModService, auditLogService, memberService, eventService,
--   webhookService, templateService, notificationSettingsService, onboardingService,
--   boostService

-- ════════════════════════════════════════════════════════════════════════════════
-- 1. CHANNELS — expand type constraint, ensure nsfw column
-- ════════════════════════════════════════════════════════════════════════════════

DO $$
DECLARE
  cname TEXT;
BEGIN
  -- Drop named constraint or auto-named constraint on channels.type
  FOR cname IN
    SELECT conname FROM pg_constraint
    WHERE conrelid = 'channels'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) LIKE '%type%'
  LOOP
    EXECUTE format('ALTER TABLE channels DROP CONSTRAINT %I', cname);
  END LOOP;
END $$;

ALTER TABLE channels
  ADD CONSTRAINT channels_type_check
  CHECK (type IN ('text', 'voice', 'announcement', 'category', 'forum', 'stage', 'dm'));

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'channels' AND column_name = 'nsfw'
  ) THEN
    ALTER TABLE channels ADD COLUMN nsfw BOOLEAN DEFAULT FALSE;
  END IF;
END $$;

-- ════════════════════════════════════════════════════════════════════════════════
-- 2. SERVERS — fix verification_level type, add explicit_content_filter
-- ════════════════════════════════════════════════════════════════════════════════

DO $$
DECLARE
  col_type TEXT;
  cname TEXT;
BEGIN
  SELECT data_type INTO col_type
  FROM information_schema.columns
  WHERE table_name = 'servers' AND column_name = 'verification_level';

  IF col_type IS NOT NULL AND col_type <> 'text' AND col_type <> 'character varying' THEN
    -- Must drop CHECK constraints first (they use integer comparison operators)
    FOR cname IN
      SELECT conname FROM pg_constraint
      WHERE conrelid = 'servers'::regclass
        AND contype = 'c'
        AND pg_get_constraintdef(oid) LIKE '%verification_level%'
    LOOP
      EXECUTE format('ALTER TABLE servers DROP CONSTRAINT %I', cname);
    END LOOP;

    ALTER TABLE servers ALTER COLUMN verification_level DROP DEFAULT;
    ALTER TABLE servers ALTER COLUMN verification_level TYPE TEXT
      USING CASE verification_level
        WHEN 0 THEN 'none'
        WHEN 1 THEN 'low'
        WHEN 2 THEN 'medium'
        WHEN 3 THEN 'high'
        WHEN 4 THEN 'very_high'
        ELSE 'none'
      END;
    ALTER TABLE servers ALTER COLUMN verification_level SET DEFAULT 'none';
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'servers' AND column_name = 'explicit_content_filter'
  ) THEN
    ALTER TABLE servers ADD COLUMN explicit_content_filter TEXT DEFAULT 'disabled';
  END IF;
END $$;

-- ════════════════════════════════════════════════════════════════════════════════
-- 3. AUTOMOD — rename table + columns to match autoModService.ts
-- ════════════════════════════════════════════════════════════════════════════════

-- 3a. Rename table
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'auto_mod_rules')
     AND NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'automod_rules')
  THEN
    ALTER TABLE auto_mod_rules RENAME TO automod_rules;
  END IF;
END $$;

-- 3b. Rename columns
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'automod_rules' AND column_name = 'rule_type') THEN
    ALTER TABLE automod_rules RENAME COLUMN rule_type TO trigger_type;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'automod_rules' AND column_name = 'trigger_config') THEN
    ALTER TABLE automod_rules RENAME COLUMN trigger_config TO trigger_metadata;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'automod_rules' AND column_name = 'is_enabled') THEN
    ALTER TABLE automod_rules RENAME COLUMN is_enabled TO enabled;
  END IF;
END $$;

-- 3c. Add 'actions' JSONB column, populate from action_type + action_config
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'automod_rules' AND column_name = 'actions'
  ) THEN
    ALTER TABLE automod_rules ADD COLUMN actions JSONB DEFAULT '[]';
    -- Migrate existing data
    UPDATE automod_rules
    SET actions = jsonb_build_array(
      jsonb_build_object('type', COALESCE(action_type, 'block_message'), 'metadata', COALESCE(action_config, '{}'::jsonb))
    )
    WHERE actions = '[]'::jsonb;
  END IF;
END $$;

-- 3d. Update trigger_type CHECK constraint to match service types
DO $$
DECLARE
  cname TEXT;
BEGIN
  FOR cname IN
    SELECT conname FROM pg_constraint
    WHERE conrelid = 'automod_rules'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) LIKE '%trigger_type%'
  LOOP
    EXECUTE format('ALTER TABLE automod_rules DROP CONSTRAINT %I', cname);
  END LOOP;
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

-- Also try old column name constraint
DO $$
DECLARE
  cname TEXT;
BEGIN
  FOR cname IN
    SELECT conname FROM pg_constraint
    WHERE conrelid = 'automod_rules'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) LIKE '%rule_type%'
  LOOP
    EXECUTE format('ALTER TABLE automod_rules DROP CONSTRAINT %I', cname);
  END LOOP;
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'automod_rules') THEN
    ALTER TABLE automod_rules ADD CONSTRAINT automod_rules_trigger_type_check
      CHECK (trigger_type IN ('keyword', 'spam', 'mention_spam', 'link', 'invite_link', 'caps',
                              'profanity', 'mentions', 'links', 'keywords'));
  END IF;
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ════════════════════════════════════════════════════════════════════════════════
-- 4. AUDIT LOG — rename table + columns to match auditLogService.ts
-- ════════════════════════════════════════════════════════════════════════════════

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'audit_logs')
     AND NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'audit_log')
  THEN
    ALTER TABLE audit_logs RENAME TO audit_log;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'audit_log' AND column_name = 'actor_id') THEN
    ALTER TABLE audit_log RENAME COLUMN actor_id TO user_id;
  END IF;
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'audit_log' AND column_name = 'action_type') THEN
    ALTER TABLE audit_log RENAME COLUMN action_type TO action;
  END IF;
END $$;

-- ════════════════════════════════════════════════════════════════════════════════
-- 5. BANS — rename table + column to match memberService.ts
-- ════════════════════════════════════════════════════════════════════════════════

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'server_bans')
     AND NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'bans')
  THEN
    ALTER TABLE server_bans RENAME TO bans;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'bans' AND column_name = 'executor_id') THEN
    ALTER TABLE bans RENAME COLUMN executor_id TO banned_by;
  END IF;
END $$;

-- ════════════════════════════════════════════════════════════════════════════════
-- 6. INVITES — add id column, rename inviter_id to created_by
-- ════════════════════════════════════════════════════════════════════════════════

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'invites' AND column_name = 'id'
  ) THEN
    ALTER TABLE invites ADD COLUMN id UUID DEFAULT gen_random_uuid() UNIQUE;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'invites' AND column_name = 'inviter_id')
     AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'invites' AND column_name = 'created_by')
  THEN
    ALTER TABLE invites RENAME COLUMN inviter_id TO created_by;
  END IF;
END $$;

-- ════════════════════════════════════════════════════════════════════════════════
-- 7. EVENTS — rename tables + add missing columns
-- ════════════════════════════════════════════════════════════════════════════════

-- 7a. Rename community_events → scheduled_events
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'community_events')
     AND NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'scheduled_events')
  THEN
    ALTER TABLE community_events RENAME TO scheduled_events;
  END IF;
END $$;

-- 7b. Add missing columns to scheduled_events
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'scheduled_events' AND column_name = 'channel_id'
  ) THEN
    ALTER TABLE scheduled_events ADD COLUMN channel_id UUID REFERENCES channels(id) ON DELETE SET NULL;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'scheduled_events' AND column_name = 'image_url'
  ) THEN
    ALTER TABLE scheduled_events ADD COLUMN image_url TEXT;
  END IF;
END $$;

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'scheduled_events' AND column_name = 'interested_count'
  ) THEN
    ALTER TABLE scheduled_events ADD COLUMN interested_count INTEGER DEFAULT 0;
  END IF;
END $$;

-- 7c. Rename event_participants → event_rsvps
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'event_participants')
     AND NOT EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'event_rsvps')
  THEN
    ALTER TABLE event_participants RENAME TO event_rsvps;
  END IF;
END $$;

-- 7d. Add id column to event_rsvps
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'event_rsvps')
     AND NOT EXISTS (
       SELECT 1 FROM information_schema.columns
       WHERE table_name = 'event_rsvps' AND column_name = 'id'
     )
  THEN
    ALTER TABLE event_rsvps ADD COLUMN id UUID DEFAULT gen_random_uuid() UNIQUE;
  END IF;
END $$;

-- 7e. Update event_rsvps status CHECK to include 'going'
DO $$
DECLARE
  cname TEXT;
BEGIN
  FOR cname IN
    SELECT conname FROM pg_constraint
    WHERE conrelid = 'event_rsvps'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) LIKE '%status%'
  LOOP
    EXECUTE format('ALTER TABLE event_rsvps DROP CONSTRAINT %I', cname);
  END LOOP;

  ALTER TABLE event_rsvps ADD CONSTRAINT event_rsvps_status_check
    CHECK (status IN ('interested', 'going', 'attending'));
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

-- ════════════════════════════════════════════════════════════════════════════════
-- 8. WEBHOOKS — rename columns, add missing columns
-- ════════════════════════════════════════════════════════════════════════════════

-- Rename creator_id → created_by
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'webhooks' AND column_name = 'creator_id')
     AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'webhooks' AND column_name = 'created_by')
  THEN
    ALTER TABLE webhooks RENAME COLUMN creator_id TO created_by;
  END IF;
END $$;

-- Add avatar_url (service uses avatar_url, DB has avatar)
DO $$ BEGIN
  -- If DB has 'avatar' but not 'avatar_url', rename it
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'webhooks' AND column_name = 'avatar')
     AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'webhooks' AND column_name = 'avatar_url')
  THEN
    ALTER TABLE webhooks RENAME COLUMN avatar TO avatar_url;
  ELSIF NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'webhooks' AND column_name = 'avatar_url') THEN
    ALTER TABLE webhooks ADD COLUMN avatar_url TEXT;
  END IF;
END $$;

-- Add token column
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'webhooks' AND column_name = 'token'
  ) THEN
    ALTER TABLE webhooks ADD COLUMN token TEXT DEFAULT gen_random_uuid()::TEXT;
  END IF;
END $$;

-- Make url nullable (service doesn't provide url on insert; it's auto-generated)
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'webhooks' AND column_name = 'url') THEN
    ALTER TABLE webhooks ALTER COLUMN url DROP NOT NULL;
    -- Set a default so inserts without url work
    ALTER TABLE webhooks ALTER COLUMN url SET DEFAULT '';
  END IF;
END $$;

-- ════════════════════════════════════════════════════════════════════════════════
-- 9. TEMPLATES — add id column, rename template_data → serialized_data
-- ════════════════════════════════════════════════════════════════════════════════

DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'server_templates' AND column_name = 'id'
  ) THEN
    ALTER TABLE server_templates ADD COLUMN id UUID DEFAULT gen_random_uuid() UNIQUE;
  END IF;
END $$;

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'server_templates' AND column_name = 'template_data')
     AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'server_templates' AND column_name = 'serialized_data')
  THEN
    ALTER TABLE server_templates RENAME COLUMN template_data TO serialized_data;
  END IF;
END $$;

-- ════════════════════════════════════════════════════════════════════════════════
-- 10. NOTIFICATION SETTINGS — fix column names and CHECK constraints
-- ════════════════════════════════════════════════════════════════════════════════

-- 10a. Rename suppress_roles → suppress_role_mentions
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'server_notification_settings' AND column_name = 'suppress_roles')
     AND NOT EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'server_notification_settings' AND column_name = 'suppress_role_mentions')
  THEN
    ALTER TABLE server_notification_settings RENAME COLUMN suppress_roles TO suppress_role_mentions;
  END IF;
END $$;

-- 10b. Add mobile_push column
DO $$ BEGIN
  IF NOT EXISTS (
    SELECT 1 FROM information_schema.columns
    WHERE table_name = 'server_notification_settings' AND column_name = 'mobile_push'
  ) THEN
    ALTER TABLE server_notification_settings ADD COLUMN mobile_push BOOLEAN DEFAULT TRUE;
  END IF;
END $$;

-- 10c. Fix server_notification_settings level CHECK (allow 'all', 'mentions', 'none', 'default')
DO $$
DECLARE
  cname TEXT;
BEGIN
  FOR cname IN
    SELECT conname FROM pg_constraint
    WHERE conrelid = 'server_notification_settings'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) LIKE '%level%'
  LOOP
    EXECUTE format('ALTER TABLE server_notification_settings DROP CONSTRAINT %I', cname);
  END LOOP;

  ALTER TABLE server_notification_settings ADD CONSTRAINT server_notification_settings_level_check
    CHECK (level IN ('all', 'mentions', 'none', 'default', 'all_messages', 'only_mentions', 'nothing'));
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

-- 10d. Fix channel_notification_settings level CHECK
DO $$
DECLARE
  cname TEXT;
BEGIN
  FOR cname IN
    SELECT conname FROM pg_constraint
    WHERE conrelid = 'channel_notification_settings'::regclass
      AND contype = 'c'
      AND pg_get_constraintdef(oid) LIKE '%level%'
  LOOP
    EXECUTE format('ALTER TABLE channel_notification_settings DROP CONSTRAINT %I', cname);
  END LOOP;

  ALTER TABLE channel_notification_settings ADD CONSTRAINT channel_notification_settings_level_check
    CHECK (level IN ('all', 'mentions', 'none', 'default', 'all_messages', 'only_mentions', 'nothing'));
EXCEPTION WHEN undefined_table THEN NULL;
END $$;

-- ════════════════════════════════════════════════════════════════════════════════
-- 11. BOOSTS — make expires_at nullable (service doesn't provide it)
-- ════════════════════════════════════════════════════════════════════════════════

DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.columns WHERE table_name = 'server_boosts' AND column_name = 'expires_at') THEN
    ALTER TABLE server_boosts ALTER COLUMN expires_at DROP NOT NULL;
    ALTER TABLE server_boosts ALTER COLUMN expires_at SET DEFAULT (NOW() + INTERVAL '30 days');
  END IF;
END $$;

-- ════════════════════════════════════════════════════════════════════════════════
-- 12. ONBOARDING — create missing tables
-- ════════════════════════════════════════════════════════════════════════════════

CREATE TABLE IF NOT EXISTS server_onboarding (
  server_id UUID PRIMARY KEY REFERENCES servers(id) ON DELETE CASCADE,
  enabled BOOLEAN NOT NULL DEFAULT FALSE,
  welcome_title TEXT NOT NULL DEFAULT 'Welcome!',
  welcome_description TEXT,
  welcome_image_url TEXT,
  default_channel_ids UUID[] DEFAULT '{}',
  rules TEXT[] DEFAULT '{}',
  require_rules_acceptance BOOLEAN NOT NULL DEFAULT FALSE,
  prompts JSONB DEFAULT '[]',
  created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

ALTER TABLE server_onboarding ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "server_onboarding_member_read"
    ON server_onboarding FOR SELECT
    USING (
      EXISTS (
        SELECT 1 FROM server_members
        WHERE server_members.server_id = server_onboarding.server_id
          AND server_members.user_id = auth.uid()
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

DO $$ BEGIN
  CREATE POLICY "server_onboarding_owner_write"
    ON server_onboarding FOR ALL
    USING (
      EXISTS (
        SELECT 1 FROM servers
        WHERE servers.id = server_onboarding.server_id
          AND servers.owner_id = auth.uid()
      )
    );
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

CREATE TABLE IF NOT EXISTS onboarding_completions (
  user_id UUID NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  server_id UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  selected_options JSONB DEFAULT '{}',
  completed_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  PRIMARY KEY (user_id, server_id)
);

ALTER TABLE onboarding_completions ENABLE ROW LEVEL SECURITY;

DO $$ BEGIN
  CREATE POLICY "onboarding_completions_self"
    ON onboarding_completions FOR ALL
    USING (auth.uid() = user_id);
EXCEPTION WHEN duplicate_object THEN NULL;
END $$;

-- ════════════════════════════════════════════════════════════════════════════════
-- 13. RLS POLICIES for renamed tables
-- ════════════════════════════════════════════════════════════════════════════════

-- Bans (was server_bans) — ensure RLS policies exist
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'bans') THEN
    ALTER TABLE bans ENABLE ROW LEVEL SECURITY;

    BEGIN
      CREATE POLICY "bans_member_read"
        ON bans FOR SELECT
        USING (
          EXISTS (
            SELECT 1 FROM server_members
            WHERE server_members.server_id = bans.server_id
              AND server_members.user_id = auth.uid()
          )
        );
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;

    BEGIN
      CREATE POLICY "bans_admin_write"
        ON bans FOR ALL
        USING (
          EXISTS (
            SELECT 1 FROM server_members
            WHERE server_members.server_id = bans.server_id
              AND server_members.user_id = auth.uid()
          )
        );
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
  END IF;
END $$;

-- Audit log (was audit_logs)
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'audit_log') THEN
    ALTER TABLE audit_log ENABLE ROW LEVEL SECURITY;

    BEGIN
      CREATE POLICY "audit_log_member_read"
        ON audit_log FOR SELECT
        USING (
          EXISTS (
            SELECT 1 FROM server_members
            WHERE server_members.server_id = audit_log.server_id
              AND server_members.user_id = auth.uid()
          )
        );
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
  END IF;
END $$;

-- AutoMod rules (was auto_mod_rules)
DO $$ BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_name = 'automod_rules') THEN
    ALTER TABLE automod_rules ENABLE ROW LEVEL SECURITY;

    BEGIN
      CREATE POLICY "automod_rules_member_read"
        ON automod_rules FOR SELECT
        USING (
          EXISTS (
            SELECT 1 FROM server_members
            WHERE server_members.server_id = automod_rules.server_id
              AND server_members.user_id = auth.uid()
          )
        );
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;

    BEGIN
      CREATE POLICY "automod_rules_admin_write"
        ON automod_rules FOR ALL
        USING (
          EXISTS (
            SELECT 1 FROM server_members
            WHERE server_members.server_id = automod_rules.server_id
              AND server_members.user_id = auth.uid()
          )
        );
    EXCEPTION WHEN duplicate_object THEN NULL;
    END;
  END IF;
END $$;
