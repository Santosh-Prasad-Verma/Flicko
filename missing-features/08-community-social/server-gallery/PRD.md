# Server Gallery — Product Requirements

> **One-line:** Auto-aggregated gallery of every image and video shared in the server.
> **Status:** Missing — to build
> **Category:** 08-community-social
> **Effort:** M
> **Priority:** P1

## 1. Problem

Visual content (memes, screenshots, art, videos) gets buried within hours in a chat-first app. Members and owners want a single place to browse the visual life of their server. Today they screenshot search results from Discord, paste into a Notion doc, or live without it.

Evidence:
- 2025 community survey: 67% of art/design servers wanted a "server gallery"
- Discord forums repeatedly request a visual archive (top 10 wishlist)
- 28% of messages in art servers contain images

## 2. Users & Use Cases

- **Primary persona:** Member browsing the visual highlights of their art server
- **Secondary personas:** owner curating featured pieces, mod removing inappropriate uploads
- **Top 3 jobs-to-be-done:**
  1. As a member, I scroll a clean grid of images
  2. As an owner, I feature pieces and exclude channels
  3. As a mod, I remove an image with one tap

## 3. Goals & Non-Goals

**Goals**
- Auto-collect images and short videos from configured channels
- Mosaic grid with infinite scroll
- Filter by channel, author, date range
- Per-server toggle and per-channel exclude
- Owner can feature/pin items
- Search by author handle and basic OCR text (later)

**Non-Goals (out of scope for v1)**
- Editing or annotating
- Cross-server gallery
- Reverse image search
- AI auto-tagging (defer to v1.1)

## 4. Scope (v1)

- [ ] Materialized `user_galleries` per server
- [ ] Worker ingests media on message-create
- [ ] Filters: channel, author, date
- [ ] Featured/pinned items
- [ ] Mod hide/remove
- [ ] Lightbox view with metadata

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Servers enabled | 30% within 60d | DB |
| Sessions per active member | >=2/week | event |
| Lightbox views | >=12 per session | event |
| Cost per user/mo | <$0.001 | infra |

## 6. Open Questions / Risks

- NSFW handling: rely on existing channel `nsfw=true` flag; gallery respects it with blur-by-default
- Storage burden: gallery references existing media URLs, no duplication
- Risk of revenge-share: mods can hide; takedown via reports

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord | Per-message search, no gallery | Greenfield |
| Slack | File browser exists, no curation | Better |
| Mattermost | Same as Slack | Better |
| Reddit | Subreddit-as-gallery | Inspired by |

## 8. Rollout

- Internal dogfood week 1
- 1% beta servers week 2-3
- 10% week 4
- 50% week 5
- GA week 6
- Kill switch flag: `feature.server_gallery.enabled`
