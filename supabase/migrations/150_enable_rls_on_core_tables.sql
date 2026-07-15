-- Migration: Enable RLS on core tables missing security policies (Hardened with checks)
-- Description: Enables RLS and sets up secure SELECT/INSERT/UPDATE/DELETE rules only on existing tables

-- 1. channels
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'channels') THEN
    ALTER TABLE public.channels ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "select_channels" ON public.channels;
    DROP POLICY IF EXISTS "insert_channels" ON public.channels;
    DROP POLICY IF EXISTS "update_channels" ON public.channels;
    DROP POLICY IF EXISTS "delete_channels" ON public.channels;

    CREATE POLICY "select_channels" ON public.channels FOR SELECT TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM public.server_members 
        WHERE server_members.server_id = channels.server_id 
          AND server_members.user_id = auth.uid()
      )
    );

    CREATE POLICY "insert_channels" ON public.channels FOR INSERT TO authenticated
    WITH CHECK (
      EXISTS (
        SELECT 1 FROM public.servers WHERE id = server_id AND owner_id = auth.uid()
      ) OR public.has_server_permission(auth.uid(), server_id, 'MANAGE_CHANNELS')
    );

    CREATE POLICY "update_channels" ON public.channels FOR UPDATE TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM public.servers WHERE id = server_id AND owner_id = auth.uid()
      ) OR public.has_server_permission(auth.uid(), server_id, 'MANAGE_CHANNELS')
    )
    WITH CHECK (
      EXISTS (
        SELECT 1 FROM public.servers WHERE id = server_id AND owner_id = auth.uid()
      ) OR public.has_server_permission(auth.uid(), server_id, 'MANAGE_CHANNELS')
    );

    CREATE POLICY "delete_channels" ON public.channels FOR DELETE TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM public.servers WHERE id = server_id AND owner_id = auth.uid()
      ) OR public.has_server_permission(auth.uid(), server_id, 'MANAGE_CHANNELS')
    );
  END IF;
END $$;

-- 2. roles
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'roles') THEN
    ALTER TABLE public.roles ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "select_roles" ON public.roles;
    DROP POLICY IF EXISTS "manage_roles" ON public.roles;

    CREATE POLICY "select_roles" ON public.roles FOR SELECT TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM public.server_members 
        WHERE server_members.server_id = roles.server_id 
          AND server_members.user_id = auth.uid()
      )
    );

    CREATE POLICY "manage_roles" ON public.roles FOR ALL TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM public.servers WHERE id = server_id AND owner_id = auth.uid()
      ) OR public.has_server_permission(auth.uid(), server_id, 'MANAGE_ROLES')
    );
  END IF;
END $$;

-- 3. server_members
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'server_members') THEN
    ALTER TABLE public.server_members ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "select_server_members" ON public.server_members;
    DROP POLICY IF EXISTS "insert_server_members" ON public.server_members;
    DROP POLICY IF EXISTS "manage_server_members" ON public.server_members;

    CREATE POLICY "select_server_members" ON public.server_members FOR SELECT TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM public.server_members sm 
        WHERE sm.server_id = server_members.server_id 
          AND sm.user_id = auth.uid()
      )
    );

    CREATE POLICY "insert_server_members" ON public.server_members FOR INSERT TO authenticated
    WITH CHECK (
      auth.uid() = user_id OR
      EXISTS (
        SELECT 1 FROM public.servers WHERE id = server_id AND owner_id = auth.uid()
      ) OR public.has_server_permission(auth.uid(), server_id, 'MANAGE_MEMBERS')
    );

    CREATE POLICY "manage_server_members" ON public.server_members FOR ALL TO authenticated
    USING (
      auth.uid() = user_id OR
      EXISTS (
        SELECT 1 FROM public.servers WHERE id = server_id AND owner_id = auth.uid()
      ) OR public.has_server_permission(auth.uid(), server_id, 'MANAGE_MEMBERS')
    );
  END IF;
END $$;

