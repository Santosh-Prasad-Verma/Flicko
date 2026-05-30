# AI Meeting Notes — SCHEMA

```sql
CREATE TABLE meeting_notes (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  channel_id    UUID NOT NULL REFERENCES channels(id) ON DELETE CASCADE,
  voice_session_id UUID NOT NULL,
  started_at    TIMESTAMPTZ NOT NULL,
  ended_at      TIMESTAMPTZ NOT NULL,
  duration_sec  INT NOT NULL,
  participants  UUID[] NOT NULL,
  transcript_url TEXT,
  summary_md    TEXT,
  decisions     JSONB DEFAULT '[]',
  follow_ups    JSONB DEFAULT '[]',
  status        TEXT NOT NULL DEFAULT 'queued'
                  CHECK (status IN ('queued','transcribing','summarizing','published','failed')),
  message_id    UUID,
  language      TEXT,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now(),
  published_at  TIMESTAMPTZ
);
CREATE INDEX idx_mn_channel ON meeting_notes(channel_id, started_at DESC);
CREATE INDEX idx_mn_participant ON meeting_notes USING GIN(participants);

CREATE TABLE meeting_action_items (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  notes_id      UUID NOT NULL REFERENCES meeting_notes(id) ON DELETE CASCADE,
  text          TEXT NOT NULL,
  assignee_id   UUID REFERENCES users(id),
  due_at        TIMESTAMPTZ,
  task_id       UUID,
  done          BOOLEAN NOT NULL DEFAULT false,
  created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);
CREATE INDEX idx_mai_assignee ON meeting_action_items(assignee_id) WHERE NOT done;
```

## RLS
```sql
ALTER TABLE meeting_notes ENABLE ROW LEVEL SECURITY;
CREATE POLICY mn_read ON meeting_notes FOR SELECT
  USING (channel_id IN (SELECT channel_id FROM channel_members WHERE user_id=auth.uid()));
ALTER TABLE meeting_action_items ENABLE ROW LEVEL SECURITY;
CREATE POLICY mai_read ON meeting_action_items FOR SELECT
  USING (notes_id IN (SELECT id FROM meeting_notes));
CREATE POLICY mai_self_or_admin ON meeting_action_items FOR UPDATE
  USING (assignee_id = auth.uid()
      OR notes_id IN (SELECT id FROM meeting_notes WHERE channel_id IN
           (SELECT channel_id FROM channel_members WHERE user_id=auth.uid() AND has_perm('MANAGE_CHANNELS'))));
```

## Cache
| Key | Value | TTL |
|-----|-------|-----|
| `mn:summary:<id>` | rendered HTML | 5m |

## Migration: `supabase/migrations/138_ai_meeting_notes.up.sql`

## Retention
- Raw audio: deleted after summary published.
- Transcript + summary: 90 days default; admin override.
