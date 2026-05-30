# Cross-Server Channels — Product Requirements

> **One-line:** One channel mirrored across multiple servers, with intersected permissions.
> **Status:** Missing — to build
> **Category:** 08-community-social
> **Effort:** XL
> **Priority:** P1

## 1. Problem

Allied communities (sister servers, regional chapters, multi-team co-ops) want to chat together without forcing every member to join all servers. Today they pick one server as the canonical one, and the others post screenshots or link bots. The result: fragmented conversation and lost context. Meanwhile, federation in Matrix/IRC works but is too heavy for our setting.

Evidence:
- 2025 owner survey: 31% of medium servers (>1k) expressed interest in shared channels
- Matrix bridges break weekly; users complain about UX
- 19% of Flicko members are in multiple "thematic" servers around the same topic

## 2. Users & Use Cases

- **Primary persona:** Owner of a regional gaming chapter who wants a global #lounge with sister chapters
- **Secondary personas:** mod intersecting permissions, member sending one message that lands in 3 servers
- **Top 3 jobs-to-be-done:**
  1. As an owner, I link my #global-lounge with another server's lounge
  2. As a member, I post once and it shows for everyone in linked servers
  3. As a mod, I can locally hide a message without affecting other servers

## 3. Goals & Non-Goals

**Goals**
- Bilateral or multi-party "federation-lite" channel links (up to 5 servers)
- Single message store, multiple channel mappings
- Intersection of permissions: post requires all linked channels to allow
- Local mute/ban affects only one server's view
- Realtime fanout via Centrifugo to all linked clients
- Owner can leave the link at any time without breaking history
- Compatible with existing message reactions, threads, votes

**Non-Goals (out of scope for v1)**
- Voice channels
- Cross-server file syncing of huge attachments (defer to v1.1)
- Outbound federation to non-Flicko platforms

## 4. Scope (v1)

- [ ] `cross_server_links` table joining N channels to one logical link id
- [ ] Single `messages` row referenced by N `channel_messages` mappings
- [ ] Linked-channel UI badge
- [ ] Permission intersection at post time
- [ ] Local moderation actions vs global (delete propagates if author or global mod)
- [ ] Owner-side dashboard to manage links

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Linked channels created | >=200 within 90d of GA | DB |
| Messages per linked channel | >=2x parent average | DB |
| Member satisfaction | >=4.0/5 | survey |
| Cost per user/mo | <$0.0006 | infra |

## 6. Open Questions / Risks

- Permission intersection when servers have different role schemes: lowest-common-denominator
- DM-style abuse from one bad server affecting others. Mitigation: per-server kick removes link visibility
- Storage: messages stored once; channel mapping references row
- Risk of split-brain on partition. Mitigation: NATS message bus with at-least-once delivery and dedup

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord | None native | Greenfield |
| Matrix | Full federation | Too heavy and lossy |
| Slack Connect | Org-level | We do it per channel |
| Revolt | None | Same gap |

## 8. Rollout

- Internal dogfood week 1-2
- 1% beta servers week 3-4
- 10% week 5
- 50% week 6
- GA week 7
- Kill switch flag: `feature.cross_server_channels.enabled`