-- 4. reactions
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'reactions') THEN
    ALTER TABLE public.reactions ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "select_reactions" ON public.reactions;
    DROP POLICY IF EXISTS "insert_reactions" ON public.reactions;
    DROP POLICY IF EXISTS "delete_reactions" ON public.reactions;

    CREATE POLICY "select_reactions" ON public.reactions FOR SELECT TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM public.messages m
        JOIN public.channels c ON m.channel_id = c.id
        JOIN public.server_members sm ON c.server_id = sm.server_id
        WHERE m.id = reactions.message_id AND sm.user_id = auth.uid()
      )
    );

    CREATE POLICY "insert_reactions" ON public.reactions FOR INSERT TO authenticated
    WITH CHECK (
      auth.uid() = user_id AND
      EXISTS (
        SELECT 1 FROM public.messages m
        JOIN public.channels c ON m.channel_id = c.id
        JOIN public.server_members sm ON c.server_id = sm.server_id
        WHERE m.id = message_id AND sm.user_id = auth.uid()
      )
    );

    CREATE POLICY "delete_reactions" ON public.reactions FOR DELETE TO authenticated
    USING (
      auth.uid() = user_id OR
      EXISTS (
        SELECT 1 FROM public.messages m
        JOIN public.channels c ON m.channel_id = c.id
        JOIN public.server_members sm ON c.server_id = sm.server_id
        WHERE m.id = message_id AND (
          sm.user_id = auth.uid() AND (
            public.has_permission(auth.uid(), c.id, 'MANAGE_MESSAGES') 
            OR EXISTS (SELECT 1 FROM public.servers s WHERE s.id = c.server_id AND s.owner_id = auth.uid())
          )
        )
      )
    );
  END IF;
END $$;

-- 5. server_bans
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'server_bans') THEN
    ALTER TABLE public.server_bans ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "manage_server_bans" ON public.server_bans;

    CREATE POLICY "manage_server_bans" ON public.server_bans FOR ALL TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM public.servers WHERE id = server_id AND owner_id = auth.uid()
      ) OR public.has_server_permission(auth.uid(), server_id, 'BAN_MEMBERS')
    );
  END IF;
END $$;

-- 6. custom_emojis & server_emojis
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'custom_emojis') THEN
    ALTER TABLE public.custom_emojis ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "select_custom_emojis" ON public.custom_emojis;
    DROP POLICY IF EXISTS "manage_custom_emojis" ON public.custom_emojis;

    CREATE POLICY "select_custom_emojis" ON public.custom_emojis FOR SELECT TO authenticated USING (true);
    CREATE POLICY "manage_custom_emojis" ON public.custom_emojis FOR ALL TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM public.servers WHERE id = server_id AND owner_id = auth.uid()
      ) OR public.has_server_permission(auth.uid(), server_id, 'MANAGE_EMOJIS_AND_STICKERS')
    );
  END IF;
END $$;

DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'server_emojis') THEN
    ALTER TABLE public.server_emojis ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "select_server_emojis" ON public.server_emojis;
    DROP POLICY IF EXISTS "manage_server_emojis" ON public.server_emojis;

    CREATE POLICY "select_server_emojis" ON public.server_emojis FOR SELECT TO authenticated USING (true);
    CREATE POLICY "manage_server_emojis" ON public.server_emojis FOR ALL TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM public.servers WHERE id = server_id AND owner_id = auth.uid()
      ) OR public.has_server_permission(auth.uid(), server_id, 'MANAGE_EMOJIS_AND_STICKERS')
    );
  END IF;
END $$;

-- 7. music_queues
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'music_queues') THEN
    ALTER TABLE public.music_queues ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "select_music_queues" ON public.music_queues;
    DROP POLICY IF EXISTS "manage_music_queues" ON public.music_queues;

    CREATE POLICY "select_music_queues" ON public.music_queues FOR SELECT TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM public.server_members sm 
        WHERE sm.server_id = music_queues.server_id 
          AND sm.user_id = auth.uid()
      )
    );

    CREATE POLICY "manage_music_queues" ON public.music_queues FOR ALL TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM public.server_members sm 
        WHERE sm.server_id = music_queues.server_id 
          AND sm.user_id = auth.uid()
      )
    );
  END IF;
END $$;

-- 8. notifications
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'notifications') THEN
    ALTER TABLE public.notifications ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "manage_own_notifications" ON public.notifications;

    CREATE POLICY "manage_own_notifications" ON public.notifications FOR ALL TO authenticated
    USING (user_id = auth.uid());
  END IF;
END $$;

-- 9. creator_media_uploads
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'creator_media_uploads') THEN
    ALTER TABLE public.creator_media_uploads ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "manage_own_creator_media" ON public.creator_media_uploads;

    CREATE POLICY "manage_own_creator_media" ON public.creator_media_uploads FOR ALL TO authenticated
    USING (creator_id = auth.uid());
  END IF;
END $$;

-- 10. external_bot_events
DO $$
BEGIN
  IF EXISTS (SELECT 1 FROM information_schema.tables WHERE table_schema = 'public' AND table_name = 'external_bot_events') THEN
    ALTER TABLE public.external_bot_events ENABLE ROW LEVEL SECURITY;
    DROP POLICY IF EXISTS "manage_bot_events" ON public.external_bot_events;

    CREATE POLICY "manage_bot_events" ON public.external_bot_events FOR ALL TO authenticated
    USING (
      EXISTS (
        SELECT 1 FROM public.bots b
        WHERE b.id = bot_id AND b.owner_id = auth.uid()
      )
    );
  END IF;
END $$;
