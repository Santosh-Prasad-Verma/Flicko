-- 034_advanced_rls_policies.sql

-- Enable RLS on all Phase 1 domain tables
ALTER TABLE public.user_settings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.sessions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.connected_accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.presence ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.activities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.attachments ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.embeds ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.mentions ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.message_flags ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.message_edit_history ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.pinned_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.threads ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.thread_members ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.voice_states ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.screen_shares ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.drawing_strokes ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_dms ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.group_dm_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dm_messages ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.dm_read_states ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.friend_requests ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.friendships ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.blocks ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.invite_usage ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.stickers ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.server_templates ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.permission_overwrites ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.member_roles ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.communities ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.community_events ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.event_participants ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.announcements ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.audit_logs ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.auto_mod_rules ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.reports ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.warnings ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.server_boosts ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.server_boost_status ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.webhooks ENABLE ROW LEVEL SECURITY;

-- 1.12 User Management RLS
CREATE POLICY "Users can view their own settings" ON public.user_settings FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Users can update their own settings" ON public.user_settings FOR UPDATE USING (user_id = auth.uid());

CREATE POLICY "Users can view their own sessions" ON public.sessions FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Users can delete their own sessions" ON public.sessions FOR DELETE USING (user_id = auth.uid());

CREATE POLICY "Users can view their own connected accounts" ON public.connected_accounts FOR SELECT USING (user_id = auth.uid());
CREATE POLICY "Users can insert their own connected accounts" ON public.connected_accounts FOR INSERT WITH CHECK (user_id = auth.uid());
CREATE POLICY "Users can update their own connected accounts" ON public.connected_accounts FOR UPDATE USING (user_id = auth.uid());
CREATE POLICY "Users can delete their own connected accounts" ON public.connected_accounts FOR DELETE USING (user_id = auth.uid());

CREATE POLICY "Anyone can view presence" ON public.presence FOR SELECT USING (true);
CREATE POLICY "Users can update their own presence" ON public.presence FOR ALL USING (user_id = auth.uid());

CREATE POLICY "Anyone can view activities" ON public.activities FOR SELECT USING (true);
CREATE POLICY "Users can manage their own activities" ON public.activities FOR ALL USING (user_id = auth.uid());

-- 1.13 Messaging RLS (Simplified for basic channel access; full permissions need functions)
CREATE POLICY "View attachments via channel access" ON public.attachments FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.messages m
    JOIN public.channels c ON m.channel_id = c.id
    JOIN public.server_members sm ON c.server_id = sm.server_id
    WHERE m.id = attachments.message_id AND sm.user_id = auth.uid()
  )
);
CREATE POLICY "Insert attachments" ON public.attachments FOR INSERT WITH CHECK (
  EXISTS (
    SELECT 1 FROM public.messages m
    WHERE m.id = message_id AND m.author_id = auth.uid()
  )
);

CREATE POLICY "View embeds via channel access" ON public.embeds FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.messages m
    JOIN public.channels c ON m.channel_id = c.id
    JOIN public.server_members sm ON c.server_id = sm.server_id
    WHERE m.id = embeds.message_id AND sm.user_id = auth.uid()
  )
);

CREATE POLICY "Users can view mentions directed at them or via channel" ON public.mentions FOR SELECT USING (
  target_id = auth.uid() OR
  EXISTS (
    SELECT 1 FROM public.messages m
    JOIN public.channels c ON m.channel_id = c.id
    JOIN public.server_members sm ON c.server_id = sm.server_id
    WHERE m.id = mentions.message_id AND sm.user_id = auth.uid()
  )
);
CREATE POLICY "Users can update read status of their mentions" ON public.mentions FOR UPDATE USING (target_id = auth.uid());

CREATE POLICY "View message flags via channel access" ON public.message_flags FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.messages m
    JOIN public.channels c ON m.channel_id = c.id
    JOIN public.server_members sm ON c.server_id = sm.server_id
    WHERE m.id = message_flags.message_id AND sm.user_id = auth.uid()
  )
);

