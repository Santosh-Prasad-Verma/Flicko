// =============================================================================
// k6 Realtime WebSocket fan-out load test  (Supabase Realtime / Phoenix proto)
// =============================================================================
// The app connects to Supabase Realtime at:
//   wss://<project>.supabase.co/realtime/v1/websocket?apikey=<anon>&vsn=1.0.0
// (see mobile/lib/core/services/presence_service.dart). This test measures the
// metric that actually breaks Discord-like apps under load: end-to-end message
// PROPAGATION LATENCY as the number of concurrent subscribers on one channel
// grows.
//
// Design: every VU joins the SAME broadcast topic and periodically sends a
// broadcast carrying a send-timestamp. Every VU receives every broadcast and
// records (now - sent_at) into a Trend. With N connected VUs, each broadcast
// fans out to N receivers — so this directly stresses realtime fan-out.
//
// Broadcast (not postgres_changes) is used so the test is self-contained and
// needs no DB writes. A postgres_changes variant is sketched at the bottom.
//
// Run locally:
//   k6 run scripts/k6-realtime-ws-test.js \
//     -e SUPABASE_URL=https://YOURPROJ.supabase.co \
//     -e SUPABASE_ANON_KEY=eyJ...
//
// !!! Point this at a DEDICATED TEST/STAGING project, never production. !!!
// =============================================================================
import { WebSocket } from 'k6/experimental/websockets';
import { setInterval, clearInterval, setTimeout } from 'k6/experimental/timers';
import { Trend, Counter } from 'k6/metrics';
import { check } from 'k6';

// --- Custom metrics ---------------------------------------------------------
const propagationLatency = new Trend('realtime_propagation_ms', true);
const messagesReceived = new Counter('realtime_messages_received');
const joinErrors = new Counter('realtime_join_errors');

// --- Config -----------------------------------------------------------------
const SUPABASE_URL = __ENV.SUPABASE_URL || 'http://localhost:54321';
const ANON_KEY = __ENV.SUPABASE_ANON_KEY || 'anon-key-not-set';
const TOPIC = 'realtime:load-test-room';
const WS_URL =
  `${SUPABASE_URL.replace(/^http/, 'ws')}/realtime/v1/websocket` +
  `?apikey=${ANON_KEY}&vsn=1.0.0`;

export const options = {
  scenarios: {
    // Ramp concurrent subscribers to find the fan-out ceiling.
    realtime_fanout: {
      executor: 'ramping-vus',
      startVUs: 0,
      stages: [
        { duration: '20s', target: 50 },   // warm up
        { duration: '30s', target: 200 },  // ramp
        { duration: '1m', target: 200 },   // sustained peak
        { duration: '15s', target: 0 },    // drain
      ],
      gracefulStop: '10s',
    },
  },
  thresholds: {
    // Publish -> receive propagation. Target < 500ms; fail the run if p95 > 2s.
    realtime_propagation_ms: ['p(95)<2000', 'p(99)<5000'],
    // Joining a channel should almost never fail.
    realtime_join_errors: ['count<10'],
  },
};

export default function () {
  const ws = new WebSocket(WS_URL);
  let heartbeat;
  let publisher;
  let refCounter = 0;
  const nextRef = () => String(++refCounter);

  ws.onopen = () => {
    // 1. Join the topic as a broadcast channel (self:true so we also receive
    //    our own sends and can measure loopback latency deterministically).
    ws.send(
      JSON.stringify({
        topic: TOPIC,
        event: 'phx_join',
        payload: {
          config: {
            broadcast: { self: true, ack: false },
            presence: { key: '' },
            postgres_changes: [],
          },
          access_token: ANON_KEY,
        },
        ref: nextRef(),
      }),
    );

    // 2. Phoenix requires a heartbeat or the socket is culled (~30s).
    heartbeat = setInterval(() => {
      ws.send(
        JSON.stringify({
          topic: 'phoenix',
          event: 'heartbeat',
          payload: {},
          ref: nextRef(),
        }),
      );
    }, 25000);

    // 3. Publish a broadcast every 3s carrying a high-res send timestamp.
    publisher = setInterval(() => {
      ws.send(
        JSON.stringify({
          topic: TOPIC,
          event: 'broadcast',
          payload: {
            type: 'broadcast',
            event: 'ping',
            payload: { sent_at: Date.now(), vu: __VU },
          },
          ref: nextRef(),
        }),
      );
    }, 3000);

    // 4. Each VU lives ~60s then closes; ramping executor handles concurrency.
    setTimeout(() => ws.close(), 60000);
  };

  ws.onmessage = (e) => {
    const msg = JSON.parse(e.data);

    // Confirm the join succeeded.
    if (msg.event === 'phx_reply') {
      const ok = msg.payload && msg.payload.status === 'ok';
      check(ok, { 'channel join ok': (v) => v === true });
      if (!ok) joinErrors.add(1);
      return;
    }

    // A broadcast fanned out to us — record propagation latency.
    if (msg.event === 'broadcast' && msg.payload && msg.payload.payload) {
      const sentAt = msg.payload.payload.sent_at;
      if (typeof sentAt === 'number') {
        propagationLatency.add(Date.now() - sentAt);
        messagesReceived.add(1);
      }
    }
  };

  ws.onerror = (e) => {
    joinErrors.add(1);
    // eslint-disable-next-line no-console
    console.error(`ws error (VU ${__VU}): ${e && e.error}`);
  };

  ws.onclose = () => {
    if (heartbeat) clearInterval(heartbeat);
    if (publisher) clearInterval(publisher);
  };
}

// =============================================================================
// VARIANT: postgres_changes propagation (closer to the real message path)
// -----------------------------------------------------------------------------
// To measure the TRUE user-visible path (INSERT into messages -> realtime
// notify -> client), have subscribers join with:
//     postgres_changes: [{ event: 'INSERT', schema: 'public', table: 'messages',
//                          filter: 'channel_id=eq.<uuid>' }]
// and run a SEPARATE writer (k6 http scenario or a small Go loop) that INSERTs
// rows via PostgREST with an embedded created_at. Subscribers then compute
// latency from the row's created_at to receive time. Requires a valid user JWT
// (RLS) and a seeded test channel — heavier setup, so keep it as a nightly job.
// =============================================================================
