# Read Receipts Control — Product Requirements

> **One-line:** Granular per-DM, per-server, per-friend toggles for sending read receipts; default off.
> **Status:** Missing — to build
> **Category:** 10-privacy-security
> **Effort:** S
> **Priority:** P1

## 1. Problem

Discord ships read receipts via the `Read` indicator and "last read" inference, with no per-conversation control. Users get pressure-cooker DM dynamics ("they read it 30 minutes ago and didn't reply"), workplace anxiety in community-as-workspace servers, and no way to opt out short of leaving the server. Snapchat-style "screenshot-everything" anxiety has migrated to read-state stalking.

Real evidence:
- iMessage and WhatsApp both ship granular read-receipt control; users expect parity.
- r/discordapp threads on "turn off read receipts" hit thousands of upvotes.
- Mental-health communities cite read-receipt anxiety as a top onboarding friction.

The pain: every conversation surface broadcasts your attention to others, with no nuance.

## 2. Users & Use Cases

- **Primary persona:** Anyone who values quiet attention — they want to read and respond on their own time without signaling availability.
- **Secondary personas:** Community-server members who use Flicko as their work tool and want an "off-hours mute" for read receipts; people in DM relationships with asymmetric expectations.
- **Top 3 jobs-to-be-done:**
  1. As a user, I want read receipts off by default, so that I can read things without committing to a reply window.
  2. As a friend, I want to enable read receipts for a specific person I trust, so that they know I see their messages.
  3. As a server member, I want server-wide read-receipt-off, so that I do not signal attention to community admins.

## 3. Goals & Non-Goals

**Goals**
- Default-off read receipts for everyone, everywhere.
- Per-DM toggle.
- Per-friend toggle (overrides DM default).
- Per-server toggle.
- Reciprocity model: if you do not send read receipts, you do not see incoming read receipts. ("If you read me, I'll read you.")
- Settings tile to bulk-enable for friends or for a specific server.

**Non-Goals (out of scope for v1)**
- Per-channel read receipts (server-level granularity is enough).
- "Read receipts visible only to the sender" mode (that is the default in iMessage; we do that automatically).
- Tracking when a message was first read (timestamps).

## 4. Scope (v1)

- [ ] User_settings table column matrix.
- [ ] Reciprocity computation in messaging service.
- [ ] Per-DM toggle in DM settings.
- [ ] Per-friend toggle in friend profile.
- [ ] Per-server toggle in server settings.
- [ ] Migration to default-off for all existing users (one-shot).

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Users who turned receipts on for at least one DM | ≥30% within 60d | event |
| User-reported "DM anxiety" in survey | down 20% | survey |
| Reciprocity violations | 0% (by construction) | unit test |
| Performance overhead | <2ms per message read event | metric |

## 6. Open Questions / Risks

- **Risk: existing users miss messages.** Default-off means people do not see "X read your message." Mitigation: in-app explainer at first encounter; settings link prominent.
- **Risk: confusion about reciprocity.** Mitigation: "you only see read receipts from people who can see yours" copy on the toggle.
- **Open: read receipts in group DMs?** v1: each pair toggles independently within the group.

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord | None | Native granular |
| iMessage | Per-conversation | Same + per-friend layer |
| WhatsApp | Global toggle | Granular |
| Slack | Read-position tracker, not receipt | Different scope |

## 8. Rollout

- New users: default-off shipped from day one.
- Existing users: migration sets all toggles to off; explainer on first launch post-migration.
- Kill switch: `feature.read_receipts_control.enabled` (rolls back to old global behavior).
