// @ts-nocheck — Deno runtime
import { serve } from 'https://deno.land/std@0.208.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

serve(async (req: Request) => {
  if (req.method === 'OPTIONS') {
    return new Response(null, { headers: corsHeaders });
  }

  if (req.method !== 'POST') {
    return new Response(JSON.stringify({ error: 'Method not allowed' }), {
      status: 405,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }

  const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY');
  const XAI_API_KEY = Deno.env.get('XAI_API_KEY');
  const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || '';
  const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || Deno.env.get('SUPABASE_ANON_KEY') || '';

  try {
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
      return new Response(JSON.stringify({ error: 'Invalid token' }), {
        status: 401,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const body = await req.json();
    const { messages } = body;

    if (!messages || !Array.isArray(messages)) {
      return new Response(JSON.stringify({ error: 'messages array is required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    const systemPrompt = `You are Aura, an AI summarization assistant inside the Flicko messaging app.
Summarize the following chat conversation into a concise bulleted list. Focus on key decisions, questions raised, and main topics.
Be conversational but highly structured and brief. Use markdown bullet points. Return only the summary text.`;

    const chatContent = messages.map(m => `${m.sender || m.role || 'User'}: ${m.content || m.text || ''}`).join('\n');

    let summaryText = '';
    let success = false;

    // Try Gemini
    if (GEMINI_API_KEY) {
      try {
        const geminiResponse = await fetch(
          `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${GEMINI_API_KEY}`,
          {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
              contents: [{ role: 'user', parts: [{ text: `${systemPrompt}\n\nChat history:\n${chatContent}` }] }],
              generationConfig: { temperature: 0.3, maxOutputTokens: 1024 }
            }),
          }
        );

        if (geminiResponse.ok) {
          const geminiData = await geminiResponse.json();
          summaryText = geminiData.candidates?.[0]?.content?.parts?.[0]?.text || '';
          if (summaryText) success = true;
        }
      } catch (err) {
        console.warn('Gemini summary error:', err);
      }
    }

    // Try Grok/XAI if Gemini is missing or failed
    if (!success && XAI_API_KEY) {
      try {
        const xaiResponse = await fetch('https://api.x.ai/v1/chat/completions', {
          method: 'POST',
          headers: {
            'Content-Type': 'application/json',
            'Authorization': `Bearer ${XAI_API_KEY}`,
          },
          body: JSON.stringify({
            model: 'grok-beta',
            messages: [
              { role: 'system', content: systemPrompt },
              { role: 'user', content: chatContent }
            ],
            temperature: 0.3,
            max_tokens: 1024,
          }),
        });

        if (xaiResponse.ok) {
          const xaiData = await xaiResponse.json();
          summaryText = xaiData.choices?.[0]?.message?.content || '';
          if (summaryText) success = true;
        }
      } catch (err) {
        console.warn('XAI summary error:', err);
      }
    }

    if (!success) {
      return new Response(JSON.stringify({ error: 'AI summarization service unavailable' }), {
        status: 502,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    return new Response(JSON.stringify({ summary: summaryText }), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (err: any) {
    console.error('chat-summary error:', err);
    return new Response(JSON.stringify({ error: err?.message || 'Internal server error' }), {
      status: 500,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  }
});
