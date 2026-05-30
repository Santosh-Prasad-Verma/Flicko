# Server Map — Product Requirements

> **One-line:** Opt-in, city-level map showing where members are, with privacy modes.
> **Status:** Missing — to build
> **Category:** 08-community-social
> **Effort:** L
> **Priority:** P2

## 1. Problem

Members of a server often have no idea their fellow members live nearby. This kills opportunities for meetups, language partners, and regional events. Disclosing precise location to the entire community is a privacy nightmare. We need an opt-in geo lens that gives "neighborhood awareness" without surveillance.

Evidence:
- 2025 survey: 38% of communities expressed interest in regional sub-channels but said discovery was the blocker
- Top regional bots (RegionRoles, GeoTag) installed across 1.8k Flicko servers
- Discord disabled location features in 2018 due to safety concerns; opt-in geohash is the path forward

## 2. Users & Use Cases

- **Primary persona:** Member curious about meetups in their city
- **Secondary personas:** organizer planning events, owner growing regional sub-communities
- **Top 3 jobs-to-be-done:**
  1. As a member, I opt in once and see who is in my city
  2. As an organizer, I see member density to pick venues
  3. As a privacy-minded user, I see only countries, never streets

## 3. Goals & Non-Goals

**Goals**
- Strict opt-in, off by default
- Three privacy modes: Country only, Region/state, City (geohash precision-5)
- Never expose street level
- Per-server sharing toggle (you can share in server A but not B)
- Member can revoke at any time; data deleted within 24h
- Map view with clustered pins
- Density heatmap option

**Non-Goals (out of scope for v1)**
- Realtime location ("who is online near me right now")
- Routing or directions
- Custom map styles per server (defer)
- Cross-server federation of maps

## 4. Scope (v1)

- [ ] `member_locations` table with geohash, precision, timestamps
- [ ] Onboarding flow with explicit consent + privacy explainer
- [ ] Map screen with cluster markers
- [ ] Per-server toggle in privacy settings
- [ ] Auto-coarsen to country if many members in dense area cluster
- [ ] Owner heatmap analytics

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Opt-in rate among members | >=12% within 60d | DB |
| Privacy complaint rate | <0.2% | reports |
| Map session retention | >=2 sessions/month per opted-in user | event |
| Cost per user/mo | <$0.0008 | infra |

## 6. Open Questions / Risks

- Map tiles: use Mapbox or open-source MapLibre + free tile provider?
- Risk of location inference attacks. Mitigation: precision-5 geohash (~5km), jittered offset, k-anonymity (>=5 users per geohash bucket or coarsen)
- Minor users (<18) restricted to country-level only (account flag)
- Risk of stalking via cross-server triangulation. Mitigation: never expose precise geohash to other members directly; only aggregated cluster

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord | None (privacy concerns) | We do it safely with geohash |
| Slack | None | None |
| Meetup | Whole product | We layer it on community chat |
| Facebook Events | Privacy issues | We minimize data |

## 8. Rollout

- Internal dogfood week 1 with 5 staff opt-ins
- 1% beta servers with explicit owner ack of privacy responsibilities
- 10% week 4
- 50% week 5
- GA week 6
- Kill switch flag: `feature.server_map.enabled`
