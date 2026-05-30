# Email Digest — Product Requirements

> **One-line:** Daily or weekly email summary of missed Flicko activity, sent via Resend.
> **Status:** Missing — to build
> **Category:** 06-productivity
> **Effort:** M
> **Priority:** P1

## 1. Problem

Members in 5+ active servers fall behind. Push works for active users; passive
users (lurkers, busy teammates, executives) need a low-effort recap. Slack
ships a "while you were away" email; Discord doesn't. We send a beautiful,
ranked digest that nudges return without spamming.

## 2. Users & Use Cases

- **Primary persona:** part-time member of 3-10 servers; checks Flicko nightly.
- **Secondary personas:** community lurker; busy parent who reads emails
  during commutes.
- **Top jobs-to-be-done:**
  1. As a part-time member, I want a Monday morning email of last week's
     highlights so I don't miss anything important.
  2. As a community owner, I want my members to come back, so I'd like the
     digest highlight to feature my server when it's relevant.
  3. As a member, I want fine-grained control over which servers count.

## 3. Goals & Non-Goals

**Goals**
- Daily and weekly cadence per user
- Per-server opt-in/opt-out
- Ranked content: mentions, DMs, threads I participated in, then top messages
- Respect notification mute states (muted server -> excluded by default)
- Resend (3k/mo free) used for delivery
- Unsubscribe + preferences page

**Non-Goals (v1)**
- Custom AI-generated summaries (rules-based ranking only)
- Image attachments embedded inline (we link out)
- Per-channel digest control (server-level only)

## 4. Scope (v1)

- [ ] Cadence: off / daily / weekly with day-of-week + hour preference
- [ ] Per-server allowlist (default: all unmuted)
- [ ] Ranked content blocks: Mentions, DMs, My threads, Trending in your servers, Pinned events
- [ ] Email template (HTML + plain text) with dark-mode aware CSS
- [ ] Open + click tracking via Resend
- [ ] One-click unsubscribe per RFC 8058
- [ ] Preferences page in app

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Subscribers (% of weekly users) | 22% | settings telemetry |
| Open rate | 35% | Resend |
| Click-through to app | 18% | Resend |
| Unsub rate per send | <1.5% | Resend |
| Cost per recipient/month | <$0.0006 | Resend free tier holds at our scale |

## 6. Open Questions / Risks

- Privacy: digest body contains snippets; ensure we never include DMs the user
  isn't a participant in.
- Resend free tier limit (3k/mo): for >3k recipients, plan upgrade or fan out
  via SES backup.
- Localization: render digest in user's preferred language (`users.locale`).
- Time-of-send accuracy: send hour respects user's tz.

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Slack | "while you were away" | We add ranked content, server filters |
| Discord | None | Whole feature |
| Notion | Daily Notion | Different scope |

## 8. Rollout

- Internal dogfood 7d
- 1% -> 10% -> 50% -> 100% over 21d
- Flag `feature.email_digest.enabled`
- Kill switch: flag flip + cron pause
