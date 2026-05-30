# Collaborative Docs — Product Requirements

> **One-line:** Real-time co-edited docs (Yjs CRDT) embedded in a channel.
> **Status:** Missing — to build
> **Category:** 06-productivity
> **Effort:** XL
> **Priority:** P1

## 1. Problem

Communities and small teams build playbooks, FAQs, server rules, raid strategies,
event run-of-show, and design briefs together. Today they paste a Google Docs
link in a pinned message; permission management is awful, the doc lives outside
the chat, and contributors switch context to edit. Discord has nothing native;
Notion is a separate product; Slack Canvas is paid.

We embed a real-time collaborative document in a channel. Multiple people can
edit at once and see each other's cursors. The doc is owned by the server,
respects channel permissions, and shows up in the channel header next to pinned
messages.

## 2. Users & Use Cases

- **Primary persona:** moderator team building a server playbook collaboratively.
- **Secondary personas:** event organizers writing a run-of-show; study group
  taking shared lecture notes; small team writing a project spec.
- **Top jobs-to-be-done:**
  1. As a mod team, we want to edit a single living doc together so the
     onboarding playbook stays current.
  2. As a contributor, I want to see who else is editing right now so we
     don't trample each other.
  3. As a server owner, I want to control who can edit vs. comment so
     contractors don't break things.

## 3. Goals & Non-Goals

**Goals**
- Real-time multi-user editing with sub-second sync (Yjs over WebSocket)
- Channel-scoped: docs live in a channel, inherit visibility
- Markdown-style rich text: headings, lists, code blocks, links, images, tables
- Mentions resolve to server members
- Version history with named snapshots
- Comment threads anchored to a selection

**Non-Goals (v1)**
- Page hierarchy / nested pages
- Public sharing outside the server
- Database/structured tables (Notion-style)
- Inline embeds beyond images and Flicko message links
- Offline editing (merging is supported via Yjs but UI defers to v1.1)

## 4. Scope (v1)

- [ ] Create / open / archive doc per channel
- [ ] Hocuspocus-backed real-time sync
- [ ] Presence: avatars + colored cursors
- [ ] Rich text via Tiptap (Yjs-aware)
- [ ] Mentions @user, channel #links, message links
- [ ] Image upload (Appwrite)
- [ ] Comment threads anchored to selection
- [ ] Version snapshots: auto every 5 min idle, named manual
- [ ] Permission: read = channel read; edit = explicit grant per doc
- [ ] Doc list per server

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Servers with >=1 doc in 30d | 12% active | PostHog |
| Concurrent editors p95 | 4 | Hocuspocus telemetry |
| Sync latency p99 | <300ms | client report |
| Cost per doc/month | < $0.002 | infra |
| First-30d retention | 60% return to doc | events |

## 6. Open Questions / Risks

- Hocuspocus single instance vs. cluster? Single instance with sticky-session
  load balancer for v1; clustered (Redis-backed) for GA.
- Storage: Yjs binary updates accumulate. We snapshot every N updates and
  prune deltas older than the latest snapshot.
- Image uploads inside Yjs: store URL only (Appwrite); never embed bytes.
- Migration if we ever swap to a non-Yjs CRDT: keep a Markdown export field.

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord | None native | Whole feature |
| Slack Canvas | Paid; awkward share | Free, in-channel |
| Notion | External app | Embedded, server-scoped |
| Confluence | Heavy | Lightweight, chat-native |
| Google Docs | External | Native permissions tied to channel |

## 8. Rollout

- Internal dogfood 14d (Hocuspocus stress test)
- 20-server beta 21d
- Flag `feature.collab_docs.enabled` 1% -> 10% -> 50% -> 100% over 28d
- Kill switch: flag flip + Hocuspocus enters read-only mode
