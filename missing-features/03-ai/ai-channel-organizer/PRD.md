# AI Channel Organizer — PRD

> **One-line:** One-shot AI suggestion that proposes a reorganized channel structure based on current channels and recent activity.
> **Effort:** M · **Priority:** P2

## Problem
Servers grow organically; channels accumulate, dead channels persist, naming drifts. Admins lack time to audit. AI can propose a clean structure they review-and-apply in one click.

## Users
- Server admins / moderators of mid-large servers (>100 channels).

JTBDs:
1. As an admin, run a one-click "reorganize my server" and get a proposed plan.
2. Compare proposed vs current side-by-side.
3. Apply selectively (per category).

## Goals
- Suggestion under 30s.
- Plan is a diff (rename / archive / merge / move).
- Dry-run first; never auto-apply.

## Scope
- [ ] Trigger from server settings
- [ ] Activity-based pruning suggestions
- [ ] Category re-grouping
- [ ] Selective apply with audit log

## Metrics
- 30% of large servers run it within 60d.
- 40% accept-rate on individual suggestions.
- Cost <$0.02 per run via Groq.

## Risks
- Hallucinated channel suggestions. Mitigation: ground prompt in JSON of actual channels + 14d activity stats.
- Destructive accidents. Mitigation: dry-run + per-row apply.

## Competitive
| Product | Take | Gap |
|---------|------|-----|
| Discord | nothing | greenfield |
| Slack Workflow Builder | manual | AI-driven |
