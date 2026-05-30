# Rich Polls — Product Requirements

> **One-line:** Upgrade simple polls to multi-question, ranked, time-limited, and anonymous polls.
> **Status:** Missing — to build (replaces current `polls` v1)
> **Category:** 06-productivity
> **Effort:** L
> **Priority:** P1

## 1. Problem

Today's Flicko polls support a single question and yes/no or multi-choice. Real
community needs go further: ranked-choice elections for community decisions,
multi-section onboarding quizzes used as gates, anonymous opinion polls,
time-limited polls that close at a specific time, and clear visualization of
results. Discord polls are minimal; Slack relies on third-party Polly. We
ship a single rich polls system that covers these without a bot.

## 2. Users & Use Cases

- **Primary persona:** mod running community-wide votes (rule changes, MVP picks).
- **Secondary personas:** members posting fun/anon polls; teams running tradeoff polls.
- **Top jobs-to-be-done:**
  1. As a mod, I want a ranked-choice poll where members rank 5 options and
     we automatically pick the winner (Instant Runoff Voting).
  2. As a member, I want to vote anonymously when the topic is sensitive.
  3. As a mod, I want to combine 3 questions into one poll with a single submit.

## 3. Goals & Non-Goals

**Goals**
- Multi-question polls (1-5 questions per poll)
- Question types: single, multi, ranked, scale 1-N
- Anonymous polls with hashed user_id
- Time-limited (auto-close)
- Visualizations: bar, ranked-bar, scale histogram
- Native compose (no bot)
- Backwards-compat with v1 polls (existing rows auto-mapped)

**Non-Goals (v1)**
- Conditional follow-up questions
- Verified-identity gating beyond server-member
- Embedded media in options beyond emoji

## 4. Scope (v1)

- [ ] Multi-question (max 5)
- [ ] Question types: single, multi, ranked, scale
- [ ] Anonymous mode
- [ ] Auto-close at time or after N votes
- [ ] Ranked-choice tabulation: IRV (Instant Runoff Voting)
- [ ] Live results with toggle "show only after close"
- [ ] Per-poll permissions (members/mods only/specific roles)
- [ ] Migration from `polls` v1 (mapped to single-question single-choice)

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Polls per active server / month | 2x of v1 baseline | events |
| % polls using multi/ranked | 25% | events |
| Vote rate per poll | 35% of channel members | events |
| Cost per vote | <$0.00005 | infra |

## 6. Open Questions / Risks

- IRV correctness: well-tested algorithm; UI shows round-by-round elimination.
- Anonymous + per-user limit: salt per poll like forms; enforced via UNIQUE.
- Migration from v1: keep `polls` rows; new system reads via shim.

## 7. Competitive Landscape

| Product | Their take | Gap |
|---------|------------|-----|
| Discord polls | Single-question | Multi + ranked |
| Slack | None native; Polly external | Free, native |
| Polly | External | Embedded |
| Reddit polls | Anonymous, simple | Multi-question + ranked |

## 8. Rollout

- Internal 7d
- 1% -> 10% -> 50% -> 100% over 21d
- Flag `feature.polls_rich.enabled`
- Auto-fallback to v1 polls when flag off
