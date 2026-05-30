# APPFLOW: Zapier and Make Integration

## Flow A: Admin connects Zapier
1. Admin opens `zapier.com`, searches "Flicko", clicks "Connect".
2. Zapier opens our consent URL `auth.flicko.app/oauth/authorize?client_id=zapier&...` in a popup.
3. Admin signs in to Flicko if needed (Supabase session).
4. Consent screen lists servers admin manages and scope checkboxes (`messages.send`, `members.read`, etc).
5. Admin selects 2 servers and approves. Backend creates `oauth_tokens` row, returns code.
6. Zapier exchanges code at `POST /oauth/token`. Receives access plus refresh token.
7. Zapier calls `GET /api/v1/me` to verify and store the connection.
8. Admin returns to Zapier UI to build a Zap.

## Flow B: Build a Zap (Stripe to Flicko)
1. In Zapier, admin picks "Stripe charge failed" as trigger and "Flicko - Send DM" as action.
2. Zapier asks our app to render server picker (calls `GET /api/v1/zap/searches/servers` with token). Admin picks server.
3. Zapier asks for user picker. We expose `email` lookup. Admin types `billing@example.com`. Zapier calls `GET /api/v1/zap/searches/users?email=...`. Returns matching user id.
4. Admin maps Stripe charge fields into the DM body template.
5. Admin tests the Zap. Zapier calls `POST /api/v1/zap/actions/messages/dm` with payload. Backend validates token, scope, server allowlist, then calls internal messaging service.
6. DM appears in Flicko within 1 second. Test passes. Zap is live.

## Flow C: Trigger fires (Flicko to Make)
1. A user posts a message in #feedback. Internal NATS publishes `messages.created` event.
2. Trigger dispatcher receives event. Looks up subscriptions in the in-memory index for `messages.created` on this server.
3. Match found: subscription belongs to a Make scenario watching channel `feedback`.
4. Filters evaluated: payload channel id matches. Pass.
5. Delivery job enqueued. Worker POSTs JSON to `https://hook.eu1.make.com/abc...` with HMAC header.
6. Make returns 200. `zap_triggers.last_success_at` updated. Counter incremented.

## Flow D: Delivery failure and retry
1. Outbound POST receives 503 from partner.
2. Worker schedules retry at +1m using exponential schedule.
3. Each attempt persisted in `zap_delivery_attempts`.
4. After 5 retries spanning 24 hours, payload moved to `zap_dead_letter`.
5. Dashboard increments dead-letter counter. Admin sees red banner in health dashboard.

## Flow E: Loop detection
1. Misconfigured Zap fires 80 events with identical payload in 45 seconds.
2. Bloom filter for that subscription detects 50+ duplicates.
3. Subscription auto-paused; `zapier_subscriptions.status` set to `auto_paused`.
4. Admin notified via in-app notification and email.
5. Admin opens dashboard, fixes filter, clicks "Resume". Status returns to `active`.

## Flow F: Token refresh
1. Zapier receives 401 from `POST /api/v1/zap/actions/messages/send`.
2. Zapier calls `POST /oauth/token` with the refresh token.
3. Backend issues new access token, rotates refresh token. Old refresh token row marked revoked.
4. Zapier retries the action call. Succeeds.

## Flow G: Revoke access
1. Admin opens Connected Apps, clicks Zapier row, clicks "Revoke access".
2. Confirmation modal requires typing the integration name.
3. Backend deletes `oauth_tokens` rows for this client and server. Subscriptions paused.
4. Subsequent Zapier calls receive 401.

## Flow H: Idempotency on action
1. Zapier action call has `Idempotency-Key: zap_run_88234`.
2. Backend checks `idempotency_keys` table; not found, processes request.
3. Stores result with the key.
4. If Zapier retries the same call (network blip), backend returns the cached response without re-executing.

## Flow I: Subscribe and unsubscribe
1. When user creates a Zap, Zapier calls `performSubscribe` which POSTs to `/api/v1/zap/subscribe` with `{event_type, server_id, target_url, filters}`. We return subscription id.
2. When user deletes the Zap, Zapier calls `performUnsubscribe`, we DELETE the subscription.

## Flow J: Make scenario with multiple actions
1. Make scenario: form submitted on Typeform → Flicko create thread → Flicko send message in thread.
2. Make calls `POST /api/v1/zap/actions/threads/create` with parent channel id and title. Receives thread id.
3. Make passes thread id to next module.
4. Make calls `POST /api/v1/zap/actions/messages/send` with `{channel_id: thread_id, body: ...}`. Both calls authenticated with same OAuth token.

## Cron-like delivery
For Zaps that need scheduled triggers we expose `time.tick` virtual trigger; partner schedules its own polling on their side. We do not run cron for Zapier.
