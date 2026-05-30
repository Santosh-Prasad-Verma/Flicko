# Kanban Boards — Technical Requirements

## 1. Architecture Overview

```
        ┌────────────────────────────────────────────────┐
        │ Mobile (Flutter)                               │
        │  BoardScreen (columns, swipe-to-status)        │
        │  BoardListScreen, BoardEditorSheet             │
        └────────────┬───────────────────────────────────┘
                     │ REST + Centrifugo
                     ▼
        ┌────────────────────────────────────────────────┐
        │ Go Backend                                     │
        │  kanban_service.go  kanban_handler.go          │
        │  -- reuses tasks repo for cards --             │
        └────────────┬───────────────────────────────────┘
                     │
                     ▼
        ┌────────────────────────────────────────────────┐
        │ Postgres                                       │
        │  kanban_boards  kanban_columns  kanban_cards   │
        │  (kanban_cards is a join row -> tasks)         │
        └────────────────────────────────────────────────┘
```

## 2. Components

### Backend (Go)
- `backend/internal/services/productivity/kanban/service.go`
- `backend/internal/handlers/kanban/board_handler.go`
- `backend/internal/handlers/kanban/column_handler.go`
- `backend/internal/handlers/kanban/card_handler.go`
- `backend/internal/models/kanban.go`
- `backend/internal/repo/kanban_repo.go`

### Mobile (Flutter)
- `mobile/lib/features/productivity/kanban_boards/`
  - `data/`, `domain/`, `application/`, `presentation/screens/`, `presentation/widgets/`
- Drag-drop on tablet/web via `flutter_reorderable_grid_view: ^2.0.0`
- Phone: `flutter_slidable: ^3.1.0` for swipe + bottom-sheet target picker

### Infra
- DB: Postgres, migration 164
- Realtime: Centrifugo `kanban:board:<board_id>` channel; events `card.moved`, `column.updated`, `wip.exceeded`
- Cache: Redis `kanban:board:<id>:state` 30s TTL
- Cron: nightly stuck-card detector (cards in same column 14d) -> nudge bot post

## 3. API Contracts

### REST
```
POST   /api/v1/kanban/boards
GET    /api/v1/kanban/boards?server=
GET    /api/v1/kanban/boards/:id
PATCH  /api/v1/kanban/boards/:id
DELETE /api/v1/kanban/boards/:id
POST   /api/v1/kanban/boards/:id/columns
PATCH  /api/v1/kanban/columns/:id              { name?, position?, wip_limit?, status_map? }
DELETE /api/v1/kanban/columns/:id
GET    /api/v1/kanban/boards/:id/state         columns + cards (filtered)
POST   /api/v1/kanban/cards/:task_id/move      { to_column_id, position }
```

### Centrifugo
- Channel: `kanban:board:<board_id>`
- Events: `card.moved`, `card.added`, `card.removed`, `column.updated`, `wip.exceeded`

### Payloads
```jsonc
// Move card
{ "to_column_id": "uuid", "position": 3 }
// Response 200
{ "task_id": "uuid", "status": "in_progress", "column_id": "uuid", "position": 3 }
```

## 4. Permissions & Auth

- Scopes: `kanban.read`, `kanban.write`, `kanban.manage`
- Members: read + move own cards
- Mods: full edit
- RLS in `SCHEMA.md`

## 5. Non-Functional Requirements

| NFR | Target |
|-----|--------|
| Board state load p99 | <200 ms (with 200 cards) |
| Move card p99 | <120 ms |
| Realtime fanout | <300 ms |
| Throughput | 200 rps |
| Storage | <$0.0001 per card |

## 6. Dependencies

- Existing: tasks (this feature reuses tasks rows), audit-log, push
- Mobile libs above

## 7. Observability

- `flicko_kanban_card_moves_total{from,to}` counter
- `flicko_kanban_wip_exceeded_total{board}`
- `flicko_kanban_state_load_seconds` histogram

## 8. Failure Modes & Mitigation

| Failure | Impact | Mitigation |
|---------|--------|------------|
| Two simultaneous moves | wrong order | Position rebalanced after move; tie-broken by updated_at |
| Column deleted with cards | cards orphaned | Block delete unless empty or `force=true`; on force, cards reassigned to first column |
| WIP exceeded | UX confusion | Soft warning banner; allow drop |
| Stale realtime client | wrong column | ETag on state load; client re-syncs on conflict |
| Custom status name conflict | display only | Names scoped per board, no global uniqueness |
