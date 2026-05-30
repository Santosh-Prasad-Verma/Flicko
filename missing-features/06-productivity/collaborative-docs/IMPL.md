# Collaborative Docs — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze + design | 3d | PM/Design |
| 1 | Migration 162 + models | 2d | Backend |
| 2 | DocService + ACL + handshake JWT | 3d | Backend |
| 3 | Hocuspocus container + auth/persist hooks | 4d | Backend/Infra |
| 4 | Tiptap CDN bundle (build, host) | 3d | Frontend/Web |
| 5 | Mobile WebView shell + presence + native actions | 5d | Mobile |
| 6 | Comments + version history | 3d | Both |
| 7 | Snapshot worker + markdown export sidecar | 3d | Backend |
| 8 | QA, a11y, load | 4d | QA |
| 9 | Beta -> GA | 28d | All |

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/162_collaborative_docs.up.sql`
- [ ] Down migration
- [ ] `internal/models/doc.go` (Doc, Revision, ACL, Comment, HandshakeToken)
- [ ] `services/productivity/docs/service.go`
- [ ] `services/productivity/docs/acl.go`
- [ ] `services/productivity/docs/snapshot_worker.go`
- [ ] `services/productivity/docs/handshake.go` (JWT signer + revoke)
- [ ] Hocuspocus persistence webhook `POST /internal/docs/:id/persisted`
- [ ] Hocuspocus auth webhook `POST /internal/docs/:id/authz`
- [ ] Markdown export sidecar (Node) on `:9090/render`
- [ ] Handlers: doc, comment, acl, snapshot
- [ ] Wire routes in `cmd/server/main.go`
- [ ] Centrifugo channel `docs:server:<sid>`
- [ ] Audit log entries
- [ ] Prometheus counters
- [ ] OpenAPI doc update
- [ ] Tests: ACL matrix, snapshot triggers, JWT validation, persistence webhook

## 3. Mobile Tasks

- [ ] Folder `mobile/lib/features/productivity/collab_docs/`
- [ ] DTOs match API exactly
- [ ] `WebView` shell with JS bridge: theme, auth, native actions (image picker, share, mention picker)
- [ ] Editor bundle URL config; integrity checked via SRI
- [ ] Riverpod providers: doc list, doc state (connection), comments
- [ ] Screens: doc list, editor host, version history, ACL sheet, comments drawer
- [ ] Native bottom-sheet handlers for "Comment", "Mention", "Insert image"
- [ ] Routing additions
- [ ] Deep link `flicko://doc/<id>`
- [ ] L10n keys
- [ ] Tests: provider tests on connection state; widget golden on empty list

## 4. AI / Infra Tasks

- [ ] Hocuspocus container in `docker-compose.yml`
- [ ] Sticky-session config for nginx/load balancer
- [ ] Markdown export sidecar (`tools/doc-render/`) Node + Tiptap server
- [ ] CDN bundle build pipeline
- [ ] Health checks, restart policy

## 5. Files Touched

```
backend/
  internal/services/productivity/docs/
    service.go
    acl.go
    handshake.go
    snapshot_worker.go
  internal/handlers/docs/
    doc_handler.go
    comment_handler.go
    acl_handler.go
    snapshot_handler.go
    persistence_webhook.go
  internal/models/doc.go
  internal/repo/doc_repo.go
  cmd/server/main.go                        (edit)
  api/openapi.yaml                          (edit)
docker-compose.yml                          (edit: add hocuspocus, doc-render)
tools/doc-render/                           (new)
mobile/lib/features/productivity/collab_docs/...
mobile/lib/core/router/app_router.dart     (edit)
mobile/lib/l10n/app_en.arb                 (edit)
supabase/migrations/162_collaborative_docs.up.sql
supabase/migrations/162_collaborative_docs.down.sql
```

## 6. Test Plan

- Unit: 80% on docs package; ACL matrix 100%
- Integration: full flow create -> connect -> co-edit -> snapshot -> restore (testcontainers + Hocuspocus)
- E2E: Maestro on a 2-device side-by-side test (cursor visible, edits propagate)
- Load: simulate 25 concurrent editors per doc x 100 docs; p99 update propagation < 300ms
- Chaos: kill Hocuspocus mid-edit; verify reconnect + replay
- Accessibility: VoiceOver on iOS, TalkBack on Android in WebView
- Security: JWT replay test; revoked-token test; ACL race test

## 7. Rollout & Feature Flags

- Flag `feature.collab_docs.enabled`
- Server-level allowlist during beta
- 1% -> 10% -> 50% -> 100% over 28d
- Kill switch flips Hocuspocus to read-only mode

## 8. Rollback Plan

1. Flag flip (UI hides, API 404 except read)
2. Hocuspocus read-only mode
3. Stop snapshot worker
4. Tables left alone; data preserved
5. Down migration only on corruption

## 9. Dependencies / Blockers

- Depends on: channels, server-members, push-notifications, Appwrite buckets
- Blocks: channel-notes (lighter cousin reuses some UI)
- External: Hocuspocus GH project (vendored fork acceptable)

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Hocuspocus single-host downtime | M | H | Auto-restart; cluster mode in v1.1 |
| Yjs binary blob growth | M | M | Snapshot + delta prune cron |
| Mobile WebView a11y gaps | M | M | Mirror toolbar in native; ARIA in editor |
| Large image inflates updates | L | M | Image stays in Appwrite; doc holds URL only |
| JWT secret leak | L | H | Rotate quarterly; revoke list cached |

## 11. Cost Model

| Component | Free tier | Estimated $ at 100k DAU |
|-----------|-----------|--------------------------|
| Hocuspocus host | self-host | $20/mo small VPS |
| Markdown sidecar | self-host | $5/mo |
| DB storage | Supabase | $0 (capped 50KB/doc) |
| Image storage | Appwrite | $0 |
| **Total** | | **~$25/mo** |

## 12. Done Definition

- [ ] All tasks checked
- [ ] Hocuspocus stable for 7d in beta with no data loss
- [ ] Snapshot recovery tested via chaos drill
- [ ] Beta NPS >= 25
- [ ] Zero P0/P1 in 7d post-GA
