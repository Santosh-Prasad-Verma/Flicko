# Channel Notes — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec | 1d | PM |
| 1 | Migration 170 | 1d | Backend |
| 2 | Service + handshake (reuses docs infra) | 2d | Backend |
| 3 | Hocuspocus `cn:` namespace + persistence | 1d | Backend |
| 4 | Mobile WebView shell (lite mode) | 3d | Mobile |
| 5 | Channel header pin + deep link | 1d | Mobile |
| 6 | QA, a11y | 2d | QA |
| 7 | Beta -> GA | 14d | All |

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/170_channel_notes.up.sql`
- [ ] Down migration
- [ ] Models `internal/models/channel_note.go`
- [ ] Service + handshake JWT (perm check)
- [ ] Hocuspocus persistence webhook for `cn:` namespace
- [ ] Markdown export at persist time
- [ ] Handler
- [ ] Wire routes
- [ ] Audit log on clear
- [ ] Prometheus counters
- [ ] OpenAPI doc update
- [ ] Tests: perm matrix; size cap; clear flow

## 3. Mobile Tasks

- [ ] Folder `mobile/lib/features/productivity/channel_notes/`
- [ ] DTOs
- [ ] Repository + remote DS
- [ ] Domain entities (Note, NoteMeta)
- [ ] Riverpod providers
- [ ] Note screen using shared WebView shell (lite mode flag)
- [ ] Channel header integration
- [ ] L10n
- [ ] Tests

## 4. AI / Infra Tasks

- [ ] Hocuspocus route `cn:` namespace
- [ ] Same Tiptap bundle, lite preset

## 5. Files Touched

```
backend/
  internal/services/productivity/channel_notes/{service.go,handshake.go}
  internal/handlers/channel_notes/handler.go
  internal/models/channel_note.go
  internal/repo/channel_note_repo.go
  cmd/server/main.go                       (edit)
  api/openapi.yaml                         (edit)
mobile/lib/features/productivity/channel_notes/...
mobile/lib/features/server_channels/...   (edit: header pin)
mobile/lib/core/router/app_router.dart    (edit)
mobile/lib/l10n/app_en.arb                (edit)
supabase/migrations/170_channel_notes.up.sql
supabase/migrations/170_channel_notes.down.sql
```

## 6. Test Plan

- Unit: perm matrix; clear flow
- Integration: handshake -> connect -> persist
- E2E: 2-device coedit
- Load: 10 concurrent; p99 propagation < 300ms
- A11y: TalkBack/VoiceOver in WebView
- Security: handshake replay; revoked perm

## 7. Rollout & Feature Flags

- Flag `feature.channel_notes.enabled`
- 1% -> 100% over 14d

## 8. Rollback Plan

1. Flag flip
2. Tables stay
3. Hocuspocus `cn:` namespace read-only

## 9. Dependencies / Blockers

- Depends on: collaborative-docs Hocuspocus (must be live)
- Blocks: nothing

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Bloat | M | M | 64 KB cap + convert prompt |
| Perm race | L | M | server-side rejects writes |

## 11. Cost Model

| Component | Free | $ at 100k DAU |
|-----------|------|----------------|
| Hocuspocus | shared with docs | $0 incremental |
| DB | Supabase | $0 |
| **Total** | | **$0** |

## 12. Done Definition

- [ ] All tasks checked
- [ ] Beta NPS >= 35
- [ ] Zero P0 in 7d
