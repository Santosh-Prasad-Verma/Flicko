# Post Upvote/Downvote Global — Product Requirements

> **One-line:** Reddit-style up and down votes on any message or post, with per-channel opt-in.
> **Status:** Missing — to build
> **Category:** 08-community-social
> **Effort:** M
> **Priority:** P0

## 1. Problem

Discord pinned-reactions and emoji counts work for hype, not for surfacing signal. Forum posts have voting but messages do not. Members rely on screenshots and bot commands to vote, which fragments data and prevents ranking. Without a unified signal, the new server feed cannot know what's actually good.

Evidence:
- 2025 community feedback: 64% of owners want a "best of channel" view they cannot build today
- 211 third-party "vote bots" installed across the top 1k Flicko servers, indicating clear demand
- Forum posts using votes get 2.3x more replies than ones without

## 2. Users & Use Cases

- **Primary persona:** Member who wants to upvote a useful answer in #help so it floats up
- **Secondary personas:** owner who wants signal to feed the timeline; mod muting bad-actor downvote brigades
- **Top 3 jobs-to-be-done:**
  1. As a member, I want to upvote a great post so others see it first
  2. As an owner, I want voting disabled in #venting so it does not become a popularity contest
  3. As a mod, I want to see who downvoted to spot brigades

## 3. Goals & Non-Goals

**Goals**
- One vote model that works for messages and forum posts
- Per-channel toggle, default OFF for non-forum channels
- Net-vote display in chat with quick up/down arrows
- Backend exposes vote events for the feed ranker
- Anti-abuse: rate limits, brigade detection, minimum-account-age gate
- Vote audit log for mods (with privacy considerations)

**Non-Goals (out of scope for v1)**
- Karma scores or user reputation
- Reddit-style "best/controversial" sort beyond Top
- Vote weights based on roles
- Voting on voice messages
- Vote across federated servers

## 4. Scope (v1)

- [ ] `votes` table unified across `target_kind = message|forum_post`
- [ ] Per-channel `votes_enabled` flag in `channel_settings`
- [ ] API: cast, change, retract
- [ ] Realtime: net score updates
- [ ] Anti-abuse: rate limits 60/min, account age gate, basic brigade heuristic
- [ ] Mod audit panel showing vote events for last 7 days
- [ ] Mobile UI: arrows on message bubble, animated count

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Adoption | 30% DAU casting >=1 vote within 30d | event counter |
| Channels enabled | 25% of non-forum channels enabled by owners | setting flag |
| Brigade false-positive rate | <2% | mod review sample |
| Vote latency p95 | <120ms | API metric |
| Cost per user/mo | <$0.0005 | infra |

## 6. Open Questions / Risks

- Should we hide downvote in family-friendly servers? Decision: per-server flag `disable_downvote`
- Should votes be anonymous to others? Yes, only mods see voter identity
- Brigade detection threshold: votes from N accounts <14d old in M minutes; tunable
- Risk of users gaming: mitigated by account age + IP cluster heuristic

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord | Reactions only | We give net score and ranking |
| Reddit | Karma everywhere | We let owners disable per channel |
| Slack | None | Clear gap |
| Revolt | Reactions | Same gap as Discord |

## 8. Rollout

- Internal dogfood week 1
- 1% beta servers week 2-3
- 10% week 4
- 50% week 5
- GA week 6
- Kill switch flag: `feature.votes_global.enabled`
