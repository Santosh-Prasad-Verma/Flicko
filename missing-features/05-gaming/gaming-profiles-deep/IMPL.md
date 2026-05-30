# Gaming Profiles Deep — IMPL

## Phases
| # | Goal | Days |
|---|------|------|
| 0 | Spec | 1 |
| 1 | Migration 157 | 1 |
| 2 | Composer service | 3 |
| 3 | Public SSR renderer | 4 |
| 4 | Editor screen | 4 |
| 5 | Share card export | 2 |
| 6 | Privacy + cache invalidation | 2 |
| 7 | QA + a11y | 2 |
| 8 | Beta + GA | 3 |

## Backend
- [ ] `supabase/migrations/157_gaming_profiles.up.sql`
- [ ] `backend/internal/services/gaming/profiles/{composer,public_renderer,share_card}.go`
- [ ] `backend/internal/handlers/gaming_profile_handler.go`
- [ ] OG image generator (chrome-headless or vips text composition)
- [ ] Cache invalidation hook on PATCH

## Mobile
- [ ] `mobile/lib/features/gaming/profile/`
- [ ] `GamingTab` (within profile screen)
- [ ] `GamingProfileEditorScreen`
- [ ] `ShareCardSheet`
- [ ] L10n + golden tests

## Files
```
backend/internal/services/gaming/profiles/...        (new)
backend/internal/handlers/gaming_profile_handler.go  (new)
mobile/lib/features/gaming/profile/...               (new)
supabase/migrations/157_gaming_profiles.up.sql       (new)
```

## Test
- Composer happy + each section degraded.
- SSR HTML validates; OG tags correct.
- RLS: friends-only respected.
- Image export deterministic snapshot.

## Rollout
- Flag `feature.gaming_profile.enabled`. Default OFF.
- Beta on 5 gaming servers.

## Risks
- Public abuse / impersonation. Mitigation: report-and-rename if reserved name.
- Cache thrash on hot creators. Mitigation: SWR strategy.

## Cost
- $0. SSR runs on existing Go pod.
