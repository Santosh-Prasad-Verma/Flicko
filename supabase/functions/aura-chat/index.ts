// @ts-nocheck — Supabase Edge Functions run on Deno, not Node.js
/**
 * Supabase Edge Function: aura-chat
 *
 * Server-side proxy for Aura AI chat.
 * Calls xAI Grok API with the XAI_API_KEY stored in Supabase secrets.
 * The API key NEVER reaches the frontend.
 *
 * POST /aura-chat
 * Body: {
 *   messages: Array<{ role: 'user' | 'assistant' | 'system', content: string }>,
 *   category?: string
 * }
 *
 * Returns: { text: string, functionCall?: { name: string, args: object } }
 */
import { serve } from 'https://deno.land/std@0.208.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

const SYSTEM_PROMPTS: Record<string, string> = {
  'Text Writer': `You are Aura, a premium AI assistant inside the Flicko messaging app. You are warm, knowledgeable, and conversational. Respond concisely but helpfully. Use markdown formatting when appropriate. You can discuss any topic — technology, science, health, lifestyle, creative writing, and more.`,
  'Image Generator': `You are Aura, an AI image description specialist inside the Flicko app. When users request images, describe them vividly. If you cannot generate images directly, provide a detailed creative description of what the image would look like.`,
  'Code Tutor': `You are Aura, an expert programming tutor inside the Flicko app. You specialize in Flutter/Dart, JavaScript/TypeScript, Python, Go, and modern web technologies. Provide clear code examples with explanations. Use markdown code blocks with language tags.`,
};

const TOOLS = [
  {
    type: 'function',
    function: {
      name: 'play_song',
      description: 'Play a specific song or search and play music on Sonic Drip.',
      parameters: {
        type: 'object',
        properties: {
          query: {
            type: 'string',
            description: 'The song title or search query.',
          },
        },
        required: ['query'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'send_dm',
      description: 'Send a direct message to a user/friend by name.',
      parameters: {
        type: 'object',
        properties: {
          recipientUsername: {
            type: 'string',
            description: 'The username or display name of the friend.',
          },
          message: {
            type: 'string',
            description: 'The text message content to send.',
          },
        },
        required: ['recipientUsername', 'message'],
      },
    },
  },
  {
    type: 'function',
    function: {
      name: 'list_servers',
      description: 'List the servers the user is currently joined to.',
      parameters: {
        type: 'object',
        properties: {},
      },
    },
  },
];

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

  const XAI_API_KEY = Deno.env.get('XAI_API_KEY');
  const SUPABASE_URL = Deno.env.get('SUPABASE_URL') || '';
  const SUPABASE_SERVICE_KEY = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') || Deno.env.get('SUPABASE_ANON_KEY') || '';

  if (!XAI_API_KEY) {
    return new Response(
      JSON.stringify({ error: 'Aura AI service is not configured (missing API key)' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }

  try {
    // 1. Authenticate user via Supabase JWT
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

    // 2. Parse request
    const body = await req.json();
    const { messages, category } = body;

    if (!messages || !Array.isArray(messages) || messages.length === 0) {
      return new Response(JSON.stringify({ error: 'messages array is required' }), {
        status: 400,
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
      });
    }

    // 3. Build system prompt
    const systemPrompt = SYSTEM_PROMPTS[category] || SYSTEM_PROMPTS['Text Writer'];

    let liveSuccess = false;
    let responseText = '';
    let functionCall: any = null;

    const GEMINI_API_KEY = Deno.env.get('GEMINI_API_KEY');

    // 4. Primary Engine: Google Gemini API (Supports Free Tier)
    if (GEMINI_API_KEY && GEMINI_API_KEY.trim().length > 0) {
      try {
        console.log('Attempting Gemini primary API call...');
        const geminiContents: any[] = [];
        let geminiSystemInstruction = systemPrompt;

        for (const m of messages) {
          const role = m.role || (m.sender === 'user' ? 'user' : 'assistant');
          const content = m.content || m.text || '';
          
          if (role === 'system') {
            geminiSystemInstruction = content;
          } else {
            geminiContents.push({
              role: role === 'assistant' ? 'model' : 'user',
              parts: [{ text: content }]
            });
          }
        }

        const geminiResponse = await fetch(
          `https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key=${GEMINI_API_KEY}`,
          {
            method: 'POST',
            headers: {
              'Content-Type': 'application/json',
            },
            body: JSON.stringify({
              contents: geminiContents,
              systemInstruction: {
                parts: [{ text: geminiSystemInstruction }]
              },
              generationConfig: {
                temperature: 0.7,
                maxOutputTokens: 2048,
              }
            }),
          }
        );

        if (geminiResponse.ok) {
          const geminiData = await geminiResponse.json();
          const text = geminiData.candidates?.[0]?.content?.parts?.[0]?.text;
          if (text) {
            responseText = text;
            liveSuccess = true;
            console.log('Gemini API call succeeded!');
          }
        } else {
          const errText = await geminiResponse.text();
          console.warn('Gemini API call failed with status:', geminiResponse.status, errText);
        }
      } catch (geminiError) {
        console.warn('Gemini API error occurred:', geminiError);
      }
    }

    // 5. Fallback Engine: xAI Grok completions
    if (!liveSuccess) {
      console.log('Falling back to xAI Grok API...');
      const xaiMessages = [
        { role: 'system', content: systemPrompt },
        ...messages.map((m: any) => ({
          role: m.role || (m.sender === 'user' ? 'user' : 'assistant'),
          content: m.content || m.text || '',
        })),
      ];

      const xaiResponse = await fetch('https://api.x.ai/v1/chat/completions', {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'Authorization': `Bearer ${XAI_API_KEY}`,
        },
        body: JSON.stringify({
          model: 'grok-beta',
          messages: xaiMessages,
          tools: TOOLS,
          temperature: 0.7,
          max_tokens: 2048,
        }),
      });

      if (!xaiResponse.ok) {
        const errBody = await xaiResponse.text();
        console.error('xAI API error:', xaiResponse.status, errBody);
        return new Response(
          JSON.stringify({ error: `xAI API error: ${xaiResponse.status}`, details: errBody }),
          { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
        );
      }

      const xaiData = await xaiResponse.json();
      const choice = xaiData.choices?.[0];

      if (!choice) {
        return new Response(
          JSON.stringify({ error: 'No response from Grok' }),
          { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
        );
      }

      const message = choice.message;
      if (message.tool_calls && message.tool_calls.length > 0) {
        const toolCall = message.tool_calls[0];
        functionCall = {
          name: toolCall.function.name,
          args: JSON.parse(toolCall.function.arguments || '{}'),
        };
        responseText = message.content || '';
      } else {
        responseText = message.content || '';
      }
      liveSuccess = true;
    }

    const result: any = { text: responseText };
    if (functionCall) {
      result.functionCall = functionCall;
    }

    return new Response(JSON.stringify(result), {
      status: 200,
      headers: { ...corsHeaders, 'Content-Type': 'application/json' },
    });
  } catch (err: any) {
    console.error('aura-chat error:', err);
    return new Response(
      JSON.stringify({ error: err?.message || 'Internal server error' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
});
