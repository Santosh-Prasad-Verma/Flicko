# Database Models
> *Last Updated: 2026-04-11 · Version: 1.0.0*

## Go Models (`backend/internal/models/`)
22 model files defining Go structs:

| Model File | Table(s) | Key Fields |
|-----------|----------|------------|
| `user.go` | users | ID, Username, Email, AvatarURL |
| `server.go` | servers | ID, Name, OwnerID |
| `channel.go` | channels | ID, ServerID, Type, Name |
| `message.go` | messages | ID, ChannelID, AuthorID, Content |
| `role.go` | roles | ID, ServerID, Permissions (bitfield) |
| `member.go` | members (implied) | ID, ServerID, UserID |
| `invite.go` | invites | Code, ServerID, MaxUses |
| `dm.go` | DM conversations | ID, ParticipantIDs |
| `reaction.go` | reactions | Emoji, Count, Users |
| `attachment.go` | attachments | ID, Filename, URL, Size |
| `moderation.go` | mod actions | Warnings, bans, mutes |
| `voice.go` | voice_states | UserID, ChannelID, SelfMute |
| `thread.go` | threads | ID, ParentChannelID, Name |
| `boost.go` | server boosts | ServerID, TierLevel |
| `sticker.go` | stickers | ID, Name, URL |
| `community.go` | community events | ID, Title, StartTime |
| `audit.go` | audit log entries | Action, ActorID |
| `drawing.go` | collaborative drawing | ChannelID, Data |
| `social.go` | friend relationships | UserID, FriendID, Status |
| `session.go` | user sessions | Token, IPAddress |
| `user_settings.go` | user preferences | Theme, Notifications |
| `connected_account.go` | OAuth connections | Provider, ExternalID |
| `activity.go` | user activity | Type, Content, Timestamp |

## TypeScript Models (`shared/types/models.ts`)
Key interfaces: User, Server, Channel, Message, Member, Presence, Invite, Poll, Thread, VoiceState, DirectMessage, Friend, ActivityItem.
