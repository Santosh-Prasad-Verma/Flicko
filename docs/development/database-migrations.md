# Database Migrations

> **Reading time:** ~5 minutes · **Audience:** Backend Developers · **Last Updated:** 2026-04-11

Because Flicko's architecture runs on PostgreSQL, changes to the database (adding columns, creating trigger functions) cannot be applied manually via a UI like pgAdmin. 
They must be scripted explicitly so that staging and production environments can reproduce them via CLI.

---

## The Migration Paradigm

We utilize the **Supabase CLI** for managing PostgreSQL version control.
All migrations are stored sequentially in `backend/supabase/migrations/`.

Example structure:
```text
20231015120000_initial_schema.sql
20231016143000_add_user_bio.sql
20231020091500_create_message_reactions_table.sql
```

The leading timestamp integer guarantees execution order.

---

## Workflow: Modifying the DB

### 1. Generate an empty migration file
```bash
npx supabase migration new add_read_receipts
```
This will create a new empty `.sql` file in the folder, timestamped to the current second.

### 2. Write the raw SQL
Open the newly generated generated file and write the DDL.
You MUST write standard Postgres SQL. Do not use an ORM abstractor.

```sql
-- 202311xx_add_read_receipts.sql

CREATE TABLE public.read_states (
    id UUID PRIMARY KEY DEFAULT uuid_generate_v4(),
    user_id UUID NOT NULL REFERENCES public.users(id) ON DELETE CASCADE,
    channel_id UUID NOT NULL REFERENCES public.channels(id) ON DELETE CASCADE,
    last_read_message_id UUID NOT NULL,
    updated_at TIMESTAMP WITH TIME ZONE DEFAULT NOW()
);

-- Optimize queries searching for a user's unread badges
CREATE INDEX idx_read_states_user_channel ON public.read_states(user_id, channel_id);
```

### 3. Test locally
Apply it to your local Docker test-database:
```bash
npx supabase db reset   # Optional: wipes the DB clean
npx supabase start      # Executes all migrations including your new one
```

Validate your Go Unit Tests/Integration Tests against the new schema.

### 4. Push to CI (Production)
Commit the `.sql` file to Git and open a Pull Request.

When the PR is merged into `main`, the GitHub Actions CI pipeline connects to the Production Supabase instance via its connection string. It checks the `supabase_migrations.schema_migrations` tracking table to see which timetamp it executed last. It will detect your new file, and automatically `EXECUTE` it against production, locking it into the history forever.

---

## ⚠️ Warning: Rollbacks

Supabase CLI migrations are explicitly **forward-only**. 
There are no "down" migrations. 
If you accidentally push a migration to production that contains a typo, you **CANNOT** simply edit the previous SQL file. CI will ignore it, as it already recorded the timestamp as "completed".

You must generate a brand *new* migration (e.g. `npx supabase migration new fix_typo`) containing an `ALTER TABLE` to fix the mistake.
