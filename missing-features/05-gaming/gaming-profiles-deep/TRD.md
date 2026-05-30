# Gaming Profiles Deep — TRD

## Architecture
```
profile request → composer → reads from
  ├ linked_game_accounts (game-stats)
  ├ user_achievements (achievement-system)
  ├ clips (game-clip-sharing)
  ├ recent_games (cached)
  └ friend_codes (manual)
→ rendered tab; public URL via SSR Go html/template
```

## Components
- Backend: `backend/internal/services/gaming/profiles/{composer,public_renderer}.go`
- Handler: `gaming_profile_handler.go` — GET /users/:id/gaming, GET /public/@:slug/gaming.
- Public renderer = separate small Go web server `backend/cmd/public_profiles/` (or path on main app).
- Mobile: `mobile/lib/features/gaming/profile/`
- Reuses existing services from gaming-stats, achievement-system, clips.

## API
```
GET /users/:id/gaming
GET /public/@:slug/gaming     (HTML, OG tags, SSR)
PATCH /me/gaming-profile {sections, friend_codes, privacy}
POST /me/gaming-profile/export.png
```

## NFRs
| NFR | Target |
|-----|--------|
| Composer p99 | <200ms |
| Public page TTFB | <300ms |
| Image export | <2s |

## Observability
- `flicko_gprofile_views_total{public,private}`
- `flicko_gprofile_section_renders_total{section}`

## Failure
- Each section degrades independently (skeleton if data unavailable).
