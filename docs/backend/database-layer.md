# Database Layer

> **Reading time:** ~8 minutes · **Audience:** Backend Developers · **Last Updated:** 2026-04-11

Flicko relies entirely on PostgreSQL. To achieve maximum performance, we do not use heavy ORMs like GORM. Instead, we write raw SQL queries relying on `pgx`, and enforce migrations deterministically.

---

## PGX & Connection Pooling

We use `github.com/jackc/pgx/v5`, which is significantly faster and more type-safe than the standard library `database/sql`.

**The Supavisor Layer:**
Because `pgxpool` maintains active persistent connections, and Flicko runs 3 isolated Go microservices, database connections scale quickly.
We configure `DATABASE_URL` to point to Supabase's internal IPv4 connection pooler (`port 6543`), NOT the direct connection (`port 5432`). 

This allows `pgxpool` to open hundreds of virtual connections in Go, which Supavisor multiplexes down to ~15 highly efficient physical connections to the true PostgreSQL engine.

---

## Query Mapping Pattern

Without an ORM, we heavily utilize `pgx` scanning.

```go
func (r *UserRepository) FindByID(ctx context.Context, id uuid.UUID) (*models.User, error) {
    query := `
        SELECT id, username, display_name, avatar_url, is_premium, created_at 
        FROM public.users WHERE id = $1 AND deleted_at IS NULL
    `
    
    var user models.User
    
    err := r.db.QueryRow(ctx, query, id).Scan(
        &user.ID,
        &user.Username,
        &user.DisplayName,
        &user.AvatarURL,
        &user.IsPremium,
        &user.CreatedAt,
    )
    
    if err != nil {
        if errors.Is(err, pgx.ErrNoRows) {
            return nil, apperrors.ErrNotFound
        }
        return nil, err
    }
    
    return &user, nil
}
```

### JSON Aggregation for Joins
Fetching nested data (like a Channel containing an array of Overwrites) without issuing N+1 queries requires clever SQL. We use Postgres `json_agg` natively instead of writing manual iteration loops in Go.

```sql
SELECT 
    c.*,
    COALESCE(
        json_agg(po.*) FILTER (WHERE po.id IS NOT NULL), 
        '[]'
    ) as overwrites
FROM channels c
LEFT JOIN permission_overwrites po ON po.channel_id = c.id
WHERE c.server_id = $1
GROUP BY c.id;
```
This query returns perfectly structured JSON straight from the database, which is instantly unmarshaled into `[]models.Overwrite` in the Go application logic.

---

## Migrations

All database schema changes MUST be represented as an irreversible `.sql` migration file located in `/supabase/migrations/`. 

Never modify tables manually via the Supabase Dashboard UI. 

**Migration Format:** `YYYYMMDDHHMMSS_name.sql`
Example: `20260410000000_init_schema.sql`

We rely strictly on the `supabase-cli` to apply these. Running `supabase db push` compares your local SQL files to the production migration tracker table and applies deltas.

---

## Row-Level Security (RLS)

Although Supabase is famous for Client-Side RLS (allowing Flutter to query the DB directly), Flicko **DOES NOT** use this paradigm.

All SQL queries flow through the Go backend (which uses service tier connection strings). The Go backend enforces authorization mathematically using the 26-bit RBAC system within Go application space. This provides absolute programmatic flexibility that RLS struggles to match cleanly (e.g. merging channel-deny overrides against server-allow bitfields).

As a safeguard against accidental developer leakage, our SQL migrations do enable `ENABLE ROW LEVEL SECURITY` on tables but explicitly lack overlapping policies for unauthenticated access. 
