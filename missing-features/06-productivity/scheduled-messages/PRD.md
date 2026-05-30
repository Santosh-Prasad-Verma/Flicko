# Scheduled Messages — Product Requirements

> **One-line:** Compose a message now, send it at a future time the user picks.
> **Status:** Missing — to build
> **Category:** 06-productivity
> **Effort:** M
> **Priority:** P0

## 1. Problem

Cross-timezone teams and global communities lose half their reach when posts
land at 3am for everyone else. Mods preparing weekly announcements either set
an alarm or rely on a third-party bot. Slack and Outlook ship "Send later"
natively; Discord doesn't. Flicko closes the gap with a scheduler that runs
inside our backend so it works the same on web and mobile, and so the message
comes from the user (not a bot account that breaks formatting and mentions).

## 2. Users & Use Cases

- **Primary persona:** mod or community manager who writes a Sunday newsletter
  Saturday afternoon.
- **Secondary personas:** ESL teacher in a global server who wants to drop a
  prompt at the time her students are awake; team lead in a workspace who
  drafts at end-of-day for next morning.
- **Top jobs-to-be-done:**
  1. As a mod, I want to compose a long announcement Saturday and have it
     post Sunday at 9am local time.
  2. As a member, I want to set up a "good morning" message in my own DM
     that fires every weekday morning.
  3. As a team lead, I want a teammate to be able to edit my scheduled
     message before it sends if they have role permission.

## 3. Goals & Non-Goals

**Goals**
- Schedule any message a user could send normally (text, attachments, mentions, polls)
- One-time and simple recurring (daily, weekdays, weekly)
- Edit / cancel before fire time
- Cap per user per server (50 active scheduled messages) to deter spam
- All-channels view: "My scheduled messages"
- Audit log entry on schedule and on send

**Non-Goals (v1)**
- Approval workflows (sender owns the schedule)
- Bot personas as sender
- Cross-server scheduling without role checks
- Conditional sends ("only if topic still active")

## 4. Scope (v1)

- [ ] Compose -> "Send later" picker -> schedule
- [ ] Edit body or send time before fire
- [ ] Cancel
- [ ] Recurring: daily, weekdays, weekly on specific weekday
- [ ] DM and channel scheduling
- [ ] List view per user
- [ ] Mention/role-ping rules same as live send
- [ ] Audit log entry
- [ ] Resilient firing: pg_cron + worker, idempotent

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| % active users with >=1 scheduled in 30d | 6% | events |
| Median compose -> fire delta | 18h | derived |
| Fire-on-time rate | 99.9% within 60s | worker telemetry |
| Cancel rate | <12% | events |
| Cost per scheduled msg | <$0.0001 | infra |

## 6. Open Questions / Risks

- Permission revocation between schedule and fire: at fire time, re-check
  channel write permission; if missing, fail with reason and notify owner.
- Time spec ambiguity (DST shifts): store IANA tz; convert at fire.
- Stale mentions (user left server before fire): keep markup but render as
  plain text gracefully if unresolvable.
- Mass schedule (someone schedules 1000 spam): rate limit per user.

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Slack | "Send later" native | We mirror UX |
| Discord | None native; bots only | Native, no bot perms |
| Outlook | Send later native | Adapt to chat |
| Twitter/X | Tweetdeck schedules | Group-chat context |

## 8. Rollout

- Internal dogfood 7d
- 1% -> 10% -> 50% -> 100% over 14d
- Flag `feature.scheduled_messages.enabled`
- Kill switch: flag flip + cron pause
