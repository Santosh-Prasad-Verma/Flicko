# Short Videos — PRD

> **One-line:** TikTok-style 60-second vertical videos, server-scoped or public feed, with auto-captions and engagement.
> **Status:** Missing
> **Effort:** XL
> **Priority:** P1

## 1. Problem
Discord has nothing native for short-form video. Communities post links to TikTok/YT Shorts and lose context. A native vertical feed retains attention and becomes a discovery engine for Flicko itself.

## 2. Users
- Creators who want a low-friction posting surface tied to community.
- Members who want to consume bite-sized content without leaving Flicko.
- Admins who want their server's short-video feed to grow membership.

JTBDs:
1. As a creator, I want to record/upload a 60s vertical video.
2. As a viewer, I want a swipe-up feed scoped to servers I'm in.
3. As an admin, I want a server-only feed pinned to a channel.

## 3. Goals
- Sub-3s start time
- Auto-caption every video via Whisper
- Public, server-scoped, and friends-only visibility levels
- Engagement: likes, comments, shares, saves

Non-goals: Video editing suite (use external apps for v1), monetization, ads.

## 4. Scope
- [ ] Record/upload from mobile (60s cap, vertical 9:16 forced)
- [ ] Server transcoding pipeline (HLS adaptive)
- [ ] Auto-captions
- [ ] Vertical feed (FYP / Following / Server)
- [ ] Likes, comments, shares, saves
- [ ] Reports + moderation queue
- [ ] Profile gallery

## 5. Metrics
| Metric | Target |
|--------|--------|
| Posts/DAU | >0.5/day average among posters |
| Watch-time | >3 min/session |
| Retention W4 | >25% |
| Cost per video | <$0.005 |

## 6. Risks
- Storage cost balloon. Mitigation: 90-day retention default, aggressive HLS bitrates.
- Moderation overhead. Mitigation: NSFW classifier + community flagging.
- DMCA. Mitigation: Content ID-lite via audio fingerprinting (open source).

## 7. Competitive
| Product | Take | Gap |
|---------|------|-----|
| TikTok | Best-in-class but standalone | Tied to community |
| YT Shorts | Great recs but no community | Server scope |
| IG Reels | Same as YT | Community + privacy |

## 8. Rollout
- Flag `feature.short_videos.enabled`. Beta on 5 creator servers.
- Public feed gated until moderation tooling ready.
