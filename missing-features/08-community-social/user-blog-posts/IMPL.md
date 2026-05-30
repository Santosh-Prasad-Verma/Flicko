# User Blog Posts — Implementation Plan

## 1. Phases & Timeline

| Phase | Goal | Duration | Owner |
|-------|------|----------|-------|
| 0 | Spec freeze + design review | 2d | PM/Design |
| 1 | DB schema + migration 194 | 1d | Backend |
| 2 | Backend service + handlers + renderer | 6d | Backend |
| 3 | Mobile editor + reader | 6d | Mobile |
| 4 | Wire-up + Centrifugo + Meilisearch | 2d | Both |
| 5 | QA + accessibility audit | 3d | QA |
| 6 | Beta rollout | 4d | All |
| 7 | GA | 1d | All |

## 2. Backend Tasks

- [ ] Migration `supabase/migrations/194_user_blog_posts.up.sql`
- [ ] Down migration
- [ ] Models `backend/internal/models/social/blog_post.go`
- [ ] Service `backend/internal/services/social/user-blog-posts/service.go`
- [ ] Renderer `backend/internal/services/social/user-blog-posts/render.go`
- [ ] Repo `backend/internal/repo/social/blog_post_repo.go`
- [ ] Handler `backend/internal/handlers/social/blog_handler.go`
- [ ] Wire routes in `backend/cmd/server/main.go`
- [ ] Centrifugo `posts:<author_id>` registration
- [ ] Meilisearch indexer worker
- [ ] OG/SEO metadata in public web service
- [ ] Audit log entries
- [ ] Metrics counters
- [ ] OpenAPI doc update

## 3. Mobile Tasks

- [ ] Feature folder `mobile/lib/features/social/user-blog-posts/`
- [ ] DTOs, repository, datasource
- [ ] Domain entities (post, draft, comment)
- [ ] Riverpod providers (editor, post viewer, comments)
- [ ] Presentation: editor_screen, post_view_screen, comments_sheet, drafts_screen
- [ ] Routing: `/me/drafts`, `/users/:id/posts/:slug`, `/posts/new`
- [ ] L10n keys
- [ ] Tests: widget golden, provider, repository
- [ ] Empty/error/loading states
- [ ] Markdown editor package: `super_editor` or `markdown_editable`

## 4. AI / Infra Tasks

- [ ] Optional: Groq summarization for excerpt fallback (defer to v1.1)

## 5. Files Touched (predicted)

```
backend/
  internal/services/social/user-blog-posts/service.go     (new)
  internal/services/social/user-blog-posts/render.go      (new)
  internal/handlers/social/blog_handler.go                (new)
  internal/models/social/blog_post.go                     (new)
  internal/repo/social/blog_post_repo.go                  (new)
  cmd/server/main.go                                      (edit)
mobile/
  lib/features/social/user-blog-posts/...                 (new tree)
  lib/core/router/app_router.dart                         (edit)
supabase/
  migrations/194_user_blog_posts.up.sql                   (new)
  migrations/194_user_blog_posts.down.sql                 (new)
```

## 6. Test Plan

- Unit: renderer (XSS strings), service, repo; >=85% on render
- Integration: testcontainers Postgres + Meilisearch
- E2E: write -> autosave -> publish -> appears in feed
- Load: k6 100 publishes/min, 1k reads/min
- Accessibility: axe + screen reader on reader view
- Security: XSS regression suite; markdown injection corpus

## 7. Rollout & Feature Flags

- Flag: `feature.user_blog_posts.enabled`
- Default OFF in prod
- Beta: 30 creators
- Canary: 1% -> 10% -> 50% -> 100% over 7d

## 8. Rollback Plan

1. Disable flag
2. Hide editor entry point
3. Reader still works for already-published; or hide entirely if needed
4. Data preserved

## 9. Dependencies / Blockers

- Depends on: media uploads, follow fanout
- Blocks: public-profiles (uses posts as feed)

## 10. Risks

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| XSS via markdown | M | H | Bluemonday strict + tests |
| Performance on long posts | M | M | server-rendered HTML, lazy images |
| Spam comments | M | M | rate limits, mod hide, vote-based ranking |

## 11. Cost Model

| Component | Free tier? | Estimated $ at 100k DAU |
|-----------|-----------|--------------------------|
| Compute | Railway free | $0 |
| DB | Supabase free | $0 |
| Storage | Appwrite free | $0 |
| Search | Meilisearch self-hosted | $0 |
| **Total** | | **$0 target** |

## 12. Done Definition

- [ ] All tasks above checked
- [ ] Code merged to main
- [ ] In-tree spec files updated
- [ ] Dashboard live
- [ ] Beta feedback >=4.0/5
- [ ] Zero P0/P1 bugs in 7-day window
