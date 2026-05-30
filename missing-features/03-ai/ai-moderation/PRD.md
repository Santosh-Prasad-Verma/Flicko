# AI Moderation — PRD

> **One-line:** Pre-send Llama-Guard scoring for toxicity/harm beyond keyword filters, with per-server thresholds and mod queue.
> **Effort:** M · **Priority:** P0

## Problem
Existing automod is keyword-based and misses sarcasm, paraphrase, dog-whistles, and harm categories like self-harm. AI scoring catches what regex can't.

## Users
- Server moderators of mid-large communities.
- Trust & Safety team auditing edge cases.

JTBDs:
1. Auto-block obvious harm (CSAM, self-harm, violent threats).
2. Send borderline messages to mod queue.
3. Tune sensitivity per server.

## Goals
- 5 harm categories: hate, harassment, sexual, self-harm, violence.
- Pre-send scoring (block before publish if above 0.95).
- Mod queue for 0.7–0.95 range.
- Per-server thresholds.

Non-goals: Replace human moderation; replace regex automod (run alongside).

## Scope
- [ ] Inline pre-send classifier
- [ ] Per-server threshold config
- [ ] Mod queue UI
- [ ] User appeal flow
- [ ] Audit log integration

## Metrics
- False-positive <2% measured against held-out set.
- Mod queue resolution time p50 <30 min.
- Human override rate <10%.

## Risks
- Bias in classifier. Mitigation: locale-aware threshold + appeal route.
- Latency overhead. Mitigation: sub-200ms target; off-thread.
- Privacy. Mitigation: classifier runs locally on Ollama or via Groq; never stores text post-decision.

## Competitive
| Product | Take | Gap |
|---------|------|-----|
| Discord AutoMod | regex + simple ML | richer harm taxonomy |
| Slack | basic | richer + appeal |
| Reddit Crowd Control | community-only | per-server |