CREATE POLICY "View edit history via channel access" ON public.message_edit_history FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.messages m
    JOIN public.channels c ON m.channel_id = c.id
    JOIN public.server_members sm ON c.server_id = sm.server_id
    WHERE m.id = message_edit_history.message_id AND sm.user_id = auth.uid()
  )
);

CREATE POLICY "View pinned messages" ON public.pinned_messages FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.channels c
    JOIN public.server_members sm ON c.server_id = sm.server_id
    WHERE c.id = pinned_messages.channel_id AND sm.user_id = auth.uid()
  )
);
-- Note: Insert/Delete for pinned messages actually requires MANAGE_MESSAGES permission function, using basic check for now.
CREATE POLICY "Manage pinned messages" ON public.pinned_messages FOR ALL USING (
  EXISTS (
    SELECT 1 FROM public.channels c
    JOIN public.server_members sm ON c.server_id = sm.server_id
    WHERE c.id = pinned_messages.channel_id AND sm.user_id = auth.uid()
  )
);


-- 1.14 Threads, Voice/Video, DM RLS
CREATE POLICY "View threads" ON public.threads FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.thread_members tm WHERE tm.thread_id = id AND tm.user_id = auth.uid()) OR
  EXISTS (
    SELECT 1 FROM public.channels c
    JOIN public.server_members sm ON c.server_id = sm.server_id
    WHERE c.id = threads.parent_channel_id AND sm.user_id = auth.uid()
  )
);
CREATE POLICY "Create threads" ON public.threads FOR INSERT WITH CHECK (creator_id = auth.uid());

CREATE POLICY "View thread members" ON public.thread_members FOR SELECT USING (
  user_id = auth.uid() OR EXISTS (SELECT 1 FROM public.thread_members tm WHERE tm.thread_id = thread_id AND tm.user_id = auth.uid())
);
CREATE POLICY "Manage own thread membership" ON public.thread_members FOR ALL USING (user_id = auth.uid());

CREATE POLICY "View voice states" ON public.voice_states FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.server_members sm WHERE sm.server_id = voice_states.server_id AND sm.user_id = auth.uid())
);
CREATE POLICY "Manage own voice state" ON public.voice_states FOR ALL USING (user_id = auth.uid());

CREATE POLICY "View screen shares in same channel" ON public.screen_shares FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.voice_states vs WHERE vs.channel_id = screen_shares.channel_id AND vs.user_id = auth.uid())
);
CREATE POLICY "Manage own screen share" ON public.screen_shares FOR ALL USING (user_id = auth.uid());

CREATE POLICY "View drawing strokes" ON public.drawing_strokes FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.screen_shares ss
    JOIN public.voice_states vs ON ss.channel_id = vs.channel_id
    WHERE ss.id = drawing_strokes.screen_share_id AND vs.user_id = auth.uid()
  )
);
CREATE POLICY "Insert drawing strokes" ON public.drawing_strokes FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "View joined group DMs" ON public.group_dms FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.group_dm_participants gp WHERE gp.group_dm_id = id AND gp.user_id = auth.uid())
);

CREATE POLICY "View DM messages" ON public.dm_messages FOR SELECT USING (
  author_id = auth.uid() OR EXISTS (
    SELECT 1 FROM public.group_dm_participants gp WHERE gp.group_dm_id = conversation_id AND gp.user_id = auth.uid()
  ) OR EXISTS (
    SELECT 1 FROM public.friendships f WHERE f.user_id = auth.uid() -- Basic fallback mapping for 1-1
  )
);
CREATE POLICY "Send DM messages" ON public.dm_messages FOR INSERT WITH CHECK (author_id = auth.uid());

-- 1.15 Social, Server Management, Communities RLS
CREATE POLICY "View involved friend requests" ON public.friend_requests FOR SELECT USING (sender_id = auth.uid() OR receiver_id = auth.uid());
CREATE POLICY "Send friend request" ON public.friend_requests FOR INSERT WITH CHECK (sender_id = auth.uid());
CREATE POLICY "Update received friend request" ON public.friend_requests FOR UPDATE USING (receiver_id = auth.uid());

