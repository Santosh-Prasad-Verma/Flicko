# Task Management — Backend Schema

## 1. Tables

### `tasks`

```sql
CREATE TABLE tasks (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  short_id        BIGINT NOT NULL,                          -- per-server sequence
  server_id       UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  channel_id      UUID REFERENCES channels(id) ON DELETE SET NULL,
  source_message_id UUID REFERENCES messages(id) ON DELETE SET NULL,
  creator_id      UUID NOT NULL REFERENCES users(id) ON DELETE SET NULL,
  title           TEXT NOT NULL CHECK (length(title) BETWEEN 1 AND 200),
  description     TEXT CHECK (length(description) <= 8000),
  status          TEXT NOT NULL DEFAULT 'todo'
                   CHECK (status IN ('todo','in_progress','blocked','done','cancelled')),
  priority        TEXT NOT NULL DEFAULT 'none'
                   CHECK (priority IN ('none','low','medium','high','urgent')),
  due_at          TIMESTAMPTZ,
  due_tz          TEXT DEFAULT 'UTC',
  completed_at    TIMESTAMPTZ,
  archived_at     TIMESTAMPTZ,                              -- soft delete
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (server_id, short_id)
);

CREATE INDEX idx_tasks_server_status     ON tasks(server_id, status) WHERE archived_at IS NULL;
CREATE INDEX idx_tasks_channel           ON tasks(channel_id) WHERE channel_id IS NOT NULL;
CREATE INDEX idx_tasks_due               ON tasks(due_at) WHERE due_at IS NOT NULL AND archived_at IS NULL;
CREATE INDEX idx_tasks_created_by        ON tasks(creator_id);
CREATE INDEX idx_tasks_search            ON tasks USING gin (to_tsvector('simple', coalesce(title,'') || ' ' || coalesce(description,'')));
```

### `task_assignees`

```sql
CREATE TABLE task_assignees (
  task_id     UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  assigned_by UUID REFERENCES users(id) ON DELETE SET NULL,
  assigned_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (task_id, user_id)
);

CREATE INDEX idx_task_assignees_user_status
  ON task_assignees(user_id);
```

### `task_labels`

```sql
CREATE TABLE task_labels (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id   UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  name        TEXT NOT NULL CHECK (length(name) BETWEEN 1 AND 32),
  color       TEXT NOT NULL DEFAULT '#7C5CFF',
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  UNIQUE (server_id, lower(name))
);

CREATE TABLE task_label_links (
  task_id  UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  label_id UUID NOT NULL REFERENCES task_labels(id) ON DELETE CASCADE,
  PRIMARY KEY (task_id, label_id)
);

CREATE INDEX idx_task_label_links_label ON task_label_links(label_id);
```

### `task_comments`

```sql
CREATE TABLE task_comments (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id     UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE SET NULL,
  body        TEXT NOT NULL CHECK (length(body) BETWEEN 1 AND 4000),
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_task_comments_task ON task_comments(task_id, created_at);
```

### `task_history`

```sql
CREATE TABLE task_history (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id     UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  actor_id    UUID REFERENCES users(id) ON DELETE SET NULL,
  field       TEXT NOT NULL,                                -- status, assignee, due, ...
  old_value   JSONB,
  new_value   JSONB,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_task_history_task ON task_history(task_id, created_at);
```

### `task_short_id_seq`

```sql
-- per-server sequence via single-row counter table
CREATE TABLE task_short_id_seq (
  server_id UUID PRIMARY KEY REFERENCES servers(id) ON DELETE CASCADE,
  next_id   BIGINT NOT NULL DEFAULT 1
);

-- allocation function (increments and returns)
CREATE OR REPLACE FUNCTION alloc_task_short_id(p_server UUID) RETURNS BIGINT AS $$
DECLARE v BIGINT;
BEGIN
  INSERT INTO task_short_id_seq(server_id, next_id) VALUES (p_server, 1)
    ON CONFLICT (server_id) DO NOTHING;
  UPDATE task_short_id_seq SET next_id = next_id + 1 WHERE server_id = p_server
    RETURNING next_id - 1 INTO v;
  RETURN v;
END $$ LANGUAGE plpgsql;
```

### `task_reminders_outbox`

```sql
CREATE TABLE task_reminders_outbox (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  task_id       UUID NOT NULL REFERENCES tasks(id) ON DELETE CASCADE,
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  fire_at       TIMESTAMPTZ NOT NULL,
  kind          TEXT NOT NULL CHECK (kind IN ('due_soon','overdue')),
  fired_at      TIMESTAMPTZ,
  attempts      INT NOT NULL DEFAULT 0,
  UNIQUE (task_id, user_id, kind)
);

CREATE INDEX idx_task_reminders_due
  ON task_reminders_outbox(fire_at)
  WHERE fired_at IS NULL;
```

