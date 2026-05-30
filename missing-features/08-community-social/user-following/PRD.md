# User Following — Product Requirements

> **One-line:** Follow people across servers and see their public posts in a personal home feed.
> **Status:** Missing — to build
> **Category:** 08-community-social
> **Effort:** L
> **Priority:** P0

## 1. Problem

Discord makes it almost impossible to keep up with a specific person across the servers you share. You have to remember which server they post in, scroll their messages, or DM them. Power-creators (educators, devs, artists) can't accumulate an audience. Members of multiple servers feel scattered.

Evidence:
- 2025 user research with 89 participants: 81% wanted "follow that person" as a primitive
- Top-200 Flicko power-users post in an average of 5 servers; their content fragments
- Twitter/Mastodon-like timelines drive 2-3x DAU compared to siloed chat apps

## 2. Users & Use Cases

- **Primary persona:** Member who admires multiple creators across servers
- **Secondary personas:** creator wanting to grow audience, lurker building a personal home feed
- **Top 3 jobs-to-be-done:**
  1. As a fan, I want to follow @sarah so I see her public posts without joining every server
  2. As a creator, I want a follower count so I can see my reach
  3. As a private user, I want my profile non-followable

## 3. Goals & Non-Goals

**Goals**
- One-click follow/unfollow from profile, message context, public profile page
- Default profile setting: `followable=true`, can be toggled off
- Personal home feed aggregates public posts from people you follow
- Follow request flow when user has `private=true`
- Mutual follow icon in DMs and member lists
- Notification settings per follow: All / Highlights / None

**Non-Goals (out of scope for v1)**
- Follow servers (different feature)
- Follow channels
- Public follower lists if user opts out
- Discord-style "friends" merge (kept separate from follows for now)

## 4. Scope (v1)

- [ ] `follows` table with status: pending, accepted, declined, blocked
- [ ] Profile UX: Follow button, count, mutual badge
- [ ] Privacy: `followable` flag, `private` flag
- [ ] Home feed `home_feed_items` materialized per user
- [ ] Notifications per follow
- [ ] Following / Followers lists with privacy filter
- [ ] Block-prevents-follow rules

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Follows per active user | >=4 within 30d | DB |
| Home-feed sessions | >=3/week per user | event |
| Creator retention W4 | +10pp vs control | cohort |
| Follow-back rate | >=22% | DB |
| Cost per user/mo | <$0.0015 | infra |

## 6. Open Questions / Risks

- Default visibility of followers list: opt-in public or opt-out? Decision: opt-out public for non-private users
- Can followers see your activity in private servers? No, RLS strict
- Risk of harassment via mass-follow. Mitigation: rate limits, blocked users cannot follow
- Notification noise from followed power-users: respect per-follow notification setting

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord | Friends only | We let you follow without DM access |
| Mastodon | Full graph | We tie back to chat |
| Twitter | Original feed | We layer it on community chat |
| Slack | None | Different audience |

## 8. Rollout

- Internal dogfood week 1
- 1% beta week 2-3
- 10% week 4
- 50% week 5
- GA week 6
- Kill switch flag: `feature.user_following.enabled`