CREATE POLICY "View own friendships" ON public.friendships FOR SELECT USING (user_id = auth.uid() OR friend_id = auth.uid());
CREATE POLICY "Manage own friendships" ON public.friendships FOR ALL USING (user_id = auth.uid());

CREATE POLICY "View own blocks" ON public.blocks FOR SELECT USING (blocker_id = auth.uid());
CREATE POLICY "Manage own blocks" ON public.blocks FOR ALL USING (blocker_id = auth.uid());

CREATE POLICY "View server invites" ON public.invites FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.server_members sm WHERE sm.server_id = invites.server_id AND sm.user_id = auth.uid()) OR
  is_expired = false -- Allow public access to active invites
);
-- INSERT requiring CREATE_INVITE permission skipped here, relying on backend auth

CREATE POLICY "View server stickers" ON public.stickers FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.server_members sm WHERE sm.server_id = stickers.server_id AND sm.user_id = auth.uid())
);

CREATE POLICY "View permission overwrites" ON public.permission_overwrites FOR SELECT USING (
  EXISTS (
    SELECT 1 FROM public.channels c
    JOIN public.server_members sm ON c.server_id = sm.server_id
    WHERE c.id = permission_overwrites.channel_id AND sm.user_id = auth.uid()
  )
);

CREATE POLICY "View discoverable or joined communities" ON public.communities FOR SELECT USING (
  is_discoverable = true OR EXISTS (SELECT 1 FROM public.server_members sm WHERE sm.server_id = server_id AND sm.user_id = auth.uid())
);

CREATE POLICY "View community events" ON public.community_events FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.server_members sm WHERE sm.server_id = community_events.server_id AND sm.user_id = auth.uid())
);

CREATE POLICY "View announcements" ON public.announcements FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.server_members sm WHERE sm.server_id = announcements.server_id AND sm.user_id = auth.uid())
);


-- 1.16 Moderation & Integration
-- View audit logs requires VIEW_AUDIT_LOG permission, restricted to admins for now
CREATE POLICY "View audit logs" ON public.audit_logs FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.server_members sm WHERE sm.server_id = audit_logs.server_id AND sm.user_id = auth.uid() AND (SELECT id FROM public.roles WHERE name = 'Admin') = ANY(sm.roles))
);

CREATE POLICY "View own or admin reports" ON public.reports FOR SELECT USING (
  reporter_id = auth.uid() OR EXISTS (SELECT 1 FROM public.server_members sm WHERE sm.server_id = reports.server_id AND sm.user_id = auth.uid() AND (SELECT id FROM public.roles WHERE name = 'Admin') = ANY(sm.roles))
);
CREATE POLICY "Submit reports" ON public.reports FOR INSERT WITH CHECK (true); -- Anyone can report

CREATE POLICY "View own warnings" ON public.warnings FOR SELECT USING (
  user_id = auth.uid() OR EXISTS (SELECT 1 FROM public.server_members sm WHERE sm.server_id = warnings.server_id AND sm.user_id = auth.uid() AND (SELECT id FROM public.roles WHERE name = 'Admin') = ANY(sm.roles))
);

CREATE POLICY "View server boosts" ON public.server_boosts FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.server_members sm WHERE sm.server_id = server_boosts.server_id AND sm.user_id = auth.uid())
);
CREATE POLICY "Add server boost" ON public.server_boosts FOR INSERT WITH CHECK (user_id = auth.uid());

CREATE POLICY "View server boost status" ON public.server_boost_status FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.server_members sm WHERE sm.server_id = server_boost_status.server_id AND sm.user_id = auth.uid())
);

CREATE POLICY "View server webhooks" ON public.webhooks FOR SELECT USING (
  EXISTS (SELECT 1 FROM public.server_members sm WHERE sm.server_id = webhooks.server_id AND sm.user_id = auth.uid())
);
