# Server Reviews — Product Requirements

> **One-line:** Public 1-5 star rating with text reviews on every server's discovery page.
> **Status:** Missing — to build
> **Category:** 08-community-social
> **Effort:** M
> **Priority:** P1

## 1. Problem

Discovery is broken. Today a member browsing public Flicko servers sees a name, member count, and a description the owner wrote. There is no third-party signal of quality. They join, get a vibe check, and bounce. We need social proof that helps both new joiners pick well and good servers grow.

Evidence:
- 73% of users in our 2025 discovery survey said reviews would help them choose
- 39% of new joiners leave a server within 24h, suggesting bad picks
- Top app stores show 4x conversion lift when ratings are present
- Communities like Reddit's `r/discord_servers` rely on user testimonials (manual)

## 2. Users & Use Cases

- **Primary persona:** Discovery browser deciding among 5 candidate servers
- **Secondary personas:** server owner using reviews to improve, member wanting to recommend
- **Top 3 jobs-to-be-done:**
  1. As a browser, I want to see what real members say before joining
  2. As an owner, I want to read feedback to improve the server
  3. As a member, I want my recommendation to help others find their tribe

## 3. Goals & Non-Goals

**Goals**
- 1-5 stars + optional text review (max 1000 chars)
- Only members who joined >=14 days and have >=20 messages can review
- One active review per user per server, editable for 30 days
- Owner reply to any review (single reply, editable)
- Sort: helpful, newest, lowest, highest
- Helpful votes (separate from global votes feature)

**Non-Goals (out of scope for v1)**
- Reviews on private servers
- Anonymous reviews
- Photo or video attachments
- Reply threads beyond owner's single reply
- Cross-server reputation imports

## 4. Scope (v1)

- [ ] `server_reviews` table with rating, body, timestamps
- [ ] Eligibility check (membership age, message count)
- [ ] Helpful votes counter
- [ ] Owner single reply
- [ ] Mod report and remove flow
- [ ] Discovery page integration
- [ ] Review composer screen
- [ ] Empty state, loading, error
- [ ] Edit window 30 days

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Coverage (% public servers with >=3 reviews) | 25% within 90d | DB count |
| Discovery CTR uplift | +12% join rate | A/B test |
| Average review length | >=80 chars | DB |
| Removed reviews ratio | <8% | mod actions |
| Cost per user/mo | <$0.0001 | infra |

## 6. Open Questions / Risks

- Should reviews be visible to non-members too? Yes, public by design
- Can users review their own server (as owner)? No, blocked
- Localization: reviews show in original language with optional translate button (defer)
- Risk of brigading by competitors. Mitigation: same brigade guard as votes feature; rate limits

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord | None | Greenfield |
| Disboard (third party) | Reviews exist, off-platform | We make it native |
| Top.gg | Bot reviews, not server | Different scope |
| Slack | None | Different audience |

## 8. Rollout

- Internal dogfood week 1
- 1% public servers week 2-3
- 10% week 4
- 50% week 5
- GA week 6
- Kill switch flag: `feature.server_reviews.enabled`
