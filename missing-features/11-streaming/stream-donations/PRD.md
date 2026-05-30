# PRD — Stream Donations

## 1. Problem Statement
Flicko streamers monetize via subscriptions and channel memberships, but viewers have no impulse-driven way to send tips during a live broadcast. Today, supporters who want to surprise a streamer with $5 mid-game must leave the app, wire money externally, and the streamer never sees a real-time alert. Without on-stream donation alerts, the social loop that sustains tip economies on competing platforms is broken: viewers don't see other viewers donating, donors don't get celebrated, and streamers can't shoutout supporters in the moment.

## 2. Goals
- Let viewers tip streamers in any supported currency, with attached message and TTS option.
- Process payments via Stripe with low fee overhead and PCI scope kept inside Stripe Elements.
- Surface donations as a real-time animated overlay (browser source) plus an alert in the in-app player.
- Allow streamers to define alert tiers, animations, sound, and TTS voices via `donation_alert_rules`.
- Pay out via existing Stripe Connect express accounts on the streamer's standard payout schedule.

## 3. Non-Goals
- Crypto, gift cards, and bank transfers — Stripe-supported card and wallet methods only.
- Recurring donations — covered under subscriptions.
- Charity round-ups or fundraising matches — separate Charity feature.
- Anti-fraud fingerprinting beyond Stripe Radar — handled by platform-wide trust system.

## 4. User Stories
- As a viewer, I tap "Tip" in the player, choose $5, type "Great clutch!", and confirm with Apple Pay.
- As a streamer, I see the alert pop up on stream within 5 seconds with my custom sound and animation.
- As a streamer, I configure that donations under $5 use a basic alert and donations over $50 trigger the "legendary" alert with a longer animation.
- As a viewer, I toggle TTS so my message is read aloud on the stream.
- As a streamer, I block specific words and they get filtered from messages and TTS.
- As a streamer, I refund a problematic donation with two clicks and the alert is removed from the timeline.

## 5. Success Metrics
- Donation conversion: 2.5% of unique stream viewers donate at least once per stream they watch.
- p95 alert latency under 5 seconds from Stripe webhook to overlay render.
- Less than 0.1% donation processing errors after retries.
- Streamer alert customization adoption: 60% of donating channels customize at least one rule.
- Refund rate kept under 0.5%.

## 6. Functional Requirements
- F1: Tip composer with preset amounts ($1, $5, $10, $25, $50, $100) and custom amount entry.
- F2: Multi-currency: USD, EUR, GBP, INR, JPY, AUD, CAD with on-fly conversion display.
- F3: Stripe PaymentIntent creation server-side, confirmation client-side via Stripe Elements / Apple Pay / Google Pay.
- F4: Webhook listener for `payment_intent.succeeded` triggers donation finalization and Centrifugo alert publish.
- F5: Alert overlay subscribed to Centrifugo channel `stream-alerts:<stream_id>`.
- F6: Per-channel rule engine (`donation_alert_rules`) selecting animation, sound, TTS voice, and minimum amount.
- F7: TTS pipeline routes message to Polly/ElevenLabs (configurable) with profanity filter.
- F8: Donor display name, avatar, and amount in the alert; anonymous mode hides name.
- F9: Streamer dashboard shows donation history with filters and export to CSV.
- F10: Refund flow that updates `stream_donations.status` to `refunded` and emits a control frame to remove the alert from history overlay.

## 7. Non-Functional Requirements
- PCI scope: Stripe Elements, no card data ever touches Flicko servers.
- All webhooks signature-verified using Stripe's signing secret.
- Idempotency keys on PaymentIntent creation to handle retries.
- TTS budget cap per channel per day to prevent abuse, default $10 of TTS spend.
- Overlay alert renders inside 1 RAF frame (<16ms) to keep OBS smooth even on weak hardware.

## 8. Risks & Mitigations
- Risk: Webhook delivery delay > 30s. Mitigation: poll PaymentIntent status as fallback after 10s of waiting on the client side.
- Risk: Toxic donation messages disrupt stream. Mitigation: profanity filter, channel blocklist, mod approval queue for messages > 200 chars.
- Risk: Stripe disputes. Mitigation: clear receipt with "Tip to <streamer>" descriptor, recoverable via channel support flow.
- Risk: TTS abuse with extremely long messages. Mitigation: 200 char max, max 30s audio per alert.
- Risk: Currency conversion drift. Mitigation: lock exchange rate at PaymentIntent creation, persist `amount_usd` for analytics.

## 9. Out-of-Scope (v1)
- Donation goals and progress bars on overlay.
- Top-donor leaderboards on overlay (deferred to v1.1).
- Donation matching / sponsor multiplier.

## 10. Release Plan
- Internal alpha with 10 partner streamers using Stripe test mode.
- Closed beta with feature flag `donations_v1` and live mode for 50 partners.
- Public beta after 30 days, monitoring fraud metrics.
- GA when refund/dispute rate stabilizes below 0.5%.

## 11. Open Questions
- Which TTS provider becomes the default — Polly is cheaper, ElevenLabs sounds better.
- Should donation messages be subject to chat ban list automatically? Lean yes, but separate moderator review flag.
- Currency rounding for low-denomination currencies (JPY, KRW) — confirm with Finance.
