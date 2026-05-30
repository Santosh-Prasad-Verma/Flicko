# TRD — Stream Donations

## 1. Architecture Overview

```
[Mobile/Web Client]
   |  POST /v1/donations/intent
   v
[donation-api (Go)] ----create PI----> [Stripe]
   |                                       |
   |                                       v
   |                              [Stripe Webhook] --signed POST--> [donation-webhook]
   |                                                                       |
   |<------ optional polling fallback ------                               |
                                                                            v
                                                   [donations table] [Centrifugo: stream-alerts:<id>]
                                                                            |
                                                                            v
                                                                    [Alert Overlay (browser source)]
                                                                            +
                                                                    [TTS worker (NATS subj donation.tts)]
```

## 2. Components
- `donation-api`: Go HTTP service that creates PaymentIntents, validates streams, stores pending donations, fetches alert history.
- `donation-webhook`: Go service receiving Stripe webhooks, finalizes donation rows, emits Centrifugo alert and TTS NATS message.
- `tts-worker`: Go worker subscribed to NATS `donation.tts.*` subject, calls TTS provider, uploads MP3 to `donation-tts` bucket, publishes audio URL back to overlay via control frame.
- `alert-overlay`: SPA bundle similar to chat overlay, rendering animated alerts and playing audio.
- `donation-admin`: dashboard UI for rules, history, refunds.
- `centrifugo` and `nats` shared with the rest of platform.

## 3. Stripe Integration
- Each streamer onboards via Stripe Connect Express; account ID stored in `channels.stripe_account_id`.
- Donations created with `application_fee_amount` (Flicko platform fee, default 5%) and `transfer_data.destination = stripe_account_id`.
- Mode: live with idempotency keys `donation:{donation_id}:create`.
- Currency: viewer's selected currency, settled to streamer in their account currency by Stripe.
- Webhook endpoints registered for: `payment_intent.succeeded`, `payment_intent.payment_failed`, `charge.refunded`, `charge.dispute.created`, `charge.dispute.closed`.

## 4. API Surface
- `POST /v1/streams/{id}/donations/intent` body `{amount_minor, currency, message, tts, anonymous, alert_rule_id?}` returns `{donation_id, client_secret}`.
- `POST /v1/streams/{id}/donations/confirm` (fallback poll) returns donation status.
- `GET /v1/streams/{id}/donations` paginated, viewer sees own donations, streamer sees all.
- `GET /v1/channels/{id}/donations/rules`, `POST`, `PUT`, `DELETE` rule CRUD.
- `POST /v1/donations/{id}/refund` initiates Stripe refund; mod-only.
- `POST /v1/donations/{id}/replay` re-emits the alert (for debugging).
- `GET /v1/streams/{id}/alerts/overlay-token` returns signed JWT for overlay.

## 5. Webhook Verification
- Use `stripe.Webhook.ConstructEvent` with `STRIPE_WEBHOOK_SECRET` and `Stripe-Signature` header.
- Reject events older than 5 minutes (default tolerance).
- Idempotent processing: dedupe via `webhook_events(stripe_event_id PRIMARY KEY)`.

## 6. Alert Pipeline
- On `payment_intent.succeeded`, donation row updated to `status = succeeded`.
- Rule engine selects matching `donation_alert_rules` row by amount band and channel.
- Alert payload built: `{donation_id, donor_name, amount_minor, currency, message, animation, sound_url, tts_url?, duration_ms}`.
- Publishes to `stream-alerts:<stream_id>`. Overlay receives within < 1 second.
- TTS is asynchronous; overlay holds the alert until TTS audio URL arrives via `stream-alerts-ctrl:<id>` `op:tts-ready` frame.

## 7. TTS Pipeline
- NATS subject `donation.tts.queue` consumed by `tts-worker`.
- Worker validates message length (≤ 200 chars), runs profanity filter, builds SSML.
- Calls Polly default; ElevenLabs if channel rule overrides voice.
- Stores MP3 in `donation-tts` Supabase bucket, public URL returned.
- Publishes `tts-ready` control frame.
- Channels exceeding daily TTS budget get suppressed and a notification sent to streamer.

## 8. Refunds
- Refund triggers `POST /v1/refunds` to Stripe with `reason`, optional partial amount.
- On `charge.refunded` webhook, donation moves to `refunded`. Control frame emitted to remove from overlay history view.
- If refund happens within 30s of donation, alert is suppressed at overlay if not yet rendered (race-safe via state check).

## 9. Currency Handling
- Amount stored in minor units (cents, paise, yen). `amount_minor BIGINT`.
- Display layer converts minor → major using ISO 4217 minor unit table.
- `amount_usd_minor` populated at confirm time using cached FX rates from `fx_rates` table refreshed hourly.

## 10. Failure Modes
- Stripe webhook outage: poll endpoint reconciles within 10 minutes via job `donation_reconciler` scanning pending intents older than 60s.
- Centrifugo down: alert queued in `donation_alert_queue` table for up to 30 minutes; overlay reconnect picks up via history.
- TTS provider down: alert plays sound + visual without TTS, no failure surfaced to viewer.
- Refund failure: surfaces to streamer with retry; donation stays `succeeded` until Stripe acknowledges.

## 11. Scaling
- Webhook handler horizontally scaled, target 100 events/sec sustained, 1k peak.
- Donation create endpoint targeted 50 RPS sustained, 500 RPS peak (raid scenarios).
- Centrifugo channel `stream-alerts:<id>` shares cluster with chat; alert volume is 1-2 orders smaller than chat.
- TTS worker autoscales based on NATS lag.

## 12. Observability
- Metrics: `donation_intent_created_total`, `donation_succeeded_total`, `donation_alert_latency_ms`, `donation_refund_total`, `tts_budget_exhausted_total`.
- Tracing: Stripe API calls captured as outbound spans.
- Alarms: alert latency p95 > 5s, webhook signature failures > 1%, refund rate > 1% over 1h.

## 13. Security
- Webhook secret rotated every 90 days.
- Stripe keys stored in Vault, accessed only by `donation-api` and `donation-webhook` service identities.
- Donation messages sanitized for HTML and capped at 200 chars before render.
- Anonymous mode strips donor identity from overlay payload (still stored server-side for support).
- Tax: 1099/T5 issuance handled by Stripe Connect; Flicko surfaces totals via `donation_payout_summary` view.

## 14. Compliance
- GDPR: donor PII deletable on request — donations preserved for 7 years (financial record), but display name and message scrubbed.
- PCI DSS SAQ-A scope retained by using only Stripe-hosted payment elements.
- AML: large donations (>$1000 USD equivalent) flagged for review.
