# Database Indexes
> *Last Updated: 2026-04-11 · Version: 1.0.0*

## Performance Indexes

| Index | Table | Columns | Purpose |
|-------|-------|---------|---------|
| `idx_users_username` | users | username | Username lookup |
| `idx_users_email` | users | email | Email lookup |
| `idx_channels_server_id` | channels | server_id | Channels per server |
| `idx_messages_channel_id_created_at` | messages | (channel_id, created_at DESC) | Message history pagination |
| `idx_messages_author_id` | messages | author_id | Messages by user |
| `idx_invites_server_id` | invites | server_id | Invites per server |
| `idx_temp_punishments_expiry` | temp_punishments | expires_at WHERE active=true | Auto-expiry check |
| `idx_user_xp_leaderboard` | user_xp | (server_id, xp DESC) | Leaderboard queries |
| `idx_tickets_server` | tickets | (server_id, status) | Ticket listing |
| `idx_tickets_creator` | tickets | creator_id | User's tickets |
| `idx_starboard_entries_stars` | starboard_entries | (server_id, star_count DESC) | Top starred messages |

## Unique Constraints
| Table | Columns | Purpose |
|-------|---------|---------|
| users | username | Unique usernames |
| users | email | Unique emails |
| members | (server_id, user_id) | One membership per user per server |
| user_xp | (user_id, server_id) | One XP record per user per server |
| starboard_entries | (server_id, original_message_id) | One starboard entry per message |
| starboard_stars | (entry_id, user_id) | One star per user per entry |
