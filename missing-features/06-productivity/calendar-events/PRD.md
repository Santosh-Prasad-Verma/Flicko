# Calendar & Events — Product Requirements

> **One-line:** Server calendar with recurring events, RSVPs, reminders, and ICS export.
> **Status:** Missing — to build
> **Category:** 06-productivity
> **Effort:** L
> **Priority:** P0

## 1. Problem

Discord communities run book clubs, game nights, study sessions, raid windows,
office hours, and AMAs. Today the only options are pinned messages with a date
typed in plain text, third-party bots like Sesh that gate basic features behind
a paywall, or community members copy-pasting Google Calendar links. There is no
shared, server-scoped source of truth that travels with the server.

The pain shows up in three places. Members miss events because reminders depend
on the bot's polling cadence and timezone guesses. Organizers cannot tell who
will actually attend without writing a poll or scrolling reactions. New members
who join after an event is announced never see the event at all because the
pinned message scrolled away.

Slack has no native calendar either, but Notion, Linear, and even Microsoft
Teams ship one. Flicko closes the gap with a calendar that lives in the server,
respects per-channel scoping, exports ICS so members can subscribe from their
phone calendar, and pushes reminders through the same channel that surfaces
mentions and DMs.

## 2. Users & Use Cases

- **Primary persona:** community moderator running a 500-2000 member server
  with 1-3 weekly recurring events.
- **Secondary personas:** event attendee who wants reminders without joining
  every notification channel; team lead using Flicko for an internal workspace
  who runs sprint ceremonies.
- **Top jobs-to-be-done:**
  1. As a moderator, I want to schedule a recurring weekly event so members
     get a consistent rhythm without me manually re-posting.
  2. As a member, I want to RSVP yes/no/maybe so the host can plan and I get
     a reminder ten minutes before start.
  3. As a member, I want to add the event to my phone calendar so the
     reminder still fires when Flicko is closed.

## 3. Goals & Non-Goals

**Goals**
- One calendar per server, optionally scoped per channel
- Recurring rules covering daily, weekly, monthly-by-day, custom RRULE
- RSVPs with three states: yes, no, maybe; capacity caps optional
- Reminders at T-24h, T-1h, T-10m configurable per event and per user
- ICS export per server and per event with stable UIDs
- Timezone-aware display; store UTC, render in viewer's tz

**Non-Goals (out of scope for v1)**
- Two-way sync with Google or Outlook calendars (see notion-linear-integration)
- Paid ticketing or registration limits beyond capacity
- Video conference provisioning (Discord Stage / Flicko voice channels handle this)
- Calendar invitations to non-Flicko users via email (digest covers it)

## 4. Scope (v1)

- [ ] Create / edit / delete event with title, description, start, end, location, channel, cover image
- [ ] Recurring rules: none / daily / weekly / monthly-on-Nth / custom RRULE
- [ ] RSVP yes/no/maybe with optional cap and waitlist
- [ ] Three reminder offsets configurable per event with per-user override
- [ ] Calendar grid view: month, week, agenda
- [ ] ICS feed per server (`/calendar/<server>.ics`) and per event
- [ ] Timezone display preference per user, default to device tz
- [ ] Auto-thread on event start in linked channel for live discussion
- [ ] Audit log entry on create/edit/cancel

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Servers with at least 1 event in 30d | 18% of active servers | PostHog cohort |
| RSVP attach rate (rsvps / event_views) | 35% | event funnel |
| Reminder open rate | 60% (push) / 45% (digest) | notif tracking |
| Event no-show rate (yes RSVP, no participation) | <25% | join logs |
| Cost per event/month | < $0.0008 | infra metrics |

## 6. Open Questions / Risks

- Recurring exceptions: do we use RRULE+EXDATE or materialize each occurrence?
  Decision: materialize next 90 days into `event_occurrences` for fast queries.
- ICS feed auth: signed URL with rotation? Yes, HMAC over user_id+server_id+secret.
- DST transitions for weekly recurring events crossing the boundary: store IANA
  tz on the event row, not just UTC.
- Cross-server event mirroring (one event in N servers) deferred to v1.1.

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord native events | Voice/Stage tied; no recurring; no RSVP nuance | Recurring, channel-scoping, ICS |
| Sesh bot | Mature but external; paid tier for recurring | Native, free, no bot perms drama |
| Slack | No native calendar | Whole feature is the gap |
| Notion calendar | Standalone, not in chat | Tight chat thread integration |
| Discord paid Events tier | Ticketing focus | Casual recurring events |

## 8. Rollout

- Internal dogfood on Flicko HQ server for 7 days
- Closed beta to 20 hand-picked moderator servers, 14 days
- 1% rollout via flag `feature.calendar_events.enabled`
- 10% after 7 days clean
- 50% after another 7
- GA at day 28 if KPIs hit
- Kill switch flips the flag; cron worker for reminders pauses cleanly because
  it reads the flag on each tick.
