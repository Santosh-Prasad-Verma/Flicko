# Kanban Boards — Backend Schema

## 1. Tables

### `kanban_boards`

```sql
CREATE TABLE kanban_boards (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id   UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  name        TEXT NOT NULL CHECK (length(name) BETWEEN 1 AND 80),
  description TEXT CHECK (length(description) <= 1000),
  cover_color TEXT NOT NULL DEFAULT '#7C5CFF',
  archived_at TIMESTAMPTZ,
  created_by  UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_kanban_boards_server ON kanban_boards(server_id) WHERE archived_at IS NULL;
```

### `kanban_columns`

```sql
CREATE TABLE kanban_columns (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  board_id    UUID NOT NULL REFERENCES kanban_boards(id) ON DELETE CASCADE,
  name        TEXT NOT NULL CHECK (length(name) BETWEEN 1 AND 40),
  status_map  TEXT NOT NULL CHECK (status_map IN ('todo','in_progress','blocked','done','cancelled')),
  position    REAL NOT NULL,                     -- fractional indexing (LexoRank-like)
  wip_limit   INT,                               -- null = unlimited
  collapsed   BOOLEAN NOT NULL DEFAULT false,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_kanban_columns_board ON kanban_columns(board_id, position);
```

### `kanban_cards`

```sql
-- Join row binding a task to a board column with a position.
CREATE TABLE kanban_cards (
  task_id     UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  board_id    UUID NOT NULL REFERENCES kanban_boards(id) ON DELETE CASCADE,
  column_id   UUID NOT NULL REFERENCES kanban_columns(id) ON DELETE RESTRICT,
  position    REAL NOT NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (board_id, task_id)
);

CREATE INDEX idx_kanban_cards_column   ON kanban_cards(column_id, position);
CREATE INDEX idx_kanban_cards_task     ON kanban_cards(task_id);
```

### `kanban_card_history`

```sql
CREATE TABLE kanban_card_history (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  board_id    UUID NOT NULL REFERENCES kanban_boards(id) ON DELETE CASCADE,
  task_id     UUID NOT NULL,
  from_column UUID,
  to_column   UUID NOT NULL,
  actor_id    UUID REFERENCES users(id) ON DELETE SET NULL,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_kanban_history_board_time ON kanban_card_history(board_id, created_at DESC);
```

## 2. RLS Policies

```sql
ALTER TABLE kanban_boards  ENABLE ROW LEVEL SECURITY;
ALTER TABLE kanban_columns ENABLE ROW LEVEL SECURITY;
ALTER TABLE kanban_cards   ENABLE ROW LEVEL SECURITY;

CREATE POLICY kanban_boards_member_read ON kanban_boards FOR SELECT
  USING (server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid()));

CREATE POLICY kanban_boards_mod_write ON kanban_boards FOR INSERT
  WITH CHECK (server_id IN (
    SELECT server_id FROM server_members
    WHERE user_id = auth.uid() AND role IN ('owner','admin','mod')));

CREATE POLICY kanban_columns_member_read ON kanban_columns FOR SELECT
  USING (board_id IN (SELECT id FROM kanban_boards
         WHERE server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid())));

CREATE POLICY kanban_cards_member_read ON kanban_cards FOR SELECT
  USING (board_id IN (SELECT id FROM kanban_boards
         WHERE server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid())));
```

## 3. Triggers

```sql
CREATE TRIGGER kanban_boards_set_updated_at
  BEFORE UPDATE ON kanban_boards
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

CREATE TRIGGER kanban_cards_set_updated_at
  BEFORE UPDATE ON kanban_cards
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Sync task.status when card moves columns.
CREATE OR REPLACE FUNCTION kanban_sync_task_status() RETURNS TRIGGER AS $$
DECLARE m TEXT;
BEGIN
  SELECT status_map INTO m FROM kanban_columns WHERE id = NEW.column_id;
  UPDATE tasks SET status = m WHERE id = NEW.task_id;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

CREATE TRIGGER kanban_cards_sync_status
  AFTER INSERT OR UPDATE OF column_id ON kanban_cards
  FOR EACH ROW EXECUTE FUNCTION kanban_sync_task_status();
```

## 4. Migration File

Path: `supabase/migrations/164_kanban_boards.up.sql`

```sql
BEGIN;
-- create tables, indexes, RLS, triggers
INSERT INTO kanban_columns (board_id, name, status_map, position)
  -- seeded by service after board create, not migration
GRANT SELECT, INSERT, UPDATE, DELETE ON kanban_boards  TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON kanban_columns TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON kanban_cards   TO authenticated;
GRANT SELECT                          ON kanban_card_history TO authenticated;
COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `kanban:board:<id>:state` | columns+cards JSON | 30s |
| `kanban:board:<id>:wip:<col>` | int | 10s |

## 6. Search Index

Cards are searched via `tasks` index (no separate kanban index).

## 7. Object Storage

Board cover image is a 6-char hex color, no upload.

## 8. Data Retention

- Boards archived: purged after 60d
- Card history kept indefinitely (cheap; useful for cycle-time charts later)

## 9. Sample Queries

```sql
-- Board state with filters
SELECT c.id AS column_id, c.name, c.status_map, c.position, c.wip_limit,
       t.id AS task_id, t.short_id, t.title, t.priority, t.due_at,
       k.position AS card_position
FROM kanban_columns c
LEFT JOIN kanban_cards k ON k.column_id = c.id
LEFT JOIN tasks t ON t.id = k.task_id
WHERE c.board_id = $1
  AND ($2::uuid IS NULL OR t.id IN (
    SELECT task_id FROM task_assignees WHERE user_id = $2))
ORDER BY c.position, k.position;

-- WIP count
SELECT count(*) FROM kanban_cards WHERE column_id = $1;
```
