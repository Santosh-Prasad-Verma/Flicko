# PRD - Reward System

## Summary
The Reward System grants creators, members, and servers automatic incentives for desirable platform actions (first message, daily streak, hosting a successful stage, completing a challenge, hitting a subscriber milestone). Rewards can be coins, badges, role unlocks, discount codes, or cash-equivalent payouts. The system runs as a rules engine consuming events from the platform outbox and writing immutable grants. It is the engagement-loop backbone for every other 07-economy module.

## Problem
Engagement on a creator platform is brittle without a feedback loop that surfaces immediate value for completing actions. Manual incentive programs run by ops are slow, inconsistent, and not auditable. Existing systems (Discord engagement bots, Slack Karma) are siloed and do not pay actual money. We need a server-aware, creator-aware, anti-abuse rule engine that reliably emits rewards within 30 seconds of triggering events with full ledger trail.

## Jobs To Be Done
- As a **member**, when I complete my first 3 actions on a server, I want to receive a small coin gift, so I feel onboarded.
- As a **creator**, when I cross 100 subscribers, I want a celebratory badge + bonus payout, so milestones feel earned.
- As a **server owner**, when my server stays active 7 days, I want a server-level perk unlock, so my community is rewarded.
- As **growth**, I want to A/B reward rule variants without redeploying, so we can iterate experimentation.
- As **finance**, I want every reward grant ledgerized with budget caps, so we avoid surprise costs.

## Scope
In: rule definitions (DSL or JSON), event ingestion from outbox/NATS, grant computation, idempotency per event, budget/quota per rule, badges, role grants, coin payouts, discount code mints, anti-abuse cooldowns, admin UI.
Out (v1): user-defined rules per server (admins use templates), cross-platform rewards, gamification leaderboards (separate module), randomized loot boxes (regulatory risk).

## Metrics
- D7 retention lift on members who received first-week reward >= +14 pp vs no-reward cohort.
- Rule SLA: 99% of triggered events produce a grant within 30 s.
- Budget overrun: 0 incidents (hard cap).
- Reward fraud rate: < 0.5% of grants reversed.

## Competitive Table
| Surface | Rule engine | Budget caps | Grant ledger | Cash rewards | A/B framework |
|---|---|---|---|---|---|
| Discord engagement bots | Per-bot | No | No | No | No |
| Reddit Karma | Implicit | No | No | No | No |
| Twitch Bits boosts | Per-streamer | Yes | Limited | No | No |
| Roblox player events | Yes | Yes | Yes | No | Yes |
| Flicko Rewards | Yes (config + DSL) | Yes (per-rule) | Yes (immutable) | Yes (coins, payouts) | Yes (variant + holdout) |

## Risks
- Reward farming via sybil accounts (mitigation: device fingerprint, phone-verification gates for cash, velocity caps).
- Budget runaway from misconfigured rule (mitigation: hard daily cap per rule, on-call alert at 80%).
- Grant double-spend due to event replay (mitigation: idempotency key = sha256(rule_id, user_id, event_id)).
- Tax exposure on cash rewards (mitigation: rewards > $600 / year per US user generates 1099, gated by KYC).

## Open Questions
- Rule DSL or JSON configs only? (Lean: JSON config now, DSL in v2.)
- Reward delivery latency target: 30 s strict or best-effort? (Lean: strict for first-experience rewards, best-effort for milestones.)
- Allow creators to fund custom rules from their balance? (Lean: yes, but only milestone-style rules in v1, strict moderation review.)
