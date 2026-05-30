# Calendar & Events — Backend Schema

## 1. Tables

### `events`

```sql
CREATE TABLE events (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  uid             TEXT UNIQUE NOT NULL,             -- ICS UID, stable
  server_id       UUID NOT NULL REFERENCES servers(id) ON DELETE CASCADE,
  channel_id      UUID REFERENCES channels(id) ON DELETE SET NULL,
  creator_id      UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  title           TEXT NOT NULL CHECK (length(title) BETWEEN 1 AND 140),
  description     TEXT CHECK (length(description) <= 4000),
  location        TEXT,
  starts_at       TIMESTAMPTZ NOT NULL,
  ends_at         TIMESTAMPTZ NOT NULL,
  tz              TEXT NOT NULL DEFAULT 'UTC',
  rrule           TEXT,                              -- iCal RRULE; null = single
  rdate           TIMESTAMPTZ[],                     -- explicit additions
  exdate          TIMESTAMPTZ[],                     -- exceptions
  capacity        INT CHECK (capacity > 0),
  cover_image_id  TEXT,
  state           TEXT NOT NULL DEFAULT 'scheduled' CHECK (state IN ('scheduled','cancelled','completed')),
  reminders       INT[] NOT NULL DEFAULT ARRAY[1440,60,10]::INT[],
  yes_count       INT NOT NULL DEFAULT 0,
  no_count        INT NOT NULL DEFAULT 0,
  maybe_count     INT NOT NULL DEFAULT 0,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at      TIMESTAMPTZ NOT NULL DEFAULT now(),
  cancelled_at    TIMESTAMPTZ,
  CONSTRAINT events_time_order CHECK (ends_at > starts_at)
);

CREATE INDEX idx_events_server_starts ON events(server_id, starts_at);
CREATE INDEX idx_events_channel       ON events(channel_id) WHERE channel_id IS NOT NULL;
CREATE INDEX idx_events_state         ON events(state);
```

### `event_occurrences`

```sql
-- Materialized expansion of recurring events for fast range queries.
CREATE TABLE event_occurrences (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id      UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  occ_starts_at TIMESTAMPTZ NOT NULL,
  occ_ends_at   TIMESTAMPTZ NOT NULL,
  is_exception  BOOLEAN NOT NULL DEFAULT false,
  UNIQUE (event_id, occ_starts_at)
);

CREATE INDEX idx_event_occ_starts ON event_occurrences(occ_starts_at);
CREATE INDEX idx_event_occ_event  ON event_occurrences(event_id);
```

### `event_rsvps`

```sql
CREATE TABLE event_rsvps (
  event_id    UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  occ_starts_at TIMESTAMPTZ NOT NULL,                -- supports per-occurrence RSVP
  user_id     UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  state       TEXT NOT NULL CHECK (state IN ('yes','no','maybe','waitlist')),
  note        TEXT CHECK (length(note) <= 280),
  reminder_overrides INT[],                          -- per-user offsets
  created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  updated_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
  PRIMARY KEY (event_id, occ_starts_at, user_id)
);

CREATE INDEX idx_event_rsvps_user ON event_rsvps(user_id);
```

### `event_reminders_outbox`

```sql
CREATE TABLE event_reminders_outbox (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  event_id      UUID NOT NULL REFERENCES events(id) ON DELETE CASCADE,
  user_id       UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
  occ_starts_at TIMESTAMPTZ NOT NULL,
  fire_at       TIMESTAMPTZ NOT NULL,
  offset_min    INT NOT NULL,
  fired_at      TIMESTAMPTZ,
  attempts      INT NOT NULL DEFAULT 0,
  last_error    TEXT,
  UNIQUE (event_id, user_id, occ_starts_at, offset_min)
);

CREATE INDEX idx_event_reminders_due
  ON event_reminders_outbox(fire_at)
  WHERE fired_at IS NULL;
```

## 2. RLS Policies

```sql
ALTER TABLE events             ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_occurrences  ENABLE ROW LEVEL SECURITY;
ALTER TABLE event_rsvps        ENABLE ROW LEVEL SECURITY;

CREATE POLICY events_member_read ON events FOR SELECT
  USING (server_id IN (SELECT server_id FROM server_members WHERE user_id = auth.uid()));

CREATE POLICY events_mod_write ON events FOR INSERT
  WITH CHECK (
    server_id IN (
      SELECT server_id FROM server_members
      WHERE user_id = auth.uid() AND role IN ('owner','admin','mod')
    )
  );

CREATE POLICY events_mod_update ON events FOR UPDATE
  USING (
    server_id IN (
      SELECT server_id FROM server_members
      WHERE user_id = auth.uid() AND role IN ('owner','admin','mod')
    )
    OR creator_id = auth.uid()
  );

CREATE POLICY rsvps_self_write ON event_rsvps FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());
```

