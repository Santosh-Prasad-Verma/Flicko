# Forms & Surveys — Backend Schema

## 1. Tables

### `forms`

```sql
CREATE TABLE forms (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  server_id       UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  channel_id      UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  creator_id      UUID NOT NULL REFERENCES users(id) ON DELETE SET NULL,
  title           TEXT NOT NULL CHECK (length(title) BETWEEN 1 AND 140),
  description     TEXT CHECK (length(description) <= 1000),
  state           TEXT NOT NULL DEFAULT 'draft'
                   CHECK (state IN ('draft','open','closed','archived')),
  anonymous       BOOLEAN NOT NULL DEFAULT false,
  anon_salt       TEXT NOT NULL DEFAULT encode(gen_random_bytes(16),'hex'),
  limit_one_per_user BOOLEAN NOT NULL DEFAULT true,
  closes_at       TIMESTAMPTZ,
  channel_post_id UUID,                           -- the embedded card message
  revision        INT NOT NULL DEFAULT 1,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX idx_forms_server_state ON forms(server_id, state);
CREATE INDEX idx_forms_channel      ON forms(channel_id);
```

### `form_questions`

```sql
CREATE TABLE form_questions (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  form_id     UUID NOT NULL REFERENCES forms(id) ON DELETE CASCADE,
  position    INT NOT NULL,
  type        TEXT NOT NULL CHECK (type IN ('short_text','long_text','choice_single','choice_multi','scale','dropdown','date','file')),
  label       TEXT NOT NULL CHECK (length(label) BETWEEN 1 AND 200),
  options     JSONB NOT NULL DEFAULT '[]',
  required    BOOLEAN NOT NULL DEFAULT false,
  validation  JSONB NOT NULL DEFAULT '{}',         -- {min,max,regex}
  UNIQUE (form_id, position)
);

CREATE INDEX idx_form_questions_form ON form_questions(form_id, position);
```

### `form_responses`

```sql
CREATE TABLE form_responses (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  form_id     UUID NOT NULL REFERENCES forms(id) ON DELETE CASCADE,
  user_id     UUID REFERENCES users(id) ON DELETE SET NULL,
  user_hash   TEXT,                                -- if anonymous, hex SHA256(user_id || anon_salt)
  submitted_at TIMESTAMPTZ NOT NULL DEFAULT now(),
  client_meta  JSONB NOT NULL DEFAULT '{}'
);

CREATE INDEX idx_form_responses_form ON form_responses(form_id, submitted_at);
CREATE UNIQUE INDEX idx_form_responses_one_per_user
  ON form_responses(form_id, user_id) WHERE user_id IS NOT NULL;
CREATE UNIQUE INDEX idx_form_responses_one_per_anon
  ON form_responses(form_id, user_hash) WHERE user_hash IS NOT NULL;
```

### `form_response_answers`

```sql
CREATE TABLE form_response_answers (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  response_id UUID NOT NULL REFERENCES form_responses(id) ON DELETE CASCADE,
  question_id UUID NOT NULL REFERENCES form_questions(id) ON DELETE CASCADE,
  value       JSONB NOT NULL                        -- {text:"..."} or {choice:[...]} or {file:"..."}
);

CREATE INDEX idx_form_answers_response ON form_response_answers(response_id);
CREATE INDEX idx_form_answers_question ON form_response_answers(question_id);
```

## 2. RLS Policies

```sql
ALTER TABLE forms                  ENABLE ROW LEVEL SECURITY;
ALTER TABLE form_questions         ENABLE ROW LEVEL SECURITY;
ALTER TABLE form_responses         ENABLE ROW LEVEL SECURITY;
ALTER TABLE form_response_answers  ENABLE ROW LEVEL SECURITY;

CREATE POLICY forms_member_read ON forms FOR SELECT
  USING (state IN ('open','closed','archived')
         AND server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid()));

CREATE POLICY forms_creator_or_mod_write ON forms FOR ALL
  USING (creator_id = auth.uid()
         OR server_id IN (SELECT server_id FROM server_members
                          WHERE user_id = auth.uid() AND role IN ('owner','admin','mod')))
  WITH CHECK (server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid()));

CREATE POLICY responses_self_insert ON form_responses FOR INSERT
  WITH CHECK (user_id = auth.uid() OR user_id IS NULL);

CREATE POLICY responses_mod_read ON form_responses FOR SELECT
  USING (form_id IN (
    SELECT id FROM forms
    WHERE server_id IN (SELECT server_id FROM server_members
                        WHERE user_id = auth.uid() AND role IN ('owner','admin','mod'))));
```

## 3. Triggers

```sql
CREATE TRIGGER forms_set_updated_at
  BEFORE UPDATE ON forms
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Block edits to questions once state moves past draft.
CREATE OR REPLACE FUNCTION forms_questions_lock() RETURNS TRIGGER AS $$
DECLARE s TEXT;
BEGIN
  SELECT state INTO s FROM forms WHERE id = COALESCE(NEW.form_id, OLD.form_id);
  IF s <> 'draft' AND TG_OP IN ('INSERT','DELETE') THEN
    RAISE EXCEPTION 'forms_locked';
  END IF;
  RETURN COALESCE(NEW, OLD);
END $$ LANGUAGE plpgsql;

CREATE TRIGGER form_questions_lock_t
  BEFORE INSERT OR DELETE ON form_questions
  FOR EACH ROW EXECUTE FUNCTION forms_questions_lock();
```

## 4. Migration File

Path: `supabase/migrations/169_forms.up.sql`

```sql
BEGIN;
-- create tables, indexes, RLS, triggers
SELECT cron.schedule('forms_auto_close','0 * * * *',
  $$UPDATE forms SET state='closed' WHERE state='open' AND closes_at <= now();$$);
GRANT SELECT, INSERT, UPDATE         ON forms                  TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON form_questions         TO authenticated;
GRANT SELECT, INSERT                  ON form_responses        TO authenticated;
GRANT SELECT, INSERT                  ON form_response_answers TO authenticated;
COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `forms:agg:<form_id>` | aggregate JSON | 30s |
| `forms:meta:<form_id>` | meta+question schema | 60s |

## 6. Search Index

Not searched.

## 7. Object Storage

- Bucket: `form-attachments`
- MIME: image/*, application/pdf
- Max: 8 MB
- Permission: `read("server:{server_id}")`, `write("user:{user_id}")`

## 8. Data Retention

- Active: indefinite
- Archived: 365d
- GDPR: cascade with user delete; anon hashes survive (no PII bound)

## 9. Sample Queries

```sql
-- Aggregate single-choice
SELECT (value->>'choice')::text AS option, count(*) AS n
FROM form_response_answers
WHERE question_id = $1
GROUP BY option;

-- Stream CSV
SELECT r.id, r.user_id, q.label, a.value
FROM form_responses r
JOIN form_response_answers a ON a.response_id = r.id
JOIN form_questions q ON q.id = a.question_id
WHERE r.form_id = $1
ORDER BY r.submitted_at;
```
