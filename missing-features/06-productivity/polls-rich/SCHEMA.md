# Rich Polls — Backend Schema

## 1. Tables

### `polls_v2`

```sql
CREATE TABLE polls_v2 (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id       UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  channel_id      UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  creator_id      UUID NOT NULL REFERENCES users(id) ON DELETE SET NULL,
  title           TEXT NOT NULL CHECK (length(title) BETWEEN 1 AND 200),
  anonymous       BOOLEAN NOT NULL DEFAULT false,
  anon_salt       TEXT NOT NULL DEFAULT encode(gen_random_bytes(16),'hex'),
  show_results    TEXT NOT NULL DEFAULT 'live' CHECK (show_results IN ('live','on_close')),
  closes_at       TIMESTAMPTZ,
  closed_at       TIMESTAMPTZ,
  state           TEXT NOT NULL DEFAULT 'open' CHECK (state IN ('open','closed','archived')),
  min_account_age_hours INT NOT NULL DEFAULT 24,
  channel_post_id UUID,
  revision        INT NOT NULL DEFAULT 1,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_polls_v2_server_state ON polls_v2(server_id, state);
CREATE INDEX idx_polls_v2_channel      ON polls_v2(channel_id);
CREATE INDEX idx_polls_v2_closes       ON polls_v2(closes_at) WHERE state='open';
```

### `poll_questions`

```sql
CREATE TABLE poll_questions (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  poll_id     UUID NOT NULL REFERENCES polls_v2(id) ON DELETE CASCADE,
  position    INT NOT NULL,
  type        TEXT NOT NULL CHECK (type IN ('single','multi','ranked','scale')),
  label       TEXT NOT NULL CHECK (length(label) BETWEEN 1 AND 200),
  options     JSONB NOT NULL DEFAULT '[]',
  scale_min   INT,
  scale_max   INT,
  required    BOOLEAN NOT NULL DEFAULT false,
  UNIQUE (poll_id, position)
);

CREATE INDEX idx_poll_questions_poll ON poll_questions(poll_id, position);
```

### `poll_votes`

```sql
CREATE TABLE poll_votes (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  poll_id     UUID NOT NULL REFERENCES polls_v2(id) ON DELETE CASCADE,
  user_id     UUID REFERENCES users(id) ON DELETE SET NULL,
  user_hash   TEXT,                                  -- when anonymous
  submitted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  client_meta  JSONB NOT NULL DEFAULT '{}'
);

CREATE UNIQUE INDEX idx_poll_votes_one_per_user
  ON poll_votes(poll_id, user_id) WHERE user_id IS NOT NULL;
CREATE UNIQUE INDEX idx_poll_votes_one_per_anon
  ON poll_votes(poll_id, user_hash) WHERE user_hash IS NOT NULL;
```

### `poll_vote_answers`

```sql
CREATE TABLE poll_vote_answers (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  vote_id     UUID NOT NULL REFERENCES poll_votes(id) ON DELETE CASCADE,
  question_id UUID NOT NULL REFERENCES poll_questions(id) ON DELETE CASCADE,
  value       JSONB NOT NULL                          -- {choice}|{choices:[]}|{ranking:[]}|{scale:N}
);

CREATE INDEX idx_poll_answers_vote     ON poll_vote_answers(vote_id);
CREATE INDEX idx_poll_answers_question ON poll_vote_answers(question_id);
```

## 2. RLS Policies

```sql
ALTER TABLE polls_v2          ENABLE ROW LEVEL SECURITY;
ALTER TABLE poll_questions    ENABLE ROW LEVEL SECURITY;
ALTER TABLE poll_votes        ENABLE ROW LEVEL SECURITY;
ALTER TABLE poll_vote_answers ENABLE ROW LEVEL SECURITY;

CREATE POLICY polls_v2_member_read ON polls_v2 FOR SELECT
  USING (server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid()));

CREATE POLICY polls_v2_member_write ON polls_v2 FOR INSERT
  WITH CHECK (server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid()));

CREATE POLICY poll_votes_self_insert ON poll_votes FOR INSERT
  WITH CHECK (user_id = auth.uid() OR user_id IS NULL);

CREATE POLICY poll_votes_admin_read ON poll_votes FOR SELECT
  USING (poll_id IN (
    SELECT id FROM polls_v2
    WHERE server_id IN (SELECT server_id FROM server_members
                        WHERE user_id = auth.uid() AND role IN ('owner','admin','mod'))));
```

## 3. Triggers

```sql
CREATE TRIGGER polls_v2_set_updated_at
  BEFORE UPDATE ON polls_v2
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Lock questions edits once a vote exists.
CREATE OR REPLACE FUNCTION poll_questions_lock() RETURNS TRIGGER AS $$
DECLARE n INT;
BEGIN
  SELECT count(*) INTO n FROM poll_votes WHERE poll_id = COALESCE(NEW.poll_id, OLD.poll_id);
  IF n > 0 THEN RAISE EXCEPTION 'polls_locked'; END IF;
  RETURN COALESCE(NEW, OLD);
END $$ LANGUAGE plpgsql;

CREATE TRIGGER poll_questions_lock_t
  BEFORE INSERT OR UPDATE OR DELETE ON poll_questions
  FOR EACH ROW EXECUTE FUNCTION poll_questions_lock();
```

## 4. Migration File

Path: `supabase/migrations/171_polls_v2.up.sql`

```sql
BEGIN;
-- create tables, indexes, RLS, triggers
SELECT cron.schedule('polls_v2_auto_close','*/1 * * * *',
  $$UPDATE polls_v2 SET state='closed', closed_at=now()
    WHERE state='open' AND closes_at <= now();$$);

-- Migrate v1 polls into v2 read-shim view if old table exists.
GRANT SELECT, INSERT, UPDATE         ON polls_v2          TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON poll_questions    TO authenticated;
GRANT SELECT, INSERT                  ON poll_votes        TO authenticated;
GRANT SELECT, INSERT                  ON poll_vote_answers TO authenticated;
COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `pollsv2:agg:<id>` | aggregates + IRV rounds JSON | 5s |
| `pollsv2:meta:<id>` | meta+questions JSON | 60s |

## 6. Search Index

Not searched.

## 7. Object Storage

None.

## 8. Data Retention

- Active: indefinite
- Closed: 365 days
- GDPR: cascade with user; anon hashes survive

## 9. Sample Queries

```sql
-- Single-choice aggregate
SELECT (value->>'choice')::text AS option, count(*) AS n
FROM poll_vote_answers
WHERE question_id = $1
GROUP BY option;

-- Ranked-choice raw rankings (for IRV in app)
SELECT a.value->'ranking' AS ranking
FROM poll_vote_answers a
WHERE a.question_id = $1;

-- Auto-close pull
SELECT id FROM polls_v2
WHERE state='open' AND closes_at <= now()
LIMIT 200;
```
