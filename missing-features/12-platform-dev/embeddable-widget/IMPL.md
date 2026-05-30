# Embeddable Widget — Implementation

## Phases
| # | Goal | Days |
|---|------|------|
| 0 | Spec + threat model | 2 |
| 1 | Migration 245 (embed_keys, embed_origins) | 1 |
| 2 | Backend handler + key issuance | 2 |
| 3 | `chat.flicko.app/embed` static SPA (Vue or vanilla) | 5 |
| 4 | Loader script `widget-embed/v1.js` | 2 |
| 5 | Origin allowlist + signed JWT | 2 |
| 6 | Embed configurator screen for owners | 2 |
| 7 | QA: XSS, click-jack, perf | 3 |
| 8 | Beta + GA | 2 |

## Backend
- [ ] `supabase/migrations/245_embed_widgets.up.sql`
- [ ] `backend/internal/services/platform/embed/service.go`
- [ ] `backend/internal/handlers/embed_handler.go` (POST /embed/keys, GET /embed/keys, PATCH /embed/keys/:id)
- [ ] JWT signing for guest sessions (read-only, 24h)
- [ ] CSP headers on embed origin
- [ ] CORS limited to allowlist
- [ ] Metrics: `flicko_embed_loads_total`, `flicko_embed_origin_block_total`

## Frontend
- `widget-embed/v1.js`: tiny vanilla JS (~6KB gz) — injects iframe with signed token; postMessage bridge for events.
- `widget-embed/embed-spa/`: Vite SPA — read-only chat view + post-as-guest flow.
- Uses Flicko's design tokens but no full theme engine.

## Owner UI
- `mobile/lib/features/platform/embed/embed_keys_screen.dart` (also web): create key, set origin, copy snippet.

## Files
```
backend/internal/services/platform/embed/...                 (new)
backend/internal/handlers/embed_handler.go                   (new)
widget-embed/v1.js                                           (new)
widget-embed/embed-spa/                                      (new)
mobile/lib/features/platform/embed/...                       (new)
supabase/migrations/245_embed_widgets.up.sql                 (new)
```

## Test Plan
- XSS attempts in guest message.
- Click-jack via X-Frame-Options + frame-ancestors CSP.
- Origin allowlist enforcement (reject mismatched referer).
- Bundle size budget: loader ≤6KB gz; SPA ≤120KB gz.
- Lighthouse perf score ≥90 on embed.

## Rollout
- Flag `feature.embed_widget.enabled`. Default ON for verified servers.

## Risks
| Risk | Mitigation |
|------|------------|
| Spam from guest origins | per-IP rate limit + captcha challenge |
| Stolen embed key | rotate via owner UI; revoke on misuse |
| Bot abuse posting via embed | requires captcha + content scan |
| Server load from widely-deployed widgets | CDN cache; per-server hard cap on embed loads/min |

## Cost
- Loader served from Cloudflare CDN (free).
- SPA hosted on Cloudflare Pages (free).
- No new backend infra. $0.