## 3. Triggers

```sql
CREATE TRIGGER events_set_updated_at
  BEFORE UPDATE ON events
  FOR EACH ROW EXECUTE FUNCTION set_updated_at();

-- Maintain rsvp counter columns.
CREATE OR REPLACE FUNCTION recount_event_rsvps() RETURNS TRIGGER AS $$
BEGIN
  UPDATE events e SET
    yes_count   = (SELECT count(*) FROM event_rsvps r WHERE r.event_id=e.id AND r.state='yes'),
    no_count    = (SELECT count(*) FROM event_rsvps r WHERE r.event_id=e.id AND r.state='no'),
    maybe_count = (SELECT count(*) FROM event_rsvps r WHERE r.event_id=e.id AND r.state='maybe')
  WHERE e.id = COALESCE(NEW.event_id, OLD.event_id);
  RETURN NULL;
END $$ LANGUAGE plpgsql;

CREATE TRIGGER event_rsvps_counter
  AFTER INSERT OR UPDATE OR DELETE ON event_rsvps
  FOR EACH ROW EXECUTE FUNCTION recount_event_rsvps();
```

## 4. Migration File

Path: `supabase/migrations/160_calendar_events.up.sql`
Down: `supabase/migrations/160_calendar_events.down.sql`

```sql
-- up
BEGIN;
CREATE TABLE events (...);
CREATE TABLE event_occurrences (...);
CREATE TABLE event_rsvps (...);
CREATE TABLE event_reminders_outbox (...);
-- indexes, RLS, policies, triggers above
GRANT SELECT, INSERT, UPDATE, DELETE ON events             TO authenticated;
GRANT SELECT, INSERT, UPDATE, DELETE ON event_rsvps        TO authenticated;
GRANT SELECT                          ON event_occurrences TO authenticated;
COMMIT;
```

```sql
-- down
BEGIN;
DROP TABLE IF EXISTS event_reminders_outbox CASCADE;
DROP TABLE IF EXISTS event_rsvps           CASCADE;
DROP TABLE IF EXISTS event_occurrences     CASCADE;
DROP TABLE IF EXISTS events                CASCADE;
COMMIT;
```

## 5. Cache Keys (Redis)

| Key | Value | TTL |
|-----|-------|-----|
| `calendar:server:<server>:month:<yyyymm>` | event list JSON | 60s |
| `calendar:event:<id>` | event detail JSON | 30s |
| `calendar:event:<id>:rsvp:<user>` | rsvp state | 5m |
| `calendar:ics:<server>` | ICS body | 5m |

## 6. Search Index (Meilisearch)

```jsonc
{
  "uid": "events",
  "primaryKey": "id",
  "searchableAttributes": ["title", "description", "location"],
  "filterableAttributes": ["server_id", "channel_id", "state", "starts_at"],
  "sortableAttributes": ["starts_at"]
}
```

## 7. Object Storage (Appwrite)

- Bucket: `event-covers`
- Allowed MIME: `image/png`, `image/jpeg`, `image/webp`
- Max size: 2 MB, auto-resize 1200x630
- Permission: `read("any")`, `write("user:{creator_id}")`

## 8. Data Retention

- Active events kept indefinitely
- Cancelled events soft-purged after 90 days (`state='cancelled' AND cancelled_at < now()-interval '90 days'`)
- ICS UIDs preserved on update for client subscription stability
- GDPR delete: cascade RSVPs; events created by a deleted user reassigned to server bot account if `server.delete_orphan_events=false`

## 9. Sample Queries

```sql
-- Month view: occurrences inside a window for a server.
SELECT e.id, e.title, o.occ_starts_at, o.occ_ends_at, e.cover_image_id,
       e.yes_count, e.maybe_count
FROM event_occurrences o
JOIN events e ON e.id = o.event_id
WHERE e.server_id = $1
  AND e.state = 'scheduled'
  AND o.occ_starts_at >= $2
  AND o.occ_starts_at <  $3
ORDER BY o.occ_starts_at;

-- Reminders due in next 60s.
SELECT id, event_id, user_id
FROM event_reminders_outbox
WHERE fired_at IS NULL
  AND fire_at <= now() + interval '60 seconds'
FOR UPDATE SKIP LOCKED
LIMIT 500;
```
