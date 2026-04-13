# Database Migrations
> *Last Updated: 2026-04-11 · Version: 1.0.0*

## Supabase Migrations (65 files)
Location: `supabase/migrations/`

Run migrations:
```bash
npx supabase db push
```

### Migration History
| # | File | Description |
|---|------|-------------|
| 001 | `001_create_profiles_table.sql` | User profiles |
| 002 | `002_create_servers_table.sql` | Servers |
| 003 | `003_create_server_members_table.sql` | Server members |
| 004 | `004_create_channels_table.sql` | Channels |
| 005 | `005_create_messages_table.sql` | Messages |
| 006-011 | Various | Reactions, friends, DMs, notifications, bans, roles |
| 013-016 | Various | RLS policies for profiles, servers, messages, DMs |
| 017-020 | Various | Triggers (auto profile, server init, timestamps, mentions) |
| 021-023 | Various | Storage buckets |
| 024-032 | Various | User mgmt, messaging, threads, voice, DMs, social, server mgmt, community, moderation |
| 033-036 | Various | Boosts, RLS, permissions, automation |
| 037-042 | Various | Enhanced messages/voice, categories, storage, polls, replies, offline queue |
| 043-064 | Various | Push tokens, profiles, read states, utilities, emojis, soundboard, bots |

## Backend Migrations (3 files)
Location: `backend/migrations/`

| # | File | Description |
|---|------|-------------|
| 001 | `001_initial_schema.up.sql` | Core tables (users, servers, channels, messages, roles, invites) |
| 002 | `002_bot_system_tables.sql` | All bot system tables (13+ tables) |
| 003 | `003_allow_system_messages_without_author.sql` | Allow NULL author_id |
