import { app, HttpRequest, HttpResponseInit, InvocationContext } from "@azure/functions";
import jwt from "jsonwebtoken";
import { Pool } from "pg";

const pool = new Pool({
  connectionString: process.env.DATABASE_URL
});

const QUALITY_PRESETS: Record<string, { width: number; height: number; fps: number; bitrate: number }> = {
  '720p15':  { width: 1280, height: 720,  fps: 15, bitrate: 1_500_000 },
  '720p30':  { width: 1280, height: 720,  fps: 30, bitrate: 2_500_000 },
  '1080p30': { width: 1920, height: 1080, fps: 30, bitrate: 4_000_000 },
  '1080p60': { width: 1920, height: 1080, fps: 60, bitrate: 6_000_000 },
};

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, content-type',
};

export async function voiceTokenHandler(request: HttpRequest, context: InvocationContext): Promise<HttpResponseInit> {
  if (request.method === 'OPTIONS') {
    return { status: 204, headers: corsHeaders };
  }

  const JWT_SECRET = process.env.JWT_SECRET || 'flicko_secret';
  const ACS_CONN = process.env.AZURE_COMMUNICATION_CONNECTION_STRING || '';

  try {
    const authHeader = request.headers.get('authorization');
    if (!authHeader) {
      return { status: 401, headers: corsHeaders, jsonBody: { error: 'Missing authorization' } };
    }

    const token = authHeader.replace('Bearer ', '');
    let userId: string;
    try {
      const decoded = jwt.verify(token, JWT_SECRET) as any;
      userId = decoded.sub || decoded.user_id || decoded.id;
    } catch (err) {
      return { status: 401, headers: corsHeaders, jsonBody: { error: 'Invalid token' } };
    }

    const body = (await request.json()) as any;
    const { channelId, serverId, video, screenShare, streamTitle, streamType, quality } = body;

    if (!channelId || !serverId) {
      return { status: 400, headers: corsHeaders, jsonBody: { error: 'channelId and serverId required' } };
    }

    const isDm = serverId === 'dm';
    if (isDm) {
      if (!channelId.includes(userId)) {
        return { status: 403, headers: corsHeaders, jsonBody: { error: 'Access denied: not part of this DM channel' } };
      }
    } else {
      const memberRes = await pool.query('SELECT id FROM public.server_members WHERE server_id = $1 AND user_id = $2', [serverId, userId]);
      if (memberRes.rows.length === 0) {
        return { status: 403, headers: corsHeaders, jsonBody: { error: 'Not a server member' } };
      }

      const channelRes = await pool.query('SELECT id, type, user_limit FROM public.channels WHERE id = $1 AND server_id = $2', [channelId, serverId]);
      if (channelRes.rows.length === 0 || !['voice', 'stage'].includes(channelRes.rows[0].type)) {
        return { status: 400, headers: corsHeaders, jsonBody: { error: 'Invalid voice channel' } };
      }

      const channel = channelRes.rows[0];
      if (channel.user_limit && channel.user_limit > 0) {
        const countRes = await pool.query('SELECT COUNT(*) FROM public.voice_states WHERE channel_id = $1', [channelId]);
        if (parseInt(countRes.rows[0].count, 10) >= channel.user_limit) {
          return { status: 409, headers: corsHeaders, jsonBody: { error: 'Channel is full' } };
        }
      }
    }

    const profileRes = await pool.query('SELECT username, avatar_url FROM public.profiles WHERE id = $1', [userId]);
    const profile = profileRes.rows[0] || {};

    const roomName = isDm ? channelId : `channel_${channelId}`;

    let streamId: string | null = null;
    if (!isDm) {
      await pool.query(`
        INSERT INTO public.voice_states (user_id, channel_id, server_id, session_id, is_video, is_streaming, joined_at, updated_at)
        VALUES ($1, $2, $3, gen_random_uuid(), $4, $5, NOW(), NOW())
        ON CONFLICT (user_id) DO UPDATE SET channel_id = EXCLUDED.channel_id, is_video = EXCLUDED.is_video, is_streaming = EXCLUDED.is_streaming, updated_at = NOW()
      `, [userId, channelId, serverId, !!video, !!screenShare]);

      if (screenShare && streamTitle) {
        const streamRes = await pool.query(`
          INSERT INTO public.streams (user_id, channel_id, server_id, title, status, stream_type, max_quality)
          VALUES ($1, $2, $3, $4, 'starting', $5, $6)
          RETURNING id
        `, [userId, channelId, serverId, streamTitle, streamType || 'screen', quality || '720p30']);
        streamId = streamRes.rows[0]?.id || null;
      }
    }

    const qualityKey = quality || '720p30';
    const qualityConfig = QUALITY_PRESETS[qualityKey];

    // Generate ACS / Azure Calling Session token payload
    const sessionToken = jwt.sign(
      { sub: userId, room: roomName, name: profile.username || 'User', scopes: ['voip', 'video'] },
      JWT_SECRET,
      { expiresIn: '24h' }
    );

    return {
      status: 200,
      headers: corsHeaders,
      jsonBody: {
        token: sessionToken,
        room: roomName,
        streamId,
        qualityConfig,
        acsConnectionStringConfigured: !!ACS_CONN,
      }
    };
  } catch (err: any) {
    context.error('voice-token error:', err);
    return { status: 500, headers: corsHeaders, jsonBody: { error: err.message || 'Internal server error' } };
  }
}

app.http('voice-token', {
  methods: ['POST', 'OPTIONS'],
  authLevel: 'anonymous',
  handler: voiceTokenHandler,
});
