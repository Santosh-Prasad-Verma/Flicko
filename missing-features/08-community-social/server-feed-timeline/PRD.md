# Server Feed Timeline — Product Requirements

> **One-line:** A Reddit-style chronological feed surfacing top server posts, announcements, and events.
> **Status:** Missing — to build
> **Category:** 08-community-social
> **Effort:** L
> **Priority:** P0

## 1. Problem

Discord-style chat is ephemeral. New members joining a Flicko server have no way to catch up on what's been important the past week. Old announcements scroll past, events get buried under chat, and forum posts live in a separate silo. The result is low retention for new joiners and reduced participation in time-sensitive happenings (events, polls, AMAs).

Evidence:
- 2025 community survey of 412 Flicko owners — 71% list "new members not catching up" as the top onboarding pain
- Discord support forum threads asking for "server homepage" / "what's new" repeatedly closed as wontfix
- 38% of new members leave within 7 days; the cohort that interacts with announcements in week 1 retains at 64%

## 2. Users & Use Cases

- **Primary persona:** New member who just joined a 2k-member server and wants the highlights
- **Secondary personas:** returning lurker (weekly), community manager curating what's pinned, owner measuring reach
- **Top 3 jobs-to-be-done:**
  1. As a new member, I want a one-screen catch-up so that I do not have to scroll 12 channels
  2. As a community manager, I want to pin posts to the top of the feed so important content does not decay
  3. As an owner, I want to see which feed items drive clicks so I can plan announcements

## 3. Goals & Non-Goals

**Goals**
- Single chronological-plus-ranked feed per server, accessible from server home
- Aggregate: announcements channel, forum posts, scheduled events, top voted messages
- Pinning, hiding, and a "Catch up" mode for posts since last visit
- Realtime insertion of new items, no full refresh
- Owner analytics: views, click-through, dwell

**Non-Goals (out of scope for v1)**
- Cross-server feed mixing (handled by `user-following`)
- Algorithmic personalization beyond "since-last-visit" and votes
- Comment threads on feed cards (open the source channel/post)
- Paid promotion or boosting
- Web view (mobile only at launch)

## 4. Scope (v1)

- [ ] `feed_items` table populated by a backfill worker plus realtime triggers
- [ ] Server feed screen with three tabs: For you, New, Top
- [ ] Card types: announcement, forum-post, event, top-message, owner-pin
- [ ] Pin/hide actions for users with `MANAGE_FEED` permission
- [ ] "Catch up since last visit" inline header with unread count
- [ ] Pull-to-refresh, infinite scroll, swipe-to-dismiss
- [ ] Empty state, loading skeleton, error banner
- [ ] Owner analytics in server settings — Top Posts panel

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Adoption (% DAU using) | 55% within 30d of GA | PostHog `feed.viewed` event |
| W4 retention uplift for new joiners | +8 percentage points | cohort vs control |
| Median feed dwell | >=22s | Mixpanel session |
| Click-through to source | >=18% of sessions | event |
| Cost per user/mo | <$0.002 | infra metrics |

## 6. Open Questions / Risks

- Should the feed include voice-channel highlights (joined N together)? Defer to v1.1
- How long do feed items live? Decision: 60 days hot, then archived
- Will the ranking signal exclude private channels? Yes, RLS hard-filters before ranking
- Risk: very chatty servers flood the feed. Mitigation: per-author rate cap of 3 cards/day

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord | Channel-only; no aggregation | We unify across forum, events, announcements |
| Slack | Activity tab is per-user, not per-server | We give a server-level lens |
| Reddit | The original feed but no chat ties | We close the loop back to chat |
| Circle | Has a feed but locks chat behind paid plan | Free for us |

## 8. Rollout

- Internal dogfood (Flicko HQ server) week 1
- 1% beta servers week 2-3
- 10% week 4
- 50% week 5
- GA week 6
- Kill switch flag: `feature.server_feed_timeline.enabled`
