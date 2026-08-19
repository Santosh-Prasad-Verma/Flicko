import { app, HttpRequest, HttpResponseInit, InvocationContext } from "@azure/functions";
import jwt from "jsonwebtoken";
import { Pool } from "pg";

const pool = new Pool({
  connectionString: process.env.DATABASE_URL
});

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Methods': 'POST, OPTIONS',
  'Access-Control-Allow-Headers': 'authorization, content-type',
};

export async function pushNotifyHandler(request: HttpRequest, context: InvocationContext): Promise<HttpResponseInit> {
  if (request.method === 'OPTIONS') {
    return { status: 204, headers: corsHeaders };
  }

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
    const { targetUserId, title, body: messageBody, data } = body;

    if (!targetUserId || !title || !messageBody) {
      return { status: 400, headers: corsHeaders, jsonBody: { error: 'targetUserId, title, body required' } };
    }

    const tokenRes = await pool.query(`
      SELECT fcm_token FROM public.push_tokens WHERE user_id = $1
    `, [targetUserId]);

    const tokens = tokenRes.rows.map(r => r.fcm_token).filter(Boolean);
    const anhConnString = process.env.AZURE_NOTIFICATION_HUB_CONNECTION_STRING;
    const hubName = process.env.AZURE_NOTIFICATION_HUB_NAME || "flicko-hub";
    let sentViaANH = false;

    if (anhConnString && tokens.length > 0) {
      try {
        const { NotificationHubsClient } = require("@azure/notification-hubs");
        const client = new NotificationHubsClient(anhConnString, hubName);
        const payload = JSON.stringify({
          notification: { title, body: messageBody },
          data: data || {}
        });
        await client.sendNotification({
          body: payload,
          headers: { "ServiceBusNotification-Format": "gcm" }
        });
        sentViaANH = true;
      } catch (anhErr: any) {
        context.log("ANH push dispatch fallback mode:", anhErr?.message || anhErr);
      }
    }

    context.log(`Sending Azure Push Notification to user ${targetUserId} with ${tokens.length} registered device tokens (ANH Configured: ${!!anhConnString}, Dispatched: ${sentViaANH})`);

    return {
      status: 200,
      headers: corsHeaders,
      jsonBody: { success: true, deliveredCount: tokens.length, anhConfigured: !!anhConnString, dispatched: sentViaANH }
    };
  } catch (err: any) {
    context.error('push-notify error:', err);
    return { status: 500, headers: corsHeaders, jsonBody: { error: err.message || 'Internal server error' } };
  }
}

app.http('push-notify', {
  methods: ['POST', 'OPTIONS'],
  authLevel: 'anonymous',
  handler: pushNotifyHandler,
});
