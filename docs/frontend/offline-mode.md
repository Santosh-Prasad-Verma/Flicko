# Offline & Reconnection Logic

> **Reading time:** ~6 minutes · **Audience:** Mobile Developers · **Last Updated:** 2026-04-11

Mobile networks drop constantly. Driving through a tunnel should not cause the Flicko app to white-screen or lose the user's typed drafts.

---

## The Network Automaton

Our networking strategy is controlled by an interceptor automaton that monitors `NetInfo` from `@react-native-community/netinfo`.

When the OS reports `isConnected: false`:
1. The app renders a discreet "Connecting..." banner at the top of the UI.
2. The WebSocket dispatcher suppresses standard disconnect warning modals.
3. React Query enters "paused" state. Any `POST/PUT/PATCH` requests triggered by the user UI are caught by an Dio interceptor and placed into a volatile memory queue.

When `isConnected: true` returns:
1. The `useWebSocket` hook instantly attempts a reconnection to `ws-gateway`.
2. React Query automatically invalidates active queries (`refetchOnReconnect: true`), ensuring the UI fetches any messages missed while offline.
3. The Dio interceptor automatically pops pending mutations off the memory queue and executes them in order.

---

## Optimistic Message Queueing

If a user hits "Send" while in an elevator (Offline):
1. The `messageStore.ts` assigns the temporary message UUID.
2. The UI renders the message normally, but gives it a grey clock icon indicating `status: 'pending'`.
3. The network request is caught by the Dio Offline Interceptor.
4. If the user force-closes the app *while still offline*, the message is lost (we intentionally do not persist the outbound queue to disk to prevent complex conflict resolution bugs upon app reboot).

---

## React Query Persister

To ensure incredibly fast "Cold Boot" times to interactive paint, the React Query cache is flushed to disk using Async Storage (`@tanstack/react-query-persist-client`).

**Boot Sequence:**
1. App is tapped. Splash screen shows.
2. `persistClient` hydrates the last known JSON payload from the disk into memory.
3. The `<MessageFeed />` renders the chat exactly as the user left it yesterday, allowing them to read old messages while the app is still secretly establishing the WebSocket connection in the background.
4. Once the WebSocket connects and the background REST validation completes, any new messages jump into the screen seamlessly.

---

## WebSocket Flutternential Backoff

If the `ws-gateway` server restarts for a deployment, thousands of clients will drop simultaneously.
If they all retried instantly via a `setInterval(reconnect, 1000)`, they would inadvertently execute a DDoS attack against our own load balancer.

The `useWebSocket` hook implements jittered exponential backoff:
- Attempt 1: 500ms
- Attempt 2: 1s + random(0, 500ms)
- Attempt 3: 2s + random(0, 1000ms)
- Attempt N: Math.min(attempt^2, 30s)

This smears the reconnection storm safely across a 30-second window.
