import { app, HttpRequest, HttpResponseInit, InvocationContext } from "@azure/functions";
import jwt from "jsonwebtoken";
import fetch from "node-fetch";

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'GET, POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, content-type',
};

export async function gifSearchHandler(request: HttpRequest, context: InvocationContext): Promise<HttpResponseInit> {
  if (request.method === 'OPTIONS') {
    return { status: 204, headers: corsHeaders };
  }

  const TENOR_API_KEY = process.env.TENOR_API_KEY;
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

    let q = request.query.get('q') || 'trending';
    if (request.method === 'POST') {
      const body = (await request.json()) as any;
      if (body?.q) q = body.q;
    }

    if (TENOR_API_KEY) {
      const url = `https://tenor.googleapis.com/v2/search?q=${encodeURIComponent(q)}&key=${TENOR_API_KEY}&limit=20&media_filter=gif,tinygif`;
      const res = await fetch(url);
      if (res.ok) {
        const data = await res.json();
        return { status: 200, headers: corsHeaders, jsonBody: data };
      }
    }

    return { status: 200, headers: corsHeaders, jsonBody: { results: [] } };
  } catch (err: any) {
    context.error('gif-search error:', err);
    return { status: 500, headers: corsHeaders, jsonBody: { error: err.message || 'Internal server error' } };
  }
}

app.http('gif-search', {
  methods: ['GET', 'POST', 'OPTIONS'],
  authLevel: 'anonymous',
  handler: gifSearchHandler,
});
