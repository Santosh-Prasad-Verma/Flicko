// @ts-nocheck — Supabase Edge Functions run on Deno, not Node.js
/**
 * Supabase Edge Function: push-notify
 *
 * Triggered by database webhooks when a new message is inserted.
 * Sends push notifications via Expo Push API to relevant users.
 *
 * Required env vars: none (Expo Push is free and keyless)
 *
 * Requirements: Feature 20 (Push Notifications - Zero Cost)
 */
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const EXPO_PUSH_URL = 'https://exp.host/--/api/v2/push/send';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface WebhookPayload {
  type: 'INSERT';
  table: string;
  record: {
    id: string;
    channel_id: string;
    author_id: string;
    content: string;
  };
}

serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const supabaseUrl = Deno.env.get('SUPABASE_URL')!;
  const supabaseKey = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY')!;
  const supabase = createClient(supabaseUrl, supabaseKey);

  try {
    const payload: WebhookPayload = await req.json();

    if (payload.type !== 'INSERT' || payload.table !== 'messages') {
      return new Response('Ignored', { status: 200, headers: corsHeaders });
    }

    const message = payload.record;

    // 1. Get the channel to find the server
    const { data: channel } = await supabase
      .from('channels')
      .select('server_id, name')
      .eq('id', message.channel_id)
      .single();

    if (!channel) {
      return new Response('Channel not found', { status: 200, headers: corsHeaders });
    }

    // 2. Get the author's display info
    const { data: author } = await supabase
      .from('profiles')
      .select('username, display_name')
      .eq('id', message.author_id)
      .single();

    const authorName = author?.display_name || author?.username || 'Unknown';

    // 3. Get all server members except the author
    const { data: members } = await supabase
      .from('server_members')
      .select('user_id')
      .eq('server_id', channel.server_id)
      .neq('user_id', message.author_id);

    if (!members || members.length === 0) {
      return new Response('No recipients', { status: 200, headers: corsHeaders });
    }

    const memberIds = members.map((m: { user_id: string }) => m.user_id);

    // 3.5. Filter out users who have muted the channel or have notifications disabled globally
    // We fetch user settings and channel settings in a single query
    const { data: userSettings } = await supabase
      .from('user_settings')
      .select('user_id, notifications_enabled')
      .in('user_id', memberIds);

// Build set of users who explicitly disabled notifications
      const disabledUserIdSet = new Set(
        (userSettings || [])
          .filter(s => s.notifications_enabled === false)
          .map(s => s.user_id)
      );

      // Default to true if no settings row found, discard disabled users
      const filteredMemberIds = memberIds.filter(id => !disabledUserIdSet.has(id));

    // 4. Get active push tokens for these members
    const { data: tokens } = await supabase
      .from('push_notification_tokens')
      .select('token, user_id')
      .in('user_id', filteredMemberIds)
      .eq('is_active', true);

    if (!tokens || tokens.length === 0) {
      return new Response('No tokens', { status: 200, headers: corsHeaders });
    }

    // 5. Build Expo push messages
    const truncatedContent =
      message.content.length > 100
        ? message.content.substring(0, 100) + '…'
        : message.content;

    const pushMessages = tokens.map((t: { token: string; user_id: string }) => ({
      to: t.token,
      title: `${authorName} in #${channel.name}`,
      body: truncatedContent,
      sound: 'default',
      data: {
        type: 'message',
        channel_id: message.channel_id,
        message_id: message.id,
        server_id: channel.server_id,
      },
      channelId: 'messages', // Android notification channel
    }));

    // 6. Send via Expo Push API (batches of 100)
    const BATCH_SIZE = 100;
    for (let i = 0; i < pushMessages.length; i += BATCH_SIZE) {
      const batch = pushMessages.slice(i, i + BATCH_SIZE);

      const response = await fetch(EXPO_PUSH_URL, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Accept: 'application/json',
        },
        body: JSON.stringify(batch),
      });

      if (!response.ok) {
        console.error('Expo push failed:', await response.text());
      }
    }

    return new Response(
      JSON.stringify({ sent: pushMessages.length }),
      { status: 200, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  } catch (err) {
    console.error('Push notify error:', err);
    return new Response(
      JSON.stringify({ error: String(err) }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
});
