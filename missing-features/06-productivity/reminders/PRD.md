# Reminders — Product Requirements

> **One-line:** Native /remind slash command for self or channel reminders.
> **Status:** Missing — to build
> **Category:** 06-productivity
> **Effort:** S
> **Priority:** P0

## 1. Problem

Slack's `/remind me 30m` is a daily-use feature for many teams. Discord users
add a Sesh or Reminder bot, hit token limits, fight rate caps, or misconfigure
permissions. Flicko ships it natively. One slash, no bot, predictable timezone
parsing, push notification.

## 2. Users & Use Cases

- **Primary persona:** any active Flicko user.
- **Secondary personas:** mods setting channel-wide nudges; team leads creating
  recurring standup pings.
- **Top jobs-to-be-done:**
  1. As a user, I want to type `/remind me in 30 minutes "follow up with X"`
     and forget about it.
  2. As a mod, I want `/remind #channel friday 9am "submit weekly report"` so
     the whole channel gets pinged at the right time.
  3. As a power user, I want `/remind me every weekday 9am "stand-up"` to set
     a recurring reminder.

## 3. Goals & Non-Goals

**Goals**
- `/remind me <when> <text>` -> personal push + in-app
- `/remind <#channel|@user> <when> <text>` -> channel post or DM at fire time
- `/remind list` -> shows my pending reminders inline
- Natural-language time parsing: "in 30m", "tomorrow 9am", "friday 5pm", "every weekday 9am"
- Recurring via cron-ish syntax: daily / weekdays / weekly / monthly
- Cancel / snooze from notification

**Non-Goals (v1)**
- Conditional reminders ("when X happens")
- Reminders triggered by another user's action
- Reminders longer than 1 year out

## 4. Scope (v1)

- [ ] Slash command parser with time grammar
- [ ] Personal reminders (push + in-app at fire)
- [ ] Channel reminders (post in channel; permission-checked)
- [ ] DM reminders (post DM at fire)
- [ ] Recurring presets: daily, weekdays, weekly on weekday, monthly on Nth
- [ ] List, snooze, cancel
- [ ] Quota: 100 active per user

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| % active users using /remind in 30d | 18% | events |
| Snooze rate | <30% | events |
| Fire-on-time rate | 99.9% within 60s | worker telem |
| Cost per reminder | <$0.00005 | infra |

## 6. Open Questions / Risks

- Time grammar ambiguity (e.g., "tuesday" = next Tuesday or this Tuesday?). Rule:
  if today is Tuesday, "tuesday" = next Tuesday; otherwise upcoming Tuesday.
- Channel reminders authored by who? Use the original setter's identity but
  marked "Reminder set by @user".
- Recurrence on weekdays needs IANA tz to be accurate across DST.
- Permission revoked at fire time -> drop to DM fallback to setter.

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Slack | `/remind` mature | We mirror the UX |
| Discord native | None | Whole feature |
| Discord bots | Sesh, Reminder Bot | Bot perm friction; we're native |

## 8. Rollout

- Internal dogfood 5d
- 1% -> 10% -> 50% -> 100% over 14d
- Flag `feature.reminders.enabled`
- Kill switch: flag flip + cron pause
