# AI Server Insights — PRD

> **One-line:** Weekly AI-written report analyzing activity patterns and surfacing actionable suggestions for server admins.
> **Effort:** M · **Priority:** P2

## Problem
Existing server insights are flat charts. Admins need a narrative: what's working, what's dying, what to try.

## Users
- Server owners and admins, especially of mid-large communities.

JTBDs:
1. Get a TL;DR of last week without staring at charts.
2. See specific suggestions ("archive #foo", "add a rule").
3. Compare to last 4 weeks of trends.

## Goals
- Weekly auto-generated report posted to mod channel or DM.
- 3 sections: Activity overview, Patterns spotted, Suggestions.
- One-tap apply where possible.

## Scope
- [ ] Aggregate stats per server per week
- [ ] Pattern detection (peak hours, dead channels, top contributors, churn signals)
- [ ] Groq summarizer with structured prompt
- [ ] Trends across 4 weeks
- [ ] Optional email digest

## Metrics
- 50% of large servers read at least one report per month.
- 20% accept-rate on suggestions.
- Cost <$0.01 per report.

## Risks
- Hallucinated stats. Mitigation: numbers always come from SQL; LLM only writes prose.
- Privacy. Mitigation: aggregates only, no message bodies.

## Competitive
| Product | Take | Gap |
|---------|------|-----|
| Discord Insights | charts only | narrative + suggestions |
| Slack Analytics | charts only | narrative + suggestions |
