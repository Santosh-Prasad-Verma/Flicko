import { app, HttpRequest, HttpResponseInit, InvocationContext } from "@azure/functions";
import jwt from "jsonwebtoken";
import fetch from "node-fetch";
import { Pool } from "pg";

const pool = new Pool({
  connectionString: process.env.DATABASE_URL
});

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, content-type',
};

export async function chatSummaryHandler(request: HttpRequest, context: InvocationContext): Promise<HttpResponseInit> {
  if (request.method === 'OPTIONS') {
    return { status: 204, headers: corsHeaders };
  }

  const GEMINI_API_KEY = process.env.GEMINI_API_KEY || process.env.FLICKO_GEMINI_API_KEY;
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
    const { channelId, limit = 50 } = body;

    if (!channelId) {
      return { status: 400, headers: corsHeaders, jsonBody: { error: 'channelId is required' } };
    }

    const msgRes = await pool.query(`
      SELECT m.content, p.username
      FROM public.messages m
      LEFT JOIN public.profiles p ON m.author_id = p.id
      WHERE m.channel_id = $1
      ORDER BY m.created_at DESC
      LIMIT $2
    `, [channelId, limit]);

    if (msgRes.rows.length === 0) {
      return { status: 200, headers: corsHeaders, jsonBody: { summary: "No recent messages to summarize." } };
    }

    const chatText = msgRes.rows.map(r => `${r.username || 'User'}: ${r.content}`).reverse().join('\n');

    if (GEMINI_API_KEY) {
      const prompt = `Summarize the following channel conversation into concise bullet points with key decisions and takeaways:\n\n${chatText}`;
      const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${GEMINI_API_KEY}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: [{ parts: [{ text: prompt }] }]
        })
      });

      if (res.ok) {
        const data = (await res.json()) as any;
        const summary = data.candidates?.[0]?.content?.parts?.[0]?.text || "Summary generated.";
        return { status: 200, headers: corsHeaders, jsonBody: { summary } };
      }
    }

    return { status: 200, headers: corsHeaders, jsonBody: { summary: "Summary unavailable." } };
  } catch (err: any) {
    context.error('chat-summary error:', err);
    return { status: 500, headers: corsHeaders, jsonBody: { error: err.message || 'Internal server error' } };
  }
}

app.http('chat-summary', {
  methods: ['POST', 'OPTIONS'],
  authLevel: 'anonymous',
  handler: chatSummaryHandler,
});
