# Flicko - Product Overview

## Purpose
Flicko is a complete, production-ready, open-source Discord alternative built for self-hosting. It's a full-featured communication platform delivering real-time messaging, voice/video channels, bot framework, and server management on a single 8 GB VPS.

## Value Proposition
- **Self-Hostable**: Deploy on a single VPS (8 GB RAM) serving 3,000-5,000 concurrent users
- **Production-Grade**: 94 database migrations, 95 backend service files, 86 mobile screens, 121 documentation files
- **Open Source**: MIT License with complete transparency and extensibility
- **Enterprise Features**: 8 built-in bots, 26 permission types, full observability stack (Prometheus + Grafana + Loki)
- **Cost-Effective**: ~€8.50/month hosting vs proprietary alternatives

## Key Features

### Communication (11 Features)
- Real-time messaging via WebSocket with Redis Pub/Sub fan-out
- Message editing, deletion with soft-delete and edit history
- Threads, replies with parent message references
- Typing indicators (debounced, 8s timeout)
- Read receipts (per-user per-channel tracking)
- Reactions & emoji (Unicode + custom, per-message counts)
- Message pinning with MANAGE_MESSAGES permission
- Full-text search using PostgreSQL tsvector
- GIF search via GIPHY API integration
- Multi-option polls with real-time vote updates
- Code blocks with syntax highlighting

### Voice & Video (6 Features)
- Voice channels via LiveKit WebRTC SFU with Opus codec
- Video chat with adaptive bitrate
- Screen sharing (desktop/app)
- Push-to-talk with client-side audio gating
- Voice activity detection with speaking indicators
- 1-on-1 DM voice/video calls

### Server Management (10 Features)
- Server CRUD (create, edit, delete, transfer ownership)
- Invite system (unique codes, max uses, expiry, vanity URLs)
- Channel categories with nested channels and drag-to-reorder
- Role management (26 permission types, bitfield calculations)
- Channel permission overwrites (per-role and per-user)
- Server templates (Gaming, Study Group, Community presets)
- Server boosting with tier-based enhanced features
- Custom emoji & stickers (upload and use per-server)
- Audit log (all admin actions with timestamps)
- Server discovery (browse and search public servers)

### Bot System (8 Built-In Bots)
1. **Moderation Bot**: `/ban`, `/kick`, `/mute`, `/warn`, `/purge` - Manual moderation with escalating warnings
2. **AutoMod Bot**: 8 content filters (invites, links, caps, spam, emoji, mentions, blacklist, duplicates)
3. **Welcome Bot**: Custom join/leave messages, auto-role assignment
4. **Leveling Bot**: `/rank`, `/leaderboard` - XP per message, level-up announcements, role rewards
5. **Music Bot**: `/play`, `/skip`, `/queue`, `/np` - Music playback in voice channels
6. **Ticket Bot**: `/ticket` - Support ticket creation with categories
7. **Poll Bot**: `/poll` - In-channel polls with multi-option voting
8. **Starboard Bot**: Star reaction tracking, hall-of-fame channel

### Social & Profiles (8 Features)
- Friend requests (send, accept, decline, block lifecycle)
- Direct messages (1-on-1 with reactions and typing)
- Group DMs (up to 10 participants)
- Online presence (Online, Idle, DnD, Offline with WebSocket tracking)
- User profiles (avatar, banner, bio, badges, status)
- Activity feed (mentions, friend requests, server events)
- Push notifications via Supabase Edge Functions
- Multi-account support

### Premium & Media (7 Features)
- Flicko Plus subscription via Stripe payment integration
- Image uploads via Appwrite Storage (secure buckets)
- Video uploads via Appwrite Storage (high-speed chunks)
- Avatar & banner via Appwrite Storage (profile bucket)
- File attachments with progress tracking
- Direct WebRTC upload to Appwrite (client-side SDK)
- Animated avatars (premium-only GIF support)

## Target Users

### Primary Users
- **Self-Hosting Enthusiasts**: Developers and sysadmins wanting full control over their communication infrastructure
- **Privacy-Conscious Communities**: Organizations requiring data sovereignty and GDPR compliance
- **Gaming Communities**: Clans, guilds, and esports teams needing voice/video with low latency
- **Educational Institutions**: Schools and universities requiring self-hosted collaboration platforms
- **Open Source Projects**: Development teams needing transparent, auditable communication tools

### Use Cases
1. **Private Gaming Communities**: Replace Discord with self-hosted alternative for clan/guild communication
2. **Corporate Internal Communication**: Deploy on-premises for sensitive business communications
3. **Educational Collaboration**: University departments hosting student project coordination
4. **Open Source Development**: Transparent communication platform for distributed teams
5. **Regional Communities**: Local language support with full data residency control

## Competitive Advantages

| Feature | Flicko | Discord | Revolt | Guilded |
|---------|--------|---------|--------|---------|
| Open Source | ✅ MIT | ❌ | ✅ AGPL | ❌ |
| Self-Hostable | ✅ Single VPS | ❌ | ✅ Complex | ❌ |
| Mobile App | ✅ Flutter | ✅ | ❌ Web only | ✅ |
| Bot Framework | ✅ 8 built-in | ❌ 3rd party | ❌ | ❌ |
| Voice/Video | ✅ LiveKit | ✅ | ❌ | ✅ |
| Single VPS Deploy | ✅ 8 GB | N/A | ⚠️ 16+ GB | N/A |
| Secrets Management | ✅ Doppler | ❌ | ❌ | ❌ |

## Technical Highlights
- **Scalability**: 3,000-5,000 concurrent users on 8 GB VPS
- **Architecture**: Microservices with 3 Go services, Flutter mobile client
- **Security**: 5-layer defense-in-depth (Cloudflare → NGINX → App → DB → Docker)
- **Observability**: Full Prometheus + Grafana + Loki monitoring stack
- **Database**: 94 SQL migrations with Row-Level Security policies
- **Deployment**: Docker Compose with 9 containers across 3 isolated networks
