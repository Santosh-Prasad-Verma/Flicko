# Kanban Boards — Product Requirements

> **One-line:** Project boards per server: columns, cards, drag-drop, WIP limits.
> **Status:** Missing — to build
> **Category:** 06-productivity
> **Effort:** L
> **Priority:** P1

## 1. Problem

Once a server has tasks (see `task-management`), people want a board view to
see flow at a glance: what's planned, what's in progress, what's stuck. Linear
and Trello own this UX; Discord has nothing. Slack ships Lists with a basic
board view. Flicko boards live in the server, share the same task store as
the task-management feature, and feel native on phone first.

## 2. Users & Use Cases

- **Primary persona:** project lead running a side-project server with 5-15
  contributors.
- **Secondary personas:** moderation team using a board to track disputes; event
  organizers tracking deliverables.
- **Top jobs-to-be-done:**
  1. As a lead, I want to see all tasks grouped by status so I know what's
     stuck.
  2. As a contributor, I want to drag my task from "in progress" to "review"
     in one swipe.
  3. As a lead, I want a WIP limit on "in progress" so the team doesn't
     thrash.

## 3. Goals & Non-Goals

**Goals**
- One or more boards per server, each board has columns
- Columns map to a status (or custom status if board uses custom statuses)
- Drag-and-drop on web/tablet, swipe-to-next on phone
- Filters: assignee, label, priority, due
- WIP limits per column with soft warning (not hard block)
- Board-level "definition of done" hint per column
- Same source data as `task-management` tasks (no duplicate model)

**Non-Goals (v1)**
- Sprints, velocity charts, burndown
- Custom card fields beyond what tasks already have
- Subtasks
- Cross-server boards

## 4. Scope (v1)

- [ ] Create / edit / delete board with name and column set
- [ ] Default board: To do | In progress | Blocked | Done | Cancelled
- [ ] Custom columns mapped to existing task statuses or custom status names
- [ ] Drag-drop on web/tablet
- [ ] Swipe-to-next-status on phone (haptic confirmation)
- [ ] Filters bar
- [ ] WIP limit with banner when exceeded
- [ ] Per-column collapse
- [ ] Realtime card updates (Centrifugo)

## 5. Success Metrics

| Metric | Target | Measurement |
|--------|--------|-------------|
| Boards per active server (median) | 1 | events |
| Drag/swipe per active board day | 12 | events |
| Stuck-card alert open rate | 35% | notif |
| Cost per board view | <$0.0001 | infra |

## 6. Open Questions / Risks

- Custom statuses vs. mapping to fixed statuses: v1 ships fixed mapping;
  custom names for column display only.
- Phone drag-drop is awkward; v1 uses swipe-and-tap menu.
- WIP soft vs hard: soft to avoid arguments; surfaced as banner + log.

## 7. Competitive Landscape

| Product | Their take | Gap we exploit |
|---------|------------|----------------|
| Trello | Mature, external | Native, free, in chat |
| Linear board | Heavy | Lightweight, mobile first |
| Slack Lists | Paid | Free |
| Discord | None | Whole feature |

## 8. Rollout

- Internal dogfood 7d
- 1% -> 10% -> 50% -> 100% over 21d
- Flag `feature.kanban_boards.enabled`
- Kill switch: flag flip
