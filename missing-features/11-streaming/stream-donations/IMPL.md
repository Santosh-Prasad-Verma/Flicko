# Stream Donations — Implementation

## Phases
| # | Goal | Days |
|---|------|------|
| 0 | Spec + Stripe Connect onboarding flow | 2 |
| 1 | Migration 233 | 1 |
| 2 | Stripe webhook handler + ledger | 4 |
| 3 | Donation widget + overlay | 4 |
| 4 | Alert customization screen | 2 |
| 5 | Streamer dashboard (recent + total) | 2 |
| 6 | Payout cron + reconciliation | 3 |
| 7 | QA + fraud + chargeback flow | 3 |
| 8 | Beta + GA | 3 |

## Backend
- [ ] `supabase/migrations/233_stream_donations.up.sql`
- [ ] `backend/internal/services/streaming/donations/service.go`
- [ ] `backend/internal/services/streaming/donations/stripe_webhook.go`
- [ ] `backend/internal/services/streaming/donations/payout_worker.go` (weekly pg_cron)
- [ ] `backend/internal/handlers/donation_handler.go` (POST /streams/:id/donate, GET /streams/:id/donations, PATCH /me/alert-rules)
- [ ] Centrifugo broadcast on success
- [ ] Audit + fraud signals (velocity, refund rate)
- [ ] Metrics

## Mobile
- [ ] `mobile/lib/features/streaming/donations/`
- [ ] DonateSheet (amount + message + voice picker)
- [ ] AlertOverlay (overlay component for stream view)
- [ ] AlertRulesScreen (streamer)
- [ ] DonationsHistoryScreen
- [ ] Stripe SDK integration

## Web Overlay
- `widget-embed/donation-alerts/index.html` for OBS-friendly browser source. Connects to Centrifugo and renders alerts.

## Files
```
backend/internal/services/streaming/donations/...      (new)
backend/internal/handlers/donation_handler.go          (new)
mobile/lib/features/streaming/donations/...            (new)
widget-embed/donation-alerts/...                       (new)
supabase/migrations/233_stream_donations.up.sql        (new)
```

## Test
- E2E with Stripe test mode: success/decline/refund/dispute.
- Concurrency: 100 donations to same stream within 1 min.
- Idempotency: duplicate webhook delivery.

## Rollout
- Flag `feature.donations.enabled`. KYC required first.
- Beta with 20 verified streamers.

## Risks
| Risk | Mitigation |
|------|------------|
| Chargeback fraud | hold first $100 for 7 days |
| TTS abuse | profanity filter on message + length cap |
| Webhook race | ledger uses idempotent INSERTs with stripe event id |

## Cost
- Stripe fees passed through. Flicko's 5% covers infra. Worker on existing Go pod.
