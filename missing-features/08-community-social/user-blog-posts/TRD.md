# User Blog Posts — Technical Requirements

## 1. Architecture Overview

```
+------------------+   POST /posts   +-------------------+
| Mobile (Flutter) | --------------> |  Go Backend       |
| Web profile      |                 |  posts_service    |
+------------------+                 +---------+---------+
                                               |
              +-----------------+              v
              | Centrifugo      |    +-----------------+
              | posts:<author>  |    |  Postgres       |
              +-----------------+    |  blog_posts     |
                                     +--------+--------+
                                              |
                                              v
                                NATS flicko.posts.created
                                              |
                                              v
                                  fanout to followers
                                  (uses user-following)
```

Drafts and published posts live in `blog_posts`. Markdown is rendered server-side at publish into `body_html` for fast feed/profile reads. Sanitized via Bluemonday.

## 2. Components

### Backend (Go)
- **Service:** `backend/internal/services/social/user-blog-posts/service.go`
- **Renderer:** `backend/internal/services/social/user-blog-posts/render.go`
- **Handlers:** `backend/internal/handlers/social/blog_handler.go`
- **Models:** `backend/internal/models/social/blog_post.go`
- **Repo:** `backend/internal/repo/social/blog_post_repo.go`

### Mobile (Flutter)
- **Feature folder:** `mobile/lib/features/social/user-blog-posts/`
  - `data/`: dto, repo, datasource
  - `domain/`: post entity, comment, draft
  - `application/`: editor_provider, post_provider, comments_provider
  - `presentation/`: editor_screen, post_view_screen, comments_sheet, profile_posts_list

### Infra
- DB: tables in migration 194
- Storage: Appwrite bucket `blog_covers`
- Cache: Redis for hot posts
- Search: Meilisearch index `blog_posts`

## 3. API Contracts

### REST
```
POST   /api/v1/posts                  draft
PATCH  /api/v1/posts/:id              update draft
POST   /api/v1/posts/:id/publish
POST   /api/v1/posts/:id/unpublish
DELETE /api/v1/posts/:id
GET    /api/v1/posts/:id              by id (auth-aware)
GET    /api/v1/users/:id/posts        list
GET    /api/v1/posts/by-slug/:user/:slug
POST   /api/v1/posts/:id/like
DELETE /api/v1/posts/:id/like
GET    /api/v1/posts/:id/comments
POST   /api/v1/posts/:id/comments
DELETE /api/v1/comments/:cid
```

### WebSocket / Centrifugo
- Channel: `posts:<author_id>`
- Events: `post.published`, `post.updated`, `post.liked`, `comment.created`

### Payloads
```jsonc
{
  "id": "uuid",
  "author_id": "uuid",
  "title": "string<=200",
  "slug": "kebab",
  "body_md": "markdown",
  "body_html": "sanitized html",
  "cover_url": "string|null",
  "tags": ["string"],
  "status": "draft|published|unlisted|removed",
  "like_count": 12,
  "comment_count": 4,
  "view_count": 312,
  "published_at": "iso8601|null",
  "edited_at": "iso8601|null",
  "created_at": "iso8601"
}
```

## 4. Permissions & Auth

- Author writes own posts
- Public read for `published` and `unlisted` (when URL known)
- Drafts: author only via RLS
- Comments: any authenticated user, rate-limited; mods can remove

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| Read p50 | <100 ms (HTML cached) |
| Write p50 | <200 ms (render+sanitize) |
| Throughput | 100 publishes/min |
| Storage | <$0.001 per post |

## 6. Dependencies

- `users`, `follows`, `home_feed_items`, `media`
- Markdown libs: blackfriday + bluemonday

## 7. Observability

- Metrics: `flicko_posts_published_total`, `flicko_posts_render_seconds`, `flicko_comments_created_total`
- Logs: structured per event
- Traces: OTel
- Dashboards: `social-blog`

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| HTML render bug | broken posts | renderer unit tests; canary publish flow |
| Image hotlink abuse | bandwidth | proxy via media service |
| Spam comments | feed pollution | rate limits, mod hide |
| XSS via markdown | account takeover | Bluemonday strict policy |
