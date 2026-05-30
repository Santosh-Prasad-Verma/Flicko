# APPFLOW — Stream Donations

## 1. Viewer Sends a Tip
1. Viewer taps the coin icon in the player.
2. Tip composer opens; viewer picks $25 USD, types "Loved that play", toggles TTS on.
3. Client posts `POST /v1/streams/{stream_id}/donations/intent` with the form payload plus an idempotency key (ULID generated on open).
4. `donation-api` validates that the channel has Stripe Connect enabled, donations toggled on, and amount within min/max bounds.
5. Server inserts a row in `stream_donations` with `status = 'pending'`, then calls Stripe `PaymentIntents.create` with `transfer_data.destination = channels.stripe_account_id` and `application_fee_amount = floor(amount * 0.05)`.
6. Server returns `{donation_id, client_secret}`.
7. Client confirms via Stripe.js (`stripe.confirmCardPayment(client_secret)` or wallet variant).
8. On Stripe success callback, client shows confetti modal and closes composer. Webhook will finalize the row.

## 2. Webhook Finalizes the Donation
1. Stripe POSTs `payment_intent.succeeded` to `https://webhooks.flicko.app/stripe/donations`.
2. `donation-webhook` verifies signature, dedupes via `webhook_events.stripe_event_id`.
3. Updates `stream_donations` row: `status = 'succeeded'`, `paid_at`, `stripe_charge_id`, `amount_usd_minor`, `fee_minor`.
4. Looks up matching `donation_alert_rule` by `(channel_id, amount_usd_minor)` band; falls back to default rule.
5. Builds alert payload, calls Centrifugo `publish` for channel `stream-alerts:<stream_id>`.
6. If TTS requested, publishes NATS message to `donation.tts.queue` with `{donation_id, message, voice}`.
7. Emits dashboard notification via `notifications` system.

## 3. Overlay Renders the Alert
1. Overlay browser source connects to Centrifugo with overlay JWT.
2. Receives publication `{donation_id, donor_name, amount_minor, currency, message, animation, sound_url, duration_ms}`.
3. Pushes alert into queue. If queue not currently rendering, starts the render pipeline:
   - Fade-in animation (700 ms based on tier).
   - Plays sound at start.
   - Holds for `duration_ms`.
   - Fades out (400 ms).
4. If alert is TTS-enabled, overlay waits up to 3 seconds for `op:'tts-ready'` control frame; if it arrives, audio is queued to play after sound effect; if not, alert proceeds without TTS.
5. After completion, the next queued alert starts.

## 4. TTS Worker Runs in Background
1. `tts-worker` consumes NATS subject `donation.tts.queue`.
2. Validates message length and runs profanity filter using channel rules.
3. Calls Polly `SynthesizeSpeech` (or ElevenLabs API) with selected voice.
4. Uploads MP3 to `donation-tts/<donation_id>.mp3`.
5. Publishes control frame `{op:'tts-ready', donation_id, audio_url}` to `stream-alerts-ctrl:<stream_id>`.
6. Updates `stream_donations.tts_audio_url`.

## 5. Streamer Configures Alert Rules
1. Streamer opens Channel Settings → Donations → Alerts.
2. Clicks "Add rule".
3. Enters min/max amount band, picks animation template, uploads optional video, picks sound and voice.
4. Submits — `POST /v1/channels/{id}/donations/rules` writes to `donation_alert_rules`.
5. Preview pane fires a synthetic alert via `POST /v1/channels/{id}/donations/rules/{rule_id}/test`.
6. Rule applies to subsequent live donations immediately (no stream restart needed).

## 6. Refund Flow
1. Streamer opens donation history, clicks Refund on a row.
2. Confirms in modal; client posts `POST /v1/donations/{id}/refund`.
3. Server calls Stripe `Refunds.create` and updates row to `status = 'refund_pending'`.
4. Stripe webhook `charge.refunded` arrives.
5. Server updates row to `status = 'refunded'`, emits control frame `{op:'remove-from-history', donation_id}`.
6. Donor receives email "Your tip was refunded" with reason if provided.

## 7. Race: Quick Refund Before Render
1. Donation succeeds at t=0; alert is queued at t=1s, 4 alerts ahead in queue.
2. Streamer hits refund at t=2s; `op:'remove-from-history'` arrives at overlay before alert plays.
3. Overlay checks queue, removes the matching donation_id, alert never renders. Notification banner on dashboard: "Refund prevented alert from playing".

## 8. Anonymous Donation
1. Viewer toggles "Hide my name".
2. Server stores donation row as normal but flags `anonymous = true`.
3. Centrifugo payload uses `donor_name = 'Anonymous'`, `donor_avatar_url = null`.
4. Streamer dashboard still shows real donor for support purposes; anonymous label shown next to row.

## 9. Banned Word in Message
1. Viewer message contains "<banned>".
2. `donation-webhook` runs profanity filter on message before publishing alert.
3. If found, message redacted with "Tip from <donor>" and `message_filtered = true` recorded.
4. TTS skipped automatically.
5. Streamer can review and unfilter if it was a false positive.

## 10. Reconnect After Crash
1. OBS browser source crashes mid-stream.
2. Streamer reloads source.
3. Overlay reconnects with JWT, subscribes with `recover: true`.
4. Centrifugo replays last 50 alerts from history buffer.
5. Overlay marks replayed alerts with `replay = true` and skips animation; only logs them to history HUD if streamer enabled it.

## 11. Webhook Outage Reconciliation
1. Stripe webhook delivery delayed 5 minutes.
2. Reconciliation job runs every minute, fetches PaymentIntents in `pending` for > 60s.
3. For any with `succeeded` Stripe status, processes them as if webhook arrived, including alert publish.
4. Marks donation `reconciled_via_poll = true` for audit.

## 12. Streamer Disables Tips Mid-stream
1. Streamer toggles donations off.
2. Composer in player switches to "Tipping is paused for this stream".
3. In-flight PaymentIntents continue to resolution; new intents rejected with 423.
4. Alerts for already-paid intents continue to render so donors get their celebration.
