# Database Migrations

> **Reading time:** ~8 minutes · **Audience:** Backend Developers · **Last Updated:** 2026-04-15

Because Flicko's architecture runs on PostgreSQL, changes to the database (adding columns, creating trigger functions) cannot be applied manually via a UI like pgAdmin. 
They must be scripted explicitly so that staging and production environments can reproduce them via CLI.

---

## The Migration Paradigm

We utilize the **Supabase CLI** for managing PostgreSQL version control.
All migrations are stored sequentially in `supabase/migrations/`.

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

When the PR is merged into `main`, CI compares against `supabase_migrations.schema_migrations`, detects the new version, and executes it once in order.

---

## Migration Safety Pack (X4)

Every new migration must satisfy both **idempotency** and **recovery readiness**.

### Idempotent SQL checklist

- Use `CREATE TABLE IF NOT EXISTS` for new tables.
- Use `CREATE INDEX IF NOT EXISTS` for new indexes.
- Use `DROP TRIGGER IF EXISTS` before recreating triggers.
- Use `DROP POLICY IF EXISTS` before recreating RLS policies.
- Enable RLS explicitly and define all CRUD policies in the same migration for public schema tables.
- Seed rows with `INSERT ... ON CONFLICT DO NOTHING` when applicable.

### Rollback runbook (forward-fix model)

Supabase migrations are forward-only, so rollbacks are performed through a corrective migration:

1. **Stop rollout** and identify the bad migration version.
2. **Generate a new fix migration**:
   ```bash
   npx supabase migration new fix_<issue_name>
   ```
3. Add corrective SQL (`ALTER`, compensating inserts/updates/deletes, policy adjustments).
4. Validate locally:
   ```bash
   npx supabase db reset
   npx supabase start
   ```
5. Run repository validation before merge:
   ```bash
   cd services && make vet && make test && make build
   cd ../backend && go test ./...
   ```
6. Merge and deploy the fix migration.

### Emergency migration state repair

Only when a migration state mismatch exists and after confirming data safety:

```bash
npx supabase migration repair --status reverted <VERSION>
```

Then ship a new corrective migration immediately.

---

## ⚠️ Warning: Rollbacks

Supabase CLI migrations are explicitly **forward-only**.
Do not edit already-applied migrations; always create a new corrective migration.
