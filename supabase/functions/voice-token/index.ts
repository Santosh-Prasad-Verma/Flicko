// @ts-nocheck — Supabase Edge Functions run on Deno, not Node.js
/**
 * Supabase Edge Function: voice-token (v2)
 *
 * Enhanced to support video, screen share, and Go Live streaming.
 * Generates LiveKit access tokens with granular media grants.
 *
 * POST /voice-token
 * Body: {
 *   channelId, serverId,
 *   video?: boolean,
 *   screenShare?: boolean,
 *   streamTitle?: string,
 *   streamType?: 'screen' | 'application' | 'game' | 'camera',
 *   quality?: '720p15' | '720p30' | '1080p30' | '1080p60'
 * }
 *
 * Zero-cost: Self-hosted LiveKit on Oracle Cloud Always Free tier
 */
import { serve } from 'https://deno.land/std@0.208.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { create, getNumericDate } from 'https://deno.land/x/djwt@v3.0.1/mod.ts';

interface TokenRequest {
  channelId: string;
  serverId: string;
  video?: boolean;
  screenShare?: boolean;
  streamTitle?: string;
  streamType?: 'screen' | 'application' | 'game' | 'camera';
  quality?: '720p15' | '720p30' | '1080p30' | '1080p60';
}

const QUALITY_PRESETS: Record<string, { width: number; height: number; fps: number; bitrate: number }> = {
  '720p15':  { width: 1280, height: 720,  fps: 15, bitrate: 1_500_000 },
  '720p30':  { width: 1280, height: 720,  fps: 30, bitrate: 2_500_000 },
  '1080p30': { width: 1920, height: 1080, fps: 30, bitrate: 4_000_000 },
  '1080p60': { width: 1920, height: 1080, fps: 60, bitrate: 6_000_000 },
};

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req: Request) => {
  // CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const LIVEKIT_API_KEY = Deno.env.get('LIVEKIT_API_KEY');
  const LIVEKIT_API_SECRET = Deno.env.get('LIVEKIT_API_SECRET');
  const LIVEKIT_URL = Deno.env.get('LIVEKIT_URL') || 'wss://livekit.yourdomain.com';
  const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || '';
  const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || '';

  if (!LIVEKIT_API_KEY || !LIVEKIT_API_SECRET || !LIVEKIT_URL || !SUPABASE_URL || !SUPABASE_SERVICE_KEY) {
    return new Response(
      JSON.stringify({ error: 'Voice token service is not configured' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }

  try {
    // 1. Authenticate user
    const authHeader = req.headers.get('authorization');
    if (!authHeader) {
      return new Response(JSON.stringify({ error: 'Missing authorization' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const supabase = createClient(SUPABASE_URL, SUPABASE_SERVICE_KEY);
    const userToken = authHeader.replace('Bearer ', '');
    const { data: { user }, error: authError } = await supabase.auth.getUser(userToken);

    if (authError || !user) {
      console.error('Auth error:', authError);
      return new Response(JSON.stringify({ error: 'Invalid token' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // 2. Parse request
    const body: TokenRequest = await req.json();
    const { channelId, serverId, video, screenShare, streamTitle, streamType, quality } = body;

    if (!channelId || !serverId) {
      return new Response(JSON.stringify({ error: 'channelId and serverId required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const isDm = serverId === 'dm';

    if (isDm) {
      if (!channelId.includes(user.id)) {
        return new Response(JSON.stringify({ error: 'Access denied: user is not part of this DM channel' }), {
          status: 403,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }
    } else {
      // 3. Verify membership
      const { data: member, error: memberError } = await supabase
        .from('server_members')
        .select('id')
        .eq('server_id', serverId)
        .eq('user_id', user.id)
        .single();

      if (memberError || !member) {
        console.error('Member error:', memberError);
        return new Response(JSON.stringify({ error: 'Not a server member' }), {
          status: 403,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      // 4. Verify channel exists and is voice/stage type
      const { data: channel, error: channelError } = await supabase
        .from('channels')
        .select('id, type, user_limit')
        .eq('id', channelId)
        .eq('server_id', serverId)
        .single();

      if (channelError || !channel || !['voice', 'stage'].includes(channel.type)) {
        console.error('Channel error:', channelError, 'Channel data:', channel);
        return new Response(JSON.stringify({ error: 'Invalid voice channel' }), {
          status: 400,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      // 5. Check user limit
      if (channel.user_limit && channel.user_limit > 0) {
        const { count, error: countError } = await supabase
          .from('voice_states')
          .select('id', { count: 'exact', head: true })
          .eq('channel_id', channelId);

        if (countError) {
          console.error('Voice states count error:', countError);
        }

        if (count && count >= channel.user_limit) {
          return new Response(JSON.stringify({ error: 'Channel is full' }), {
            status: 409,
            headers: { ...corsHeaders, 'Content-Type': 'application/json' },
          });
        }
      }

      // 6. Check screen share slot availability (max 1 in free tier)
      if (screenShare) {
        const { count: screenShareCount } = await supabase
          .from('voice_states')
          .select('user_id', { count: 'exact', head: true })
          .eq('channel_id', channelId)
          .eq('is_streaming', true);

        const maxScreenShares = 1;
        if (screenShareCount && screenShareCount >= maxScreenShares) {
          return new Response(
            JSON.stringify({ error: 'Screen share slot taken', code: 'SCREEN_SHARE_LIMIT' }),
            { status: 409, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
          );
        }
      }
    }

    // 7. Get user profile for participant identity
    const { data: profile } = await supabase
      .from('profiles')
      .select('username, avatar')
      .eq('id', user.id)
      .single();

    // 8. Build LiveKit room name
    const roomName = isDm ? channelId : `channel_${channelId}`;

    // 9. Build video grant with granular permissions
    const canPublishSources = ['microphone'];
    if (video) canPublishSources.push('camera');
    if (screenShare) canPublishSources.push('screen_share', 'screen_share_audio');

    // 10. Generate LiveKit-compatible JWT
    const key = await crypto.subtle.importKey(
      'raw',
      new TextEncoder().encode(LIVEKIT_API_SECRET),
      { name: 'HMAC', hash: 'SHA-256' },
      false,
      ['sign'],
    );

    const now = Math.floor(Date.now() / 1000);
    const livekitToken = await create(
      { alg: 'HS256', typ: 'JWT' },
      {
        iss: LIVEKIT_API_KEY,
        sub: user.id,
        name: profile?.username || 'Unknown',
        nbf: now,
        exp: getNumericDate(24 * 60 * 60), // 24 hours
        video: {
          roomJoin: true,
          room: roomName,
          canPublish: true,
          canSubscribe: true,
          canPublishData: true,
          canPublishSources,
        },
        metadata: JSON.stringify({
          avatarUrl: profile?.avatar || '',
          serverId,
          channelId,
        }),
      },
      key,
    );

    // 11. Upsert voice state (only for servers)
    let streamId: string | null = null;
    if (!isDm) {
      const { error: upsertError } = await supabase.from('voice_states').upsert({
        user_id: user.id,
        channel_id: channelId,
        server_id: serverId,
        session_id: crypto.randomUUID(),
        is_video: video || false,
        is_streaming: screenShare || false,
        is_muted: false,
        is_deafened: false,
        is_self_muted: false,
        is_self_deafened: false,
        suppress: false,
        joined_at: new Date().toISOString(),
        updated_at: new Date().toISOString(),
      }, {
        onConflict: 'user_id',
      });

      if (upsertError) {
        console.error('Voice state upsert error:', upsertError);
        return new Response(JSON.stringify({ error: 'Failed to join voice channel' }), {
          status: 500,
          headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        });
      }

      // 12. If Go Live stream, create stream record
      if (screenShare && streamTitle) {
        const selectedQuality = quality || '720p30';
        const { data: stream, error: streamError } = await supabase
          .from('streams')
          .insert({
            user_id: user.id,
            channel_id: channelId,
            server_id: serverId,
            title: streamTitle,
            status: 'starting',
            stream_type: streamType || 'screen',
            max_quality: selectedQuality,
          })
          .select('id')
          .single();
      
        if (streamError) {
          console.error('Stream insert error:', streamError);
        }

        streamId = stream?.id || null;
      }
    }

    // 13. Build quality config for client
    const qualityKey = quality || '720p30';
    const qualityConfig = QUALITY_PRESETS[qualityKey];

    return new Response(
      JSON.stringify({
        token: livekitToken,
        room: roomName,
        streamId,
        qualityConfig,
        serverUrl: LIVEKIT_URL,
      }),
      {
        status: 200,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      },
    );
  } catch (err) {
    const errorMsg = err instanceof Error ? err.message : 'Internal server error';
    console.error('voice-token error:', err);
    return new Response(JSON.stringify({ error: errorMsg }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
