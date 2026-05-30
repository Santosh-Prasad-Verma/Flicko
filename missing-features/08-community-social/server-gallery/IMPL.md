# Server Gallery — Implementation

## Phases
| # | Goal | Days |
|---|------|------|
| 0 | Spec | 1 |
| 1 | Migration 199 | 1 |
| 2 | Aggregator worker | 3 |
| 3 | Backend handler + filters | 2 |
| 4 | Mobile gallery screen | 4 |
| 5 | Search + filters + lightbox | 2 |
| 6 | QA + perms audit | 2 |
| 7 | Beta + GA | 3 |

## Backend
- [ ] `supabase/migrations/199_server_gallery.up.sql`
- [ ] `backend/internal/services/social/gallery/service.go`
- [ ] `backend/internal/services/social/gallery/aggregator.go` (NATS sub on `flicko.message.attachment_uploaded`)
- [ ] `backend/internal/handlers/gallery_handler.go` (GET /servers/:id/gallery, filters: kind, channel, author, date-range)
- [ ] Respects channel read perms via RLS
- [ ] Metrics: `flicko_gallery_items_total`

## Mobile
- [ ] `mobile/lib/features/social/server_gallery/`
- [ ] Screens: `GalleryGridScreen`, `LightboxScreen`
- [ ] Lazy-load with `infinite_scroll_pagination` package
- [ ] Filter bar
- [ ] Swipe-down-to-dismiss lightbox

## Files
```
backend/internal/services/social/gallery/...      (new)
backend/internal/handlers/gallery_handler.go      (new)
mobile/lib/features/social/server_gallery/...     (new)
supabase/migrations/199_server_gallery.up.sql     (new)
```

## Test
- Permission test: ensure user without channel read can't see attachments from that channel.
- Load: server with 1M attachments — paginated cursor test.

## Rollout
- Flag `feature.server_gallery.enabled`. Default ON in private beta servers.

## Risks
| Risk | Mitigation |
|------|------------|
| Media leak via unscoped query | RLS test suite |
| Server with 10M attachments slow | lazy hydrated views, deny full-list endpoint |

## Cost
- $0 — read-only materialized view on existing attachments table.
