# Email Digest — Technical Requirements

## 1. Architecture Overview

```
   ┌───────────────┐ pg_cron 5min        ┌────────────────────┐
   │ Postgres      │────────────────────▶│ DigestPlannerWorker│
   │ digest_subs   │                     └─────────┬──────────┘
   └───────────────┘                                ▼
                                          ┌──────────────────┐
                                          │ ContentRanker    │
                                          │ (mentions, DMs,  │
                                          │  trending msgs)  │
                                          └─────────┬────────┘
                                                    ▼
                                          ┌──────────────────┐
                                          │ TemplateRenderer │
                                          │ (MJML -> HTML+TXT)│
                                          └─────────┬────────┘
                                                    ▼
                                          ┌──────────────────┐
                                          │ Resend client    │
                                          │ /v1/emails       │
                                          └─────────┬────────┘
                                                    ▼
                                          ┌──────────────────┐
                                          │ digest_runs      │
                                          │ delivery audit   │
                                          └──────────────────┘
```

## 2. Components

### Backend (Go)
- `services/productivity/digest/planner.go`
- `services/productivity/digest/ranker.go`
- `services/productivity/digest/template.go`
- `services/productivity/digest/sender.go`
- `services/productivity/digest/unsubscribe.go`
- `handlers/digest/preferences_handler.go`
- `handlers/digest/unsubscribe_handler.go` (token validation)
- `models/digest.go`

### Mobile (Flutter)
- `mobile/lib/features/productivity/email_digest/`
  - Preferences screen wired into Settings -> Notifications

### Infra
- DB: Postgres, migration 167
- Cron: pg_cron `digest_planner_tick` every 5 min (selects users due in next 5min window)
- Email: Resend API; backup SES adapter behind interface
- Templates: MJML -> HTML/TXT compiled at build time
- Tracking pixel: Resend's built-in

## 3. API Contracts

### REST
```
GET    /api/v1/digest/preferences              read mine
PATCH  /api/v1/digest/preferences              { cadence, day_of_week, hour, server_allowlist }
POST   /api/v1/digest/preview                  preview last computed digest
GET    /api/v1/digest/unsubscribe?token=       one-click unsub (RFC 8058 LIST-Unsubscribe)
GET    /api/v1/digest/runs                     last 30 sends (admin debug)
```

### Email
- Headers: `List-Unsubscribe: <https://flicko.io/u/<token>>, <mailto:unsub@flicko.io?subject=<token>>`
- `List-Unsubscribe-Post: List-Unsubscribe=One-Click`
- Reply-to: `noreply@flicko.io`

## 4. Permissions & Auth

- Preferences scoped to self
- Unsubscribe token signed JWT, 30-day expiry, single-use marker
- RLS owner-only

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| Plan + render p99 | <800 ms per recipient |
| Send throughput | 1000 emails/min via Resend |
| Open rate target | 35% |
| Cost | $0 within Resend free tier (3k/mo) |

## 6. Dependencies

- Existing: messages, mentions, threads, server-membership, audit-log
- External: Resend API
- Mobile: Settings page integration

## 7. Observability

- `flicko_digest_planned_total{cadence}`
- `flicko_digest_sent_total{result}`
- `flicko_digest_open_total`
- `flicko_digest_click_total`
- `flicko_digest_render_seconds` histogram

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| Resend rate limit | sends queued | adaptive throttle; SES failover |
| Empty digest (no content) | wasted email | skip and mark `skipped_empty` |
| User opted out mid-batch | wasted email | re-check opt-out at send time |
| Bounce hard | future sends fail | mark `bouncing`; pause |
| Spam complaint | trust hit | mark `complained`; pause; alert |
| PII leak | privacy issue | renderer test suite asserts no DM content the recipient isn't part of |
| Locale missing | English fallback | locale registry; fallback chain |
