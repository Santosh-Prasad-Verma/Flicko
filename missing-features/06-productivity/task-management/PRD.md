# Task Management — Product Requirements

> **One-line:** Per-channel and per-server tasks with assignees, due dates, status, and labels.
> **Status:** Missing — to build
> **Category:** 06-productivity
> **Effort:** L
> **Priority:** P0

## 1. Problem

Server moderators run real work in Flicko: review queues, content scheduling,
event prep, bug triage, and onboarding playbooks. Today they paste todo lists
into pinned messages or maintain a separate Trello/Notion. Either splits
context across tools or rots inside chat.

What members actually need: turn a message into a task in two taps, see who
owes what, get a nudge before the due date. Slack added Lists in 2024 but the
feature is hidden behind a paid tier; Linear is overkill; Trello is outside
the chat. Discord has no native equivalent.

We pull task management into the channel that already holds the conversation.
Right-click a message ("Convert to task"), pick assignee and due, ship. The
task lives next to the chat, and updates ping the assignee inside Flicko.

## 2. Users & Use Cases

- **Primary persona:** moderator running content/onboarding queues for a
  community of 1k-10k.
- **Secondary personas:** small team using Flicko as a workspace; project
  contributors collaborating on a side project.
- **Top jobs-to-be-done:**
  1. As a mod, I want to convert a member's bug report message into a task
     so I can track the fix without losing the link.
  2. As a contributor, I want to see "tasks assigned to me" across all my
     servers so I know my queue at a glance.
  3. As a server owner, I want a board view filtered by status so I can
     see what's blocked.

## 3. Goals & Non-Goals

**Goals**
- Tasks scoped per server, optionally per channel
- Fields: title, description, assignees (multi), due date, status, labels, priority
- Convert-message-to-task via context menu, links back to original message
- Inline status changes from chat ("/task 1234 done") and from board UI
- "My tasks" cross-server inbox
- Per-channel list view with filters (status, assignee, label, due)

**Non-Goals (out of scope for v1)**
- Gantt charts, dependencies, sprints (use kanban-boards feature for board UI)
- Time tracking
- Custom fields beyond labels and priority
- External assignees (must be Flicko users)

## 4. Scope (v1)

- [ ] CRUD task with title, description, assignees, due, status, labels, priority
- [ ] Convert message -> task with backlink
- [ ] Statuses: `todo`, `in_progress`, `blocked`, `done`, `cancelled`
- [ ] Labels: per-server taxonomy with color
- [ ] Priorities: `none`, `low`, `medium`, `high`, `urgent`
- [ ] Assignment: 1-N assignees
- [ ] Due date with timezone-aware reminders
- [ ] Slash commands: `/task new`, `/task assign`, `/task done`, `/task list`
- [ ] My-tasks cross-server inbox
- [ ] Per-channel filtered list
- [ ] Audit log
- [ ] Realtime updates (Centrifugo)

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Servers with >= 1 task in 30d | 22% of active | PostHog |
| Convert-from-message rate | 40% of new tasks | event |
| Median time-to-close | <72h | derived |
| Reminder open rate | 55% | notif tracking |
| Cost per task/month | < $0.0006 | infra |

## 6. Open Questions / Risks

- Soft delete vs. hard delete on task removal? Soft, with 30-day retention.
- Slash command parsing collisions with bots? Namespace under `/task ...`.
- Cross-server inbox query performance: precompute via materialized view? No -
  index on (assignee, status) is enough at our scale.
- Conversion of message -> task copies content; if message edited later, do we
  resync? No, snapshot at conversion time + backlink.

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Discord | None native | Whole feature is the gap |
| Slack Lists | Paid tier; awkward UX | Free, native, two-tap |
| Linear | Power tool; separate app | Lightweight, lives in chat |
| Trello | External | Native + slash commands |
| Notion DB | External | Tight thread integration |

## 8. Rollout

- Internal dogfood 7d
- 20-server closed beta 14d
- Flag `feature.task_management.enabled` 1% -> 10% -> 50% -> 100% over 21d
- Kill switch: flag flip + worker pause
