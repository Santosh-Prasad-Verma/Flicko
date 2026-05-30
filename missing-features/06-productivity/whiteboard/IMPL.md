# Whiteboard — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze | 2d | PM |
| 1 | Migration 168 + models | 1d | Backend |
| 2 | Service + handshake + ACL | 3d | Backend |
| 3 | Hocuspocus wb namespace + persistence | 3d | Backend/Infra |
| 4 | Tldraw bundle (CDN) + Yjs adapter | 4d | Frontend |
| 5 | Mobile WebView shell + native dock | 4d | Mobile |
| 6 | PNG export worker (Playwright) | 3d | Backend/Infra |
| 7 | Snapshot worker + retention | 2d | Backend |
| 8 | Voice-channel embed | 2d | Mobile |
| 9 | QA, a11y, perf | 3d | QA |
| 10 | Beta -> GA | 28d | All |

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/168_whiteboard.up.sql`
- [ ] Down migration
- [ ] Models `internal/models/whiteboard.go`
- [ ] Service + ACL + handshake JWT
- [ ] Snapshot worker (shared infra with docs)
- [ ] PNG export endpoint -> dispatch to Playwright sidecar
- [ ] Hocuspocus persistence webhook for `wb:` namespace
- [ ] Handlers
- [ ] Wire routes
- [ ] Audit log
- [ ] Prometheus counters
- [ ] OpenAPI doc update
- [ ] Tests: ACL matrix, handshake replay, export size cap

## 3. Mobile Tasks

- [ ] Folder `mobile/lib/features/productivity/whiteboard/`
- [ ] WebView shell with theme bridge
- [ ] Native bottom dock mirroring tldraw tools
- [ ] List + canvas screens; voice channel side drawer
- [ ] Export sheet
- [ ] Deep link `flicko://wb/<id>`
- [ ] L10n
- [ ] Tests (golden empty list)

## 4. AI / Infra Tasks

- [ ] Tldraw bundle build pipeline + CDN deploy
- [ ] Playwright Chromium worker (`tools/wb-render/`) container
- [ ] Hocuspocus deploy already done in docs; add `wb:` route
- [ ] Appwrite bucket + permissions

## 5. Files Touched

```
backend/
  internal/services/productivity/whiteboard/
    service.go
    handshake.go
    snapshot_worker.go
    png_export.go
  internal/handlers/whiteboard/{handler,acl_handler,export_handler}.go
  internal/models/whiteboard.go
  internal/repo/whiteboard_repo.go
  cmd/server/main.go                       (edit)
  api/openapi.yaml                         (edit)
docker-compose.yml                         (edit: wb-render)
tools/wb-render/                           (new)
tools/tldraw-bundle/                       (new)
mobile/lib/features/productivity/whiteboard/...
mobile/lib/core/router/app_router.dart    (edit)
mobile/lib/l10n/app_en.arb                (edit)
supabase/migrations/168_whiteboard.up.sql
supabase/migrations/168_whiteboard.down.sql
```

## 6. Test Plan

- Unit: ACL matrix; handshake JWT
- Integration: connect -> draw -> persist -> reconnect (testcontainers + Hocuspocus)
- E2E: 2-device side-by-side draw; PNG export round-trip
- Load: 25 concurrent editors x 50 boards; p99 propagation < 300ms
- Perf: WebView mount < 2s on mid-tier Android
- A11y: TalkBack and VoiceOver in WebView
- Security: handshake replay; tampered token

## 7. Rollout & Feature Flags

- Flag `feature.whiteboard.enabled`
- 1% -> 10% -> 50% -> 100% over 28d
- Kill switch: flag flip + Hocuspocus `wb:` namespace read-only

## 8. Rollback Plan

1. Flag flip
2. Read-only mode
3. Stop snapshot + export workers
4. Tables stay

## 9. Dependencies / Blockers

- Depends on: collaborative-docs Hocuspocus infra (shared)
- External: tldraw OSS license confirm (MIT)

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Tldraw bundle size on mobile | M | M | lazy load + prewarm |
| WebView a11y gaps | M | M | native dock mirror |
| State blob bloat | M | M | cap 5 MB; nudge to snapshot |

## 11. Cost Model

| Component | Free tier | $ at 100k DAU |
|-----------|-----------|----------------|
| Hocuspocus | shared | $0 incremental |
| Render sidecar | self-host | $5/mo |
| Storage PNG | Appwrite | $0 |
| **Total** | | **~$5/mo** |

## 12. Done Definition

- [ ] All tasks checked
- [ ] 25 concurrent editors verified
- [ ] PNG export reliable
- [ ] Beta NPS >= 25
- [ ] Zero P0/P1 in 7d
