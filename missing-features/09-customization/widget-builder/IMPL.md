# Widget Builder — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze + design review | 3d | PM/Design |
| 1 | DB migration 209 | 1d | Backend |
| 2 | CRUD service + handlers | 4d | Backend |
| 3 | Render endpoint (HTML) + CSP | 3d | Backend |
| 4 | Web builder scaffold (Vite/React) | 3d | Web |
| 5 | Drag-drop canvas + 8 blocks | 8d | Web |
| 6 | Properties panel + theme | 3d | Web |
| 7 | Snippet generator | 2d | Web |
| 8 | Cloudflare Worker edge renderer | 3d | Infra |
| 9 | Auth handoff (server-only access) | 2d | Backend/Web |
| 10 | QA + a11y audit | 3d | QA |
| 11 | Beta with 20 servers | 5d | All |
| 12 | GA | 1d | All |

Total: ~41d.

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/209_widget_builder.up.sql`.
- [ ] Down migration.
- [ ] Model `backend/internal/models/embed_widget.go`.
- [ ] Service `backend/internal/services/widgets/service.go` (CRUD, slug gen).
- [ ] Renderer `backend/internal/services/widgets/renderer.go` (HTML output).
- [ ] Block resolvers (one per type) `backend/internal/services/widgets/blocks/*.go`.
- [ ] Handlers `backend/internal/handlers/widgets_handler.go`.
- [ ] Service tests.
- [ ] Wire routes.
- [ ] Audit log entries.
- [ ] Metrics counters.
- [ ] OpenAPI doc update.

## 3. Web Tasks (`widget-builder/`)

- [ ] Scaffold with Vite + React + Tailwind.
- [ ] Auth handoff via short-lived JWT in URL hash (consumed and dropped).
- [ ] Canvas using `@dnd-kit/core`.
- [ ] Block components:
  - `BlockMemberCount.tsx`
  - `BlockOnlineRoster.tsx`
  - `BlockRecentPosts.tsx`
  - `BlockEventList.tsx`
  - `BlockLeaderboard.tsx`
  - `BlockChannelHighlight.tsx`
  - `BlockJoinCta.tsx`
  - `BlockBanner.tsx`
- [ ] Right panel `PropertiesPanel.tsx` reading per-block schema.
- [ ] Snippet sheet `SnippetGenerator.tsx`.
- [ ] State store `useBuilderStore.ts` (zustand).
- [ ] Save with debounce 800ms.

## 4. Mobile Tasks

- [ ] Settings entry point `mobile/lib/features/server_settings/presentation/screens/embed_widgets_screen.dart`:
  - Lists existing widgets.
  - Tapping "Open builder" opens external browser with one-time token.
- [ ] Tests: list view + open-external-link helper.

## 5. Infra Tasks

- [ ] Cloudflare Worker at `embed.flicko.app`.
- [ ] KV namespace.
- [ ] Origin allowlist for fetch.
- [ ] CSP set in `wrangler.toml`.

## 6. Files Touched (predicted)

```
backend/
  internal/services/widgets/service.go             (new)
  internal/services/widgets/renderer.go            (new)
  internal/services/widgets/blocks/*.go            (new, 8 files)
  internal/handlers/widgets_handler.go             (new)
  internal/models/embed_widget.go                  (new)
  cmd/server/main.go                               (edit)
widget-builder/
  src/...                                          (new tree)
  package.json, vite.config.ts                     (new)
mobile/
  lib/features/server_settings/presentation/screens/embed_widgets_screen.dart (new)
infra/
  cloudflare/wrangler.toml                         (new)
  cloudflare/worker.ts                             (new)
supabase/
  migrations/209_widget_builder.up.sql             (new)
  migrations/209_widget_builder.down.sql           (new)
```

## 7. Test Plan

- Unit: each block resolver, slug gen collision retry, layout validator.
- Integration: render end-to-end with 4 blocks.
- E2E (Playwright): builder login → drag → save → preview.
- Load: k6 — 5k RPS through edge, p95 <300ms.
- Security: CSP applied, frame-ancestors enforced; cross-site embed blocked.
- Accessibility: keyboard drag-drop, screen reader on builder.

## 8. Rollout & Feature Flags

- Flag: `feature.widget_builder.enabled`.
- Default OFF in prod.
- Beta: 20 servers; cap 1 widget each.
- Canary 10% → 100% over 7d.

## 9. Rollback Plan

1. Disable flag.
2. Edge worker returns "feature disabled" page.
3. Builder route 503.
4. Leave data; reactivate when fixed.

## 10. Dependencies / Blockers

- Depends on: `gaming-ui` web infra (CI patterns).
- Depends on: Cloudflare account + KV provisioned.
- Blocks: nothing.

## 11. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| CSP misconfig blocks legit embeds | M | M | dry-run preview |
| Edge cache stampede | L | H | KV stale-while-revalidate |
| Builder UX too complex | M | M | usability testing in beta |
| Cross-site iframe abuse | M | M | strict frame-ancestors + rate limit |

## 12. Cost Model

| Component | Free tier? | Estimated $ at 100k DAU |
|-----------|-----------|--------------------------|
| Cloudflare Workers | 100k req/day free | ~$5/mo for 5M req |
| KV | 100k ops free | ~$0.50/mo |
| Origin | Railway free | $0 |
| DB | Supabase free | $0 |
| **Total** | | **~$5.5/mo at scale** |

Acceptable as widgets are owner-driven and modest in volume.

## 13. Done Definition

- [ ] All tasks above checked
- [ ] 8 blocks live and themed
- [ ] Edge p95 <300ms
- [ ] CSP violations dashboard live
- [ ] Beta feedback ≥4.0/5
- [ ] Zero P0/P1 bugs in 7-day window
