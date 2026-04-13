# Database Overview
> *Last Updated: 2026-04-11 · Version: 1.0.0*

## Database Choice: PostgreSQL (via Supabase)
**Why PostgreSQL:**
- ACID compliance for financial transactions (Flicko Plus)
- Rich constraint system (CHECK, FK, UNIQUE) for data integrity
- Row-Level Security (RLS) for per-user access control
- JSONB support for flexible schema (bot permissions, attachments)
- Full-text search for message search
- Excellent Go driver support (pgx/v5)

**Why Supabase hosting:**
- Managed PostgreSQL with automatic backups
- Built-in Auth with JWT
- Realtime change data capture
- Connection pooling via Supavisor (port 6543)
- Edge Functions for serverless compute
- Free tier sufficient for development

## Schema Highlights
- **65 Supabase migrations** (`supabase/migrations/`)
- **3 backend migrations** (`backend/migrations/`)
- Core tables: users, servers, channels, messages, members, roles
- Bot tables: mod_settings, automod_settings, welcome_settings, etc.
- Social tables: friends, DMs, notifications, activity
- Voice tables: voice_states, streams, dm_calls

## Related Docs
- [Schema](schema.md) — Complete column-level docs
- [Migrations](migrations.md) — How to run migrations
- [Database ERD](../diagrams/database-erd.md)
