import { app, HttpRequest, HttpResponseInit, InvocationContext } from "@azure/functions";
import jwt from "jsonwebtoken";
import fetch from "node-fetch";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, content-type',
};

const SYSTEM_PROMPTS: Record<string, string> = {
  'Text Writer': `You are Aura, a premium AI assistant inside the Flicko messaging app. You are warm, knowledgeable, and conversational. Respond concisely but helpfully. Use markdown formatting when appropriate.`,
  'Image Generator': `You are Aura, an AI image description specialist inside the Flicko app. Describe images vividly.`,
  'Code Tutor': `You are Aura, an expert programming tutor inside the Flicko app. Provide clear code examples with explanations. Use markdown code blocks.`,
};

export async function auraChatHandler(request: HttpRequest, context: InvocationContext): Promise<HttpResponseInit> {
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
    const { messages, category } = body;

    if (!messages || !Array.isArray(messages) || messages.length === 0) {
      return { status: 400, headers: corsHeaders, jsonBody: { error: 'messages array is required' } };
    }

    const systemPrompt = SYSTEM_PROMPTS[category] || SYSTEM_PROMPTS['Text Writer'];

    if (GEMINI_API_KEY) {
      const geminiContents = messages.map((m: any) => ({
        role: (m.role === 'assistant' || m.sender === 'assistant') ? 'model' : 'user',
        parts: [{ text: m.content || m.text || '' }]
      }));

      const res = await fetch(`https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${GEMINI_API_KEY}`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          contents: geminiContents,
          systemInstruction: { parts: [{ text: systemPrompt }] },
          generationConfig: { temperature: 0.7, maxOutputTokens: 2048 }
        })
      });

      if (res.ok) {
        const data = (await res.json()) as any;
        const text = data.candidates?.[0]?.content?.parts?.[0]?.text || '';
        return { status: 200, headers: corsHeaders, jsonBody: { text } };
      }
    }

    return { status: 200, headers: corsHeaders, jsonBody: { text: "I'm Aura, your AI assistant. I'm operating in fallback mode!" } };
  } catch (err: any) {
    context.error('aura-chat error:', err);
    return { status: 500, headers: corsHeaders, jsonBody: { error: err.message || 'Internal server error' } };
  }
}

app.http('aura-chat', {
  methods: ['POST', 'OPTIONS'],
  authLevel: 'anonymous',
  handler: auraChatHandler,
});