## 2. RLS Policies

```sql
ALTER TABLE tasks            ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_assignees   ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_comments    ENABLE ROW LEVEL SECURITY;
ALTER TABLE task_labels      ENABLE ROW LEVEL SECURITY;

CREATE POLICY tasks_member_read ON tasks FOR SELECT
  USING (server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid()));

CREATE POLICY tasks_member_write ON tasks FOR INSERT
  WITH CHECK (server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid()));

CREATE POLICY tasks_owner_or_mod_update ON tasks FOR UPDATE
  USING (
    creator_id = auth.uid()
    OR auth.uid() IN (SELECT user_id FROM task_assignees WHERE task_id = id)
    OR server_id IN (SELECT server_id FROM server_members
                     WHERE user_id = auth.uid() AND role IN ('owner','admin','mod'))
  );
```

## 3. Triggers

```sql
CREATE TRIGGER tasks_set_updated_at
  BEFORE UPDATE ON tasks
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Set completed_at when status flips to done.
CREATE OR REPLACE FUNCTION tasks_set_completed_at() RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'done' AND (OLD.status IS DISTINCT FROM 'done') THEN
    NEW.completed_at := now();
  ELSIF NEW.status <> 'done' THEN
    NEW.completed_at := NULL;
  END IF;
  RETURN NEW;
END $$ LANGUAGE plpgsql;

CREATE TRIGGER tasks_completed_at
  BEFORE UPDATE OF status ON tasks
  FOR EACH ROW EXECUTE FUNCTION tasks_set_completed_at();
```

## 4. Migration File

Path: `supabase/migrations/161_task_management.up.sql`
Down: `supabase/migrations/161_task_management.down.sql`

```sql
BEGIN;
-- create tables
-- create indexes
-- enable RLS
-- create policies
-- create triggers
-- grants
GRANT SELECT, INSERT, UPDATE, DELETE ON tasks            TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON task_assignees   TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON task_comments    TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON task_labels      TO authenticated;
GRANT SELECT, INSERT,         DELETE ON task_label_links TO authenticated;
GRANT SELECT                          ON task_history    TO authenticated;
COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `tasks:server:<sid>:list:<filterhash>` | JSON array | 30s |
| `tasks:user:<uid>:inbox` | JSON array | 60s |
| `tasks:detail:<id>` | JSON | 60s |
| `tasks:labels:<sid>` | JSON | 5m |

## 6. Search Index (Meilisearch)

```jsonc
{
  "uid": "tasks",
  "primaryKey": "id",
  "searchableAttributes": ["title", "description"],
  "filterableAttributes": ["server_id", "channel_id", "status", "priority", "due_at", "assignee_ids", "label_ids"],
  "sortableAttributes": ["due_at", "created_at", "priority"]
}
```

## 7. Object Storage (Appwrite)

- Bucket: `task-attachments`
- Allowed MIME: image/*, application/pdf, text/*
- Max size: 25 MB
- Permissions: `read("server:{server_id}")`, `write("user:{user_id}")`

## 8. Data Retention

- Active tasks: indefinite
- Soft-archived (`archived_at IS NOT NULL`): purged after 30 days
- History rows: kept indefinitely
- GDPR delete: cascade comments + history actor null'd; tasks themselves owned by server, not user

## 9. Sample Queries

```sql
-- My-tasks inbox: open tasks assigned to me across all my servers
SELECT t.*, ta.assigned_at
FROM tasks t
JOIN task_assignees ta ON ta.task_id = t.id
WHERE ta.user_id = $1
  AND t.status IN ('todo','in_progress','blocked')
  AND t.archived_at IS NULL
ORDER BY t.due_at NULLS LAST, t.priority DESC, t.created_at DESC
LIMIT 100;

-- Server list with filters
SELECT t.*
FROM tasks t
WHERE t.server_id = $1
  AND ($2::text IS NULL OR t.status = $2)
  AND ($3::uuid IS NULL OR t.channel_id = $3)
  AND t.archived_at IS NULL
ORDER BY t.created_at DESC
LIMIT 50;

-- Reminders due in next minute
SELECT id, task_id, user_id
FROM task_reminders_outbox
WHERE fired_at IS NULL AND fire_at <= now() + interval '60 seconds'
FOR UPDATE SKIP LOCKED
LIMIT 500;
```
