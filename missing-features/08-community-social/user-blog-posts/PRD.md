# User Blog Posts — Product Requirements

> **One-line:** Long-form public posts visible to followers and on user profile pages.
> **Status:** Missing — to build
> **Category:** 08-community-social
> **Effort:** L
> **Priority:** P1

## 1. Problem

Chat is great for back-and-forth, terrible for thoughtful long-form. Power users on Flicko jump to Substack/Medium when they want to write a 1000-word piece, then post a link in chat. The result: discovery suffers, audiences fragment, and Flicko loses the deepest, most retainable content.

Evidence:
- 2025 creator survey: 58% post long-form elsewhere weekly
- Forum posts >800 chars get 4.2x more engagement than chat
- Power-creators average 2.1 platforms; consolidation is desired

## 2. Users & Use Cases

- **Primary persona:** Creator with weekly long-form thoughts
- **Secondary personas:** follower wanting longer reads, server owner curating top blogs to feed
- **Top 3 jobs-to-be-done:**
  1. As a creator, I write a post once and have it visible to followers and on my profile
  2. As a follower, I see new long-form posts in my home feed
  3. As an owner, I can pin a member's post to the server feed

## 3. Goals & Non-Goals

**Goals**
- Markdown editor with image embeds and code blocks
- Public posts with optional cover image
- Comments thread (light: 1 level + replies)
- Edit history; "edited" indicator
- Drafts persist on server, not just local
- Mentions, hashtags, embed cards
- Share link `flicko.app/@user/post-slug`

**Non-Goals (out of scope for v1)**
- Paywalled posts
- Email subscription beyond existing follower digest
- Custom domains
- Analytics beyond basic views/comments/likes

## 4. Scope (v1)

- [ ] `blog_posts` table with markdown, status (draft/published), slug
- [ ] Editor with autosave every 5s
- [ ] Comments with rate limit
- [ ] Likes (separate from votes)
- [ ] Cover images via existing storage
- [ ] Profile page lists posts
- [ ] Home feed integration (via follow fanout)
- [ ] Share preview/OG metadata

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Posts per active creator/mo | >=2 | DB |
| Avg read time | >=70s | event |
| Comment ratio | >=14% of viewers | DB |
| Cost per user/mo | <$0.001 | infra |

## 6. Open Questions / Risks

- Do drafts have RLS? Yes, draft visible only to author until publish
- Should posts support embedded video? Image+gif v1, video v1.1
- Profanity moderation: rely on report flow + future Groq classifier
- Risk of low-quality flood: rate-limit publishes to 3/day; flagging via reports

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord | None | Greenfield |
| Substack | Email-first | We tie to communities |
| Medium | Standalone | We anchor to follower graph |
| Mastodon long-post | Limited | Better editor, better embeds |

## 8. Rollout

- Internal dogfood week 1
- 1% beta creators week 2-3
- 10% week 4
- 50% week 5
- GA week 6
- Kill switch flag: `feature.user_blog_posts.enabled`
