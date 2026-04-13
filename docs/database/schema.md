# Database Schema
> *Last Updated: 2026-04-11 · Version: 1.0.0*

## Core Tables

### users
| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| id | UUID | No | gen_random_uuid() | Primary key |
| username | VARCHAR(32) | No | — | Unique, min 2 chars |
| email | VARCHAR(255) | No | — | Unique email |
| password_hash | VARCHAR(255) | No | — | bcrypt hash |
| avatar_url | TEXT | Yes | NULL | Profile avatar URL |
| banner_url | TEXT | Yes | NULL | Profile banner URL |
| theme | VARCHAR(50) | Yes | 'dark' | UI theme preference |
| created_at | TIMESTAMPTZ | No | CURRENT_TIMESTAMP | — |
| updated_at | TIMESTAMPTZ | No | CURRENT_TIMESTAMP | — |

### servers
| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| id | UUID | No | gen_random_uuid() | Primary key |
| name | VARCHAR(100) | No | — | Min 2 chars |
| description | TEXT | Yes | NULL | Server description |
| owner_id | UUID FK→users | No | — | ON DELETE RESTRICT |
| icon_url | TEXT | Yes | NULL | Server icon |
| banner_url | TEXT | Yes | NULL | Server banner |
| created_at | TIMESTAMPTZ | No | CURRENT_TIMESTAMP | — |
| updated_at | TIMESTAMPTZ | No | CURRENT_TIMESTAMP | — |

### channels
| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| id | UUID | No | gen_random_uuid() | Primary key |
| server_id | UUID FK→servers | Yes | — | ON DELETE CASCADE |
| type | VARCHAR(20) | No | — | text, voice, category, dm |
| name | VARCHAR(100) | No | — | Min 1 char |
| topic | TEXT | Yes | NULL | Channel topic |
| position | INTEGER | No | 0 | Sort order |
| parent_id | UUID FK→channels | Yes | NULL | Category parent |
| created_at | TIMESTAMPTZ | No | CURRENT_TIMESTAMP | — |
| updated_at | TIMESTAMPTZ | No | CURRENT_TIMESTAMP | — |

### messages
| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| id | UUID | No | gen_random_uuid() | Primary key |
| channel_id | UUID FK→channels | No | — | ON DELETE CASCADE |
| author_id | UUID FK→users | Yes | — | NULL for system/bot msgs |
| content | TEXT | No | — | 1-4000 chars |
| edited_at | TIMESTAMPTZ | Yes | NULL | Last edit timestamp |
| deleted_at | TIMESTAMPTZ | Yes | NULL | Soft delete timestamp |
| created_at | TIMESTAMPTZ | No | CURRENT_TIMESTAMP | — |
| updated_at | TIMESTAMPTZ | No | CURRENT_TIMESTAMP | — |

### members
| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| id | UUID | No | gen_random_uuid() | Primary key |
| server_id | UUID FK→servers | No | — | ON DELETE CASCADE |
| user_id | UUID FK→users | No | — | ON DELETE CASCADE |
| nickname | VARCHAR(64) | Yes | NULL | Server-specific nickname |
| joined_at | TIMESTAMPTZ | No | CURRENT_TIMESTAMP | — |

### roles
| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| id | UUID | No | gen_random_uuid() | Primary key |
| server_id | UUID FK→servers | No | — | ON DELETE CASCADE |
| name | VARCHAR(100) | No | — | Role name |
| color | VARCHAR(20) | Yes | NULL | Hex color |
| position | INTEGER | No | 0 | Hierarchy position |
| permissions | BIGINT | No | 0 | Bitfield permissions |

### invites
| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| code | VARCHAR(32) | No | — | Primary key |
| server_id | UUID FK→servers | No | — | ON DELETE CASCADE |
| channel_id | UUID FK→channels | No | — | Target channel |
| inviter_id | UUID FK→users | No | — | Who created it |
| max_uses | INTEGER | No | 0 | 0 = unlimited |
| uses | INTEGER | No | 0 | Current use count |
| expires_at | TIMESTAMPTZ | Yes | NULL | Expiry time |

### dm_calls
| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| id | UUID | No | gen_random_uuid() | Primary key |
| conversation_id | UUID FK→dm_conversations | No | — | Target conversation |
| caller_id | UUID FK→users | No | — | Who started the call |
| status | VARCHAR(20) | No | 'ringing' | ringing, accepted, declined, ended |
| has_video | BOOLEAN | No | false | Whether video is enabled |
| created_at | TIMESTAMPTZ | No | CURRENT_TIMESTAMP | — |

### server_emojis
| Column | Type | Nullable | Default | Description |
|--------|------|----------|---------|-------------|
| id | UUID | No | gen_random_uuid() | Primary key |
| server_id | UUID FK→servers | No | — | Parent server |
| name | VARCHAR(32) | No | — | Emoji shortcode |
| url | TEXT | No | — | Media URL |
| animated | BOOLEAN | No | false | GIF status |
| creator_id | UUID FK→users | No | — | Uploader |

## Bot System Tables
- `bots`, `bot_guilds`, `mod_settings`, `temp_punishments`
- `automod_settings`, `welcome_settings`
- `level_settings`, `user_xp`, `level_role_rewards`, `xp_multipliers`
- `ticket_settings`, `ticket_panels`, `tickets`, `ticket_feedback`
- `starboard_settings`, `starboard_entries`, `starboard_stars`

See [Migrations](migrations.md) for the full SQL.
