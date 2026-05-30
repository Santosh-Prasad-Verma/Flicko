# Disappearing Messages — Product Requirements

> **One-line:** Per-message TTL in DMs and channels with hard-delete on the server.
> **Status:** Missing — to build
> **Category:** 10-privacy-security
> **Effort:** M
> **Priority:** P0

## 1. Problem

Discord messages live forever by default. A casual rant, a phone number shared with a friend, a temp link to a screenshot — they all sit on Discord's servers indefinitely, indexed, searchable, and one breach away from public. Users want the kind of ephemerality they get on Signal: pick a TTL, and the message vanishes from both ends and from the server.

Real evidence:
- Signal's "disappearing messages" is the most-cited reason users prefer it for sensitive convos.
- Discord support forum: "delete after read" feature requests cross 10k upvotes across half a dozen threads.
- Privacy-focused Discord communities use third-party self-destruct bots (Tesseract, Kashima) — fragile, brittle, often broken.

The pain: messages outlive their usefulness, and users have to remember to delete each one manually.

## 2. Users & Use Cases

- **Primary persona:** Privacy-conscious DM user sharing temporary information (one-time codes, scratch ideas, sensitive vents).
- **Secondary personas:** Members of channels with mod-imposed channel-wide TTL (covered separately by `auto-delete-messages`); journalists communicating with sources; activists.
- **Top 3 jobs-to-be-done:**
  1. As a friend, I want to send a phone number that auto-deletes in 1 hour, so that I do not have to remember to clean up.
  2. As a community mod testing a public event, I want messages in the test channel to disappear after a day, so that the channel stays tidy.
  3. As a user, I want to see at a glance which messages are ephemeral and how long they have left.

## 3. Goals & Non-Goals

**Goals**
- Per-message TTL chosen at send time: 5m, 1h, 1d, 7d.
- Hard delete via server-side worker — gone from DB, S3, search index, and clients.
- Visible countdown on the message bubble.
- Per-DM and per-channel default TTL ("default disappearing" preference).
- Senders and recipients can both set their *own* default TTL for their messages; per-message override is always allowed.

**Non-Goals (out of scope for v1)**
- Forwarding-prevention or screenshot blocking (covered by `screen-capture-protection`).
- Channel-wide mod-imposed TTL (covered by `auto-delete-messages`).
- Edit-to-extend-TTL (one-shot only; if you need it longer, resend).
- Custom TTL values beyond the four presets in v1.

## 4. Scope (v1)

- [ ] TTL picker in composer: 5m / 1h / 1d / 7d / off.
- [ ] Visual indicator: clock icon + countdown on each ephemeral message.
- [ ] Server-side `expires_at` column on messages.
- [ ] pg_cron worker sweeping every minute, hard-deleting expired rows + attachments.
- [ ] Realtime push to clients on delete (Centrifugo `message.deleted` event).
- [ ] Per-DM default TTL setting.
- [ ] Audit-log entry on auto-delete (privacy-preserving — no content).

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| % DAU using TTL | ≥8% within 60d | event |
| Median TTL chosen | 1h | event distribution |
| Delete-job lag | <90s p99 | worker metric |
| User-reported "message stuck" | <0.1% | support tag |
| DB rows pruned/day | scales with adoption | dashboard |

## 6. Open Questions / Risks

- **Risk: legal hold conflict** — for some servers, log retention is required by law. Mitigation: server admin can disable feature for that server.
- **Risk: client clock skew** showing wrong countdown. Mitigation: countdown is computed from `expires_at` (server-set) using server-time delta from a 60s sync ping.
- **Open: notifications for ephemeral messages** — when the recipient is offline, do we still push? Yes, but the push body is "(disappearing message)" not the content.
- **Open: replies to expired messages** — surface "This message has expired."

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord | Manual delete only | Native TTL |
| Signal | Per-conversation TTL only | Per-message + per-conversation |
| Telegram | Secret chats only | Works in any channel/DM |
| Snapchat | Forced ephemerality | We give choice |

## 8. Rollout

- Internal dogfood → 5% beta → 25% → GA.
- Kill switch: `feature.disappearing_messages.enabled`.
- Worker pause flag: `worker.disappearing_messages.paused` — flip to halt deletion if a bug.
