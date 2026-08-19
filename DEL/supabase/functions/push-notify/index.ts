// @ts-nocheck — Supabase Edge Functions run on Deno, not Node.js
/**
 * Supabase Edge Function: push-notify
 *
 * Triggered by database webhooks when a new message is inserted.
 * Sends push notifications via Firebase Cloud Messaging (FCM) HTTP v1 API to Flutter clients.
 *
 * Required env vars:
 * - FIREBASE_SERVICE_ACCOUNT_KEY (JSON string of your Firebase admin service account)
 *
 * Requirements: Feature 20 (Push Notifications for Flutter)
 */
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { JWT } from 'npm:google-auth-library@9';

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

let fcmToken: string | null = null;
let fcmTokenExpiry: number = 0;
let firebaseProjectId: string | null = null;

// Get an OAuth2 token for FCM HTTP v1 API
async function getFcmAccessToken(): Promise<string> {
  if (fcmToken && Date.now() < fcmTokenExpiry) {
    return fcmToken;
  }

  const serviceAccountStr = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_KEY');
  if (!serviceAccountStr) {
    throw new Error('FIREBASE_SERVICE_ACCOUNT_KEY is not set in Edge Function secrets');
  }

  const serviceAccount = JSON.parse(serviceAccountStr);
  firebaseProjectId = serviceAccount.project_id;

  const jwtClient = new JWT({
    email: serviceAccount.client_email,
    key: serviceAccount.private_key,
    scopes: ['https://www.googleapis.com/auth/firebase.messaging'],
  });

  const tokens = await jwtClient.authorize();
  fcmToken = tokens.access_token as string;
  // expiry_date is in milliseconds
  fcmTokenExpiry = (tokens.expiry_date as number) - 60000; // 1-minute buffer
  return fcmToken;
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
    const { data: userSettings } = await supabase
      .from('user_settings')
      .select('user_id, notifications_enabled')
      .in('user_id', memberIds);

    const disabledUserIdSet = new Set(
      (userSettings || [])
        .filter((s: { user_id: string; notifications_enabled: boolean | null }) => s.notifications_enabled === false)
        .map((s: { user_id: string; notifications_enabled: boolean | null }) => s.user_id)
    );

    const filteredMemberIds = memberIds.filter((id: string) => !disabledUserIdSet.has(id));

    // 4. Get active push tokens for these members (assuming tokens are FCM tokens now)
    const { data: tokens } = await supabase
      .from('push_notification_tokens')
      .select('token, user_id')
      .in('user_id', filteredMemberIds)
      .eq('is_active', true);

    if (!tokens || tokens.length === 0) {
      return new Response('No tokens', { status: 200, headers: corsHeaders });
    }

    // 5. Build FCM push payloads
    const truncatedContent =
      message.content.length > 100
        ? message.content.substring(0, 100) + '…'
        : message.content;

    const title = `${authorName} in #${channel.name}`;
    const body = truncatedContent;

    // Get FCM access token to authenticate request
    const accessToken = await getFcmAccessToken();
    const fcmUrl = `https://fcm.googleapis.com/v1/projects/${firebaseProjectId}/messages:send`;

    let successCount = 0;
    
    // 6. Send via FCM HTTP v1 API
    // Note: FCM v1 API only accepts one message at a time, we need to Promise.all them
    const sendPromises = tokens.map(async (t: { token: string; user_id: string }) => {
      const fcmPayload = {
        message: {
          token: t.token,
          notification: {
            title,
            body,
          },
          data: {
            type: 'message',
            channel_id: message.channel_id,
            message_id: message.id,
            server_id: channel.server_id,
          },
          android: {
            priority: "high",
            notification: {
              channel_id: "messages",
              sound: "default",
            }
          },
          apns: {
            payload: {
              aps: {
                sound: "default",
              }
            }
          }
        }
      };

      const response = await fetch(fcmUrl, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          Authorization: `Bearer ${accessToken}`,
        },
        body: JSON.stringify(fcmPayload),
      });

      if (!response.ok) {
        console.error(`FCM push failed for token ${t.token}:`, await response.text());
      } else {
        successCount++;
      }
    });

    await Promise.all(sendPromises);

    return new Response(
      JSON.stringify({ sent: successCount, outOf: tokens.length }),
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
