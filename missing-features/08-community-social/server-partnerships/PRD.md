# Server Partnerships — Product Requirements

> **One-line:** Two servers form a formal partnership to cross-promote with a shared invite slot.
> **Status:** Missing — to build
> **Category:** 08-community-social
> **Effort:** M
> **Priority:** P2

## 1. Problem

Server owners cross-promote informally today: pasting invite links in `#partners` channels, swapping shoutouts. There is no canonical relationship, no analytics on whether the swap drove joins, and no way for a member to see who their server's partners are.

Evidence:
- 2025 owner survey: 47% run informal partnerships; 84% of those want a "real" feature
- Top servers (>10k members) have 3-7 partner channels each, hand-managed
- Partnership manager bots (PartnerBeast, Trove) installed across 2.4k Flicko servers

## 2. Users & Use Cases

- **Primary persona:** Owner of a 5k-member gaming server wanting reciprocal cross-promotion
- **Secondary personas:** member curious about partners, manager auditing partnerships
- **Top 3 jobs-to-be-done:**
  1. As an owner, I propose a partnership and the other side accepts
  2. As an owner, I see how many joins each partnership drove
  3. As a member, I browse my server's partners

## 3. Goals & Non-Goals

**Goals**
- Two-sided handshake: proposer + acceptor
- Shared invite slot rendered on each server's "About" page
- Per-partnership analytics: clicks, joins, retention 7d
- Up to 25 active partnerships per server (avoids inflation)
- Termination by either side; cooldown before re-pairing

**Non-Goals (out of scope for v1)**
- Multi-party partnerships (>2)
- Paid promotion/ads
- AI-suggested partners (defer; could overlap with friend-suggestions later)

## 4. Scope (v1)

- [ ] `partnerships` table with bilateral status
- [ ] Proposal flow with optional message
- [ ] Per-partnership invite slot
- [ ] Analytics dashboard
- [ ] Termination + 14d cooldown
- [ ] Partner browse page

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Active partnerships per active server | >=2 within 60d | DB |
| Partnership-attributed joins | >=8% of new joins on participating servers | event |
| Owner satisfaction | >=4.2/5 | survey |
| Cost per user/mo | <$0.0001 | infra |

## 6. Open Questions / Risks

- Should partnerships require minimum-size symmetry? No, but warn on >100x size gap
- Risk of partnership farming for Discord-style "partner badge" social proof. Mitigation: cap at 25 active, require both sides to be member-active in last 30d
- Termination message: optional, keep neutral

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord | None | Greenfield |
| PartnerBeast bot | External, owner-only | Native, two-sided |
| Reddit | Subreddit-related communities | Adjacent only |

## 8. Rollout

- Internal dogfood week 1
- 1% beta servers week 2-3
- 10% week 4
- 50% week 5
- GA week 6
- Kill switch flag: `feature.server_partnerships.enabled`
