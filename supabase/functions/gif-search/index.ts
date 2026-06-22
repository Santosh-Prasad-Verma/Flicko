// @ts-nocheck — Supabase Edge Functions run on Deno, not Node.js
/**
 * Supabase Edge Function: gif-search
 *
 * Proxies GIPHY API requests to keep the API key server-side.
 * Required env var: GIPHY_API_KEY
 *
 * Endpoints:
 *   GET /gif-search?q=<query>&offset=0&limit=20 → search results
 *   GET /gif-search?trending=true&offset=0&limit=20 → trending GIFs
 *
 * Response shape (normalised for the mobile client):
 *   { results: GifResult[], offset: number, totalCount: number }
 *
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { Redis } from "https://esm.sh/@upstash/redis";
import { createClient } from "https://esm.sh/@supabase/supabase-js@2";
import { Redis } from "https://esm.sh/@upstash/redis";
 * Requirements: Feature 13 (GIF Integration - Zero Cost)
 */
import { serve } from 'https://deno.land/std@0.177.0/http/server.ts';
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2';
import { Redis } from 'https://esm.sh/@upstash/redis';

const GIPHY_BASE = 'https://api.giphy.com/v1/gifs';
const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

interface GiphyImage {
  url?: string;
  width?: string;
  height?: string;
}

interface GiphyImages {
  fixed_width?: GiphyImage;
  original?: GiphyImage;
}

interface GiphyItem {
  id: string;
  title?: string;
  images?: GiphyImages;
}

/** Map a raw GIPHY item to the compact shape the mobile client expects. */
function normaliseGif(item: GiphyItem) {
  const fw = item.images?.fixed_width;
  const orig = item.images?.original;
  return {
    id: item.id,
    title: item.title || '',
    url: fw?.url || orig?.url || '',         // send-quality URL
    previewUrl: fw?.url || orig?.url || '',   // preview thumbnail
    width: parseInt(fw?.width || orig?.width || '200', 10),
    height: parseInt(fw?.height || orig?.height || '200', 10),
  };
}

serve(async (req) => {
  // Handle CORS preflight
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders });
  }

  const apiKey = Deno.env.get('GIPHY_API_KEY');
  if (!apiKey) {
    return new Response(
      JSON.stringify({ error: 'GIPHY_API_KEY not configured' }),
      { status: 500, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }

  // Check rate limit if UPSTASH is configured
  const authHeader = req.headers.get('Authorization');
  const upstashUrl = Deno.env.get('UPSTASH_REDIS_REST_URL');
  const upstashToken = Deno.env.get('UPSTASH_REDIS_REST_TOKEN');

  if (authHeader && upstashUrl && upstashToken) {
    try {
      const supabaseClient = createClient(
        Deno.env.get('SUPABASE_URL') || '',
        Deno.env.get('SUPABASE_ANON_KEY') || '',
        { global: { headers: { Authorization: authHeader } } }
      );
      const { data: { user } } = await supabaseClient.auth.getUser();
      if (user) {
        const redis = new Redis({ url: upstashUrl, token: upstashToken });
        const rlKey = `rate_limit:gif_search:${user.id}`;
        
        // 10 requests per minute
        const requests = await redis.incr(rlKey);
        if (requests === 1) {
          await redis.expire(rlKey, 60);
        }

        if (requests > 10) {
          return new Response(
            JSON.stringify({ error: 'Rate limit exceeded (10 requests/minute)' }),
            { status: 429, headers: { ...corsHeaders, 'Content-Type': 'application/json' } }
          );
        }
      }
    } catch (e) {
      console.error('Rate limiting error:', e);
    }
  }

  const url = new URL(req.url);
  const query = url.searchParams.get('q');
  const offset = parseInt(url.searchParams.get('offset') || '0', 10);
  const limit = Math.min(parseInt(url.searchParams.get('limit') || '20', 10), 50);
  const trending = url.searchParams.get('trending');

  try {
    let giphyUrl: string;

    if (trending === 'true') {
      giphyUrl = `${GIPHY_BASE}/trending?api_key=${apiKey}&limit=${limit}&offset=${offset}&rating=pg-13`;
    } else if (query) {
      giphyUrl = `${GIPHY_BASE}/search?api_key=${apiKey}&q=${encodeURIComponent(query)}&limit=${limit}&offset=${offset}&rating=pg-13&lang=en`;
    } else {
      return new Response(
        JSON.stringify({ error: 'Missing query parameter: q or trending' }),
        { status: 400, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
      );
    }

    const response = await fetch(giphyUrl);
    const data = await response.json();

    const results = (data.data ?? []).map(normaliseGif);
    const totalCount = data.pagination?.total_count ?? 0;
    const nextOffset = offset + results.length;

    return new Response(
      JSON.stringify({ results, offset: nextOffset, totalCount }),
      {
        status: 200,
        headers: {
          ...corsHeaders,
          'Content-Type': 'application/json',
          'Cache-Control': 'public, max-age=300', // Cache for 5 min
        },
      },
    );
  } catch (err) {
    return new Response(
      JSON.stringify({ error: 'Failed to fetch from GIPHY', details: String(err) }),
      { status: 502, headers: { ...corsHeaders, 'Content-Type': 'application/json' } },
    );
  }
});
