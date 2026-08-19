import { app, HttpRequest, HttpResponseInit, InvocationContext } from "@azure/functions";
import jwt from "jsonwebtoken";
import fetch from "node-fetch";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, content-type',
};

export async function auraTtsHandler(request: HttpRequest, context: InvocationContext): Promise<HttpResponseInit> {
  if (request.method === 'OPTIONS') {
    return { status: 204, headers: corsHeaders };
  }

  const ELEVENLABS_API_KEY = process.env.ELEVENLABS_API_KEY;
  const JWT_SECRET = process.env.JWT_SECRET || '';

  try {
    const authHeader = request.headers.get('authorization');
    if (!authHeader) {
      return { status: 401, headers: corsHeaders, jsonBody: { error: 'Missing authorization' } };
    }

    const token = authHeader.replace('Bearer ', '');
    try {
      jwt.verify(token, JWT_SECRET);
    } catch (err) {
      return { status: 401, headers: corsHeaders, jsonBody: { error: 'Invalid token' } };
    }

    const body = (await request.json()) as any;
    const text = body?.text;
    if (!text) {
      return { status: 400, headers: corsHeaders, jsonBody: { error: 'text is required' } };
    }

    if (ELEVENLABS_API_KEY) {
      const voiceId = body?.voiceId || '21m00Tcm4TlvDq8ikWAM';
      const res = await fetch(`https://api.elevenlabs.io/v1/text-to-speech/${voiceId}`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'xi-api-key': ELEVENLABS_API_KEY,
        },
        body: JSON.stringify({
          text,
          model_id: 'eleven_turbo_v2_5',
          voice_settings: { stability: 0.5, similarity_boost: 0.75 }
        })
      });

      if (res.ok) {
        const audioBuffer = await res.arrayBuffer();
        return {
          status: 200,
          headers: { ...corsHeaders, 'Content-Type': 'audio/mpeg' },
          body: Buffer.from(audioBuffer)
        };
      }
    }

    return { status: 500, headers: corsHeaders, jsonBody: { error: 'TTS service unavailable' } };
  } catch (err: any) {
    context.error('aura-tts error:', err);
    return { status: 500, headers: corsHeaders, jsonBody: { error: err.message || 'Internal server error' } };
  }
}

app.http('aura-tts', {
  methods: ['POST', 'OPTIONS'],
  authLevel: 'anonymous',
  handler: auraTtsHandler,
});
