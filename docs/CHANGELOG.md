# Changelog

All notable changes to the Flicko project are documented in this file. The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/), and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

Each version section documents features added, changes made, deprecations, removals, bug fixes, and security patches. Database migration numbers are referenced where applicable so you can trace schema changes to specific versions. The migration files themselves live in `supabase/migrations/` (65 files) and `backend/migrations/` (3 files).

---

## [1.0.0] — 2026-04-11

This is the initial public release of Flicko, representing over 12 months of development. The platform includes a complete Discord-like experience with real-time messaging, voice and video channels, a bot framework, server management, and a premium subscription tier. The backend consists of three Go microservices, the frontend is a Flutter mobile app targeting iOS and Android, and the infrastructure is designed for self-hosted deployment on a single VPS.

### Added

#### Core Platform
- **3 Go microservices** — `ws-gateway` (WebSocket connections and real-time delivery), `msg-service` (REST API with batch message insertion), and `backend` (bot framework with slash command routing). Each service has an independent entry point, Dockerfile, and health check endpoint. The services communicate through shared PostgreSQL (via Supabase) and Redis (via Upstash) instances. The `ws-gateway` supports up to 6,000 concurrent WebSocket connections within its 1 GB memory limit. The `msg-service` includes a batch insertion engine that groups messages into batches of 50, flushing every 50 milliseconds to reduce database round-trips. The `backend` service runs an in-process event bus that routes events to 8 registered bot handlers.

- **Flutter mobile app** — Cross-platform iOS and Android application built with Flutter SDK 54 and TypeScript 5.9. The app uses file-based routing via Flutter Router with 30+ screens organized into route groups: `(auth)` for login/register, `(tabs)` for the main tab bar (home, friends, DMs, notifications, profile), and dedicated groups for server detail, DM conversations, settings, voice channels, user profiles, search, and the Flicko Plus subscription screen. The design system uses GG Sans typography (Discord's font) with dark, light, and AMOLED theme support.

- **22 Riverpod state stores** — Lightweight global state management covering authentication (`authStore`), server management (`serverManagementStore` at 10 KB), messages (`messageStore`), voice state (`voiceStore`), presence (`presenceStore`), notifications (`notificationStore`), uploads (`uploadStore`), subscriptions (`subscriptionStore`), account switching (`accountSwitchStore`), and 13 additional feature-specific stores. All stores follow the same pattern of TypeScript interfaces with Riverpod's `create()` function.

- **51 frontend API service files** — TypeScript service layer providing typed API clients for every backend endpoint. Key services include `auth.service.ts`, `serverService.ts`, `messageService.ts`, `cloudinaryService.ts` (12 KB for signed upload flow), `mediaService.ts` (20 KB for media processing), `inviteService.ts` (9 KB), `roleService.ts` (9 KB), and `stripePaymentService.ts` (12 KB for premium subscriptions).

#### Real-Time Messaging
- **WebSocket connection management** — The `ws-gateway` service manages persistent WebSocket connections with a custom binary protocol. Connection lifecycle includes: `OpIdentify` (client sends JWT), `OpReady` (server confirms session with heartbeat interval), `OpHeartbeat`/`OpHeartbeatAck` (30-second keepalive), `OpDispatch` (server pushes events), and `OpPresenceUpdate` (bidirectional presence changes). Connections that miss 3 consecutive heartbeats are automatically closed. Defined in `services/shared/protocol/`.

- **Redis Pub/Sub message fan-out** — When a message is created via the REST API (`msg-service`), it is published to a Redis channel keyed by the target channel ID. The `ws-gateway` subscribes to channels for every server the connected user belongs to and delivers the message payload to the appropriate WebSocket connection. This decouples message creation from real-time delivery, allowing the two services to scale independently.

- **Batch message insertion engine** — The `msg-service` includes a batcher component (`services/msg-service/internal/batcher/`) that collects individual INSERT operations and executes them as bulk inserts in batches of 50 messages or every 50 milliseconds (whichever comes first). Under load, this reduces database round-trips from ~50/sec to ~1/sec. Messages that fail insertion are moved to a Redis-backed dead letter queue for retry.

- **Message features** — Message editing with `edited_at` timestamp tracking, soft-delete via `deleted_at` column (messages are never hard-deleted), threading via `reply_to_id` and `thread_id` foreign keys, typing indicators with debounced WebSocket events and 8-second timeout, read receipts tracking per-user per-channel last-read position, Unicode and custom emoji reactions with per-message count aggregation, message pinning requiring `MANAGE_MESSAGES` permission, full-text search using PostgreSQL `tsvector` indexes, and code block rendering with syntax highlighting in the mobile message renderer.
  - **Migration references:** 001_initial_schema.up.sql (messages table), multiple follow-up migrations for threads, reactions, pins

- **Polls** — In-channel poll creation with multiple options, real-time vote count updates via WebSocket, and poll expiration support.

#### Voice & Video
- **LiveKit WebRTC integration** — Voice and video channels powered by LiveKit's Selective Forwarding Unit (SFU). The backend generates LiveKit room tokens via the `livekit-server-sdk-go` package, and the mobile app connects using `@livekit/react-native`. Features include Opus audio codec, adaptive video bitrate, push-to-talk, voice activity detection (VAD) with speaking indicators, and screen sharing.

- **Voice state tracking** — Voice states are tracked in the `voice_states` database table with columns for `user_id`, `channel_id`, `session_id`, `self_mute`, `self_deaf`, `suppress`, and `joined_at`. State changes are broadcast via WebSocket `OpVoiceState` events so all connected clients can display accurate voice channel member lists.
  - **Service files:** `backend/internal/services/voice_service.go`, `screen_share_service.go`

- **DM voice/video calls** — 1-on-1 voice and video calls in direct message conversations using the same LiveKit infrastructure. Call state is tracked in the `dm_calls` table.

#### Server Management
- **Server CRUD** — Create, read, update, and delete servers with customizable name, description, icon, and banner. Server ownership transfer is supported. Templates (Gaming, Study Group, Community) pre-populate channels and roles.
  - **Service file:** `backend/internal/services/server.go` (3.3 KB)

- **Invite system** — Generate unique invite codes with configurable maximum uses and expiration time. Vanity URL support for premium servers. Usage tracking with atomic counter increments.
  - **Service file:** `backend/internal/services/invite_service.go` (6.2 KB)

- **Channel system** — Text, voice, announcement, and category channel types. Categories act as folders for organizing channels. Drag-to-reorder support with `position` column. Slowmode configuration per channel. Topic/description support.

- **Role-Based Access Control (RBAC)** — 26 permission types stored as a 64-bit bitfield on each role. Permissions are combined with bitwise OR across all of a user's roles, then channel-level overwrites are applied. Server owners bypass all permission checks (full bitfield = `0xFFFFFFFFFFFFFFFF`). Permission calculation functions are implemented both in Go middleware and as PostgreSQL functions for RLS policy enforcement.
  - **Service files:** `permission_service.go` (2.5 KB), `permission_overwrite_service.go`, `member_role_service.go` (4.9 KB)
  - **Middleware:** `backend/internal/middleware/authorization.go` (280 lines)
  - **Migration reference:** 035_permission_calculation_functions.sql (6.9 KB)

- **Server boosting** — Boost system with tier progression that unlocks enhanced features for the community.
  - **Service file:** `backend/internal/services/boost_service.go` (6.6 KB)

- **Audit logging** — All administrative actions (role changes, channel creation/deletion, member kicks/bans, settings changes) are recorded in the audit log with timestamps, actor ID, and action details.
  - **Service file:** `backend/internal/services/audit_service.go` (4.3 KB)

- **Server discovery** — Browse and search public servers with community features.
  - **Service file:** `backend/internal/services/community_service.go` (5.5 KB)

#### Bot System (8 Built-In Bots)
- **Bot Registry pattern** — Centralized bot management with `bots.NewRegistry()` constructor. Each bot implements the `Bot` interface and is registered at startup via `registry.Register()`. The registry handles bot lifecycle (start, stop, event subscription) and provides dependency injection for database, Redis, and logger instances.

- **🛡️ Moderation Bot** — Manual moderation commands: `/ban @user [reason] [duration]` (permanent or temporary), `/kick @user [reason]`, `/mute @user [duration] [reason]`, `/warn @user [reason]` (tracked with escalation), `/purge [count]` (bulk delete 1-100 messages), `/unban @user`, `/unmute @user`, `/warnings @user` (view history). All actions are logged to the configured mod log channel. DM notifications are sent to the affected user when `dm_on_warn` or `dm_on_ban` is enabled in `mod_settings`.
  - **File:** `backend/internal/bots/moderation.go`
  - **Migration reference:** 002_bot_system_tables.sql — `mod_settings` table

- **🤖 AutoMod Bot** — Automated content filtering engine with 8 independently configurable filters: invite link blocking (regex for discord.gg, invite.gg, etc.), external link blocking (with allowlist), excessive caps detection (configurable threshold, default 70%), emoji spam limiting (per-message count), mass mention limiting (@mentions per message), duplicate message detection (content hash comparison in time window), word/phrase blacklist (glob pattern matching), and rate-based spam detection (similar messages in short window). When a filter triggers, the message is deleted, a warning is logged to the mod channel, and the user receives a warning that feeds into the escalation system.
  - **File:** `backend/internal/bots/automod.go`
  - **Service file:** `backend/internal/services/automod_service.go` (14.2 KB — the largest service file in the codebase)
  - **Migration reference:** 002_bot_system_tables.sql — `automod_settings` table

- **👋 Welcome Bot** — Customizable join and leave messages with template variables (`{user}`, `{server}`, `{member_count}`). Optional auto-role assignment on join. Configurable welcome channel.
  - **File:** `backend/internal/bots/welcome.go`
  - **Migration reference:** 002_bot_system_tables.sql — `welcome_settings` table

- **📊 Leveling Bot** — XP-based progression system. Users earn configurable XP per message (with cooldown to prevent spam farming). Level-up announcements in a configurable channel. Level-based role rewards (automatically assign roles at specific levels). Commands: `/rank` (view own level), `/leaderboard` (server ranking).
  - **File:** `backend/internal/bots/leveling.go`
  - **Service file:** `backend/internal/services/leveling_service.go`
  - **Migration reference:** 002_bot_system_tables.sql — `level_settings`, `user_xp` tables

- **🎵 Music Bot** — Music playback in voice channels. Commands: `/play [query/URL]`, `/skip`, `/queue`, `/nowplaying`, `/pause`, `/resume`, `/stop`, `/volume [0-100]`.
  - **File:** `backend/internal/bots/music.go`

- **🎫 Ticket Bot** — Support ticket system. Users open tickets that create private channels visible only to the creator and staff. Configurable category channel for ticket organization. Customizable opening message. Ticket status tracking (open, assigned, closed).
  - **File:** `backend/internal/bots/ticket.go`
  - **Migration reference:** 002_bot_system_tables.sql — `ticket_settings`, `tickets` tables

- **📊 Poll Bot** — In-channel polls with multiple options, real-time vote counting, and configurable expiration.
  - **File:** `backend/internal/bots/poll.go`

- **⭐ Starboard Bot** — Tracks star reactions on messages. When a message receives enough stars (configurable threshold), it is cross-posted to a designated starboard channel. Prevents duplicate entries and tracks star count changes.
  - **File:** `backend/internal/bots/starboard.go`
  - **Migration reference:** 002_bot_system_tables.sql — `starboard_settings`, `starboard_entries` tables

#### Social Features
- **Friend system** — Complete friendship lifecycle: send request, accept, decline, block. Bidirectional friendship tracking in the `friends` table. Friends can DM each other without being in the same server.
  - **Service file:** `backend/internal/services/friend_service.go` (10.1 KB)

- **Presence tracking** — Real-time online status (Online, Idle, Do Not Disturb, Offline) tracked via WebSocket connection state and broadcast to friends and server members via `OpPresenceUpdate` events.
  - **Service file:** `backend/internal/services/presence_service.go` (3.3 KB)

- **Push notifications** — Delivered via Supabase Edge Functions for mentions, friend requests, DMs, and server invites.

- **User profiles** — Customizable avatar and banner (uploaded to Cloudinary), bio text, status message, and badge display.

#### Media & Uploads
- **Cloudinary direct upload** — Secure signed upload flow: the mobile app requests a cryptographic signature from the backend (`GET /api/v1/cloudinary/sign`), then uploads directly to Cloudinary's CDN. This prevents file data from passing through the Flicko backend, reducing server load and leveraging Cloudinary's global edge network. The signature is generated using HMAC-SHA256 with the Cloudinary API secret.
  - **Handler:** `backend/internal/handlers/cloudinary.go` (4.3 KB)
  - **Frontend service:** `shared/services/cloudinaryService.ts` (12 KB)

- **File validation** — Backend middleware validates file uploads by reading the first 512 bytes for MIME type detection (`http.DetectContentType()`), checking against allowed types (image/jpeg, image/png, image/gif, image/webp, video/mp4, video/webm), and enforcing configurable size limits (default 25 MB via NGINX, 10 MB via Go middleware).

- **GIF search** — GIPHY API integration via Supabase Edge Function for searching and sharing GIFs in messages.

#### Premium Subscription
- **Flicko Plus** — Premium tier with Stripe payment integration via `@stripe/stripe-react-native`. Unlocks: custom emoji uploads, animated avatars, higher upload size limits, enhanced voice audio quality, server boosting perks, and soundboard access.
  - **Frontend service:** `shared/services/stripePaymentService.ts` (12 KB)
  - **Screen:** `mobile/app/flicko-plus.tsx` (26 KB)

#### Security
- **5-layer defense-in-depth** — Cloudflare (WAF, DDoS, bot challenge) → NGINX (TLS, 4 rate limit zones, body limits) → Go application (JWT, CSRF, XSS sanitization, RBAC, Redis rate limiting) → PostgreSQL (RLS policies, encrypted connections) → Docker (network isolation, read-only FS, non-root).

- **10-layer middleware stack** — Applied to every protected request in order: Request ID generation → CORS headers → 30-second timeout context → 10 MB body limit → HTML/XSS input sanitization → CSRF token validation (X-CSRF-Token ≥16 chars on POST/PUT/DELETE/PATCH) → sensitive header redaction in logs → Redis-backed distributed rate limiting → JWT authentication (HMAC-SHA256 with Supabase API fallback) → role-based authorization with permission bitfield checks.
  - **Files:** `backend/internal/middleware/auth.go`, `authorization.go` (280 lines), `rate_limiter.go`, `security.go` (228 lines)

- **AES-256-GCM encryption** — Sensitive data encrypted at rest using a 32-byte key from the `ENCRYPTION_KEY` environment variable (64 hex characters). In development, an ephemeral key is auto-generated with a warning log.

- **Row-Level Security** — PostgreSQL RLS policies (migration 034, 13.3 KB) enforce data access rules at the database layer independent of application middleware: users can only read messages in channels they have access to, only edit their own messages, only see DMs they participate in, and only view member data within their servers.

#### Database Schema
- **65 Supabase migrations** — Complete schema versioning from initial tables through bot system tables (migration 002, 291 lines), advanced RLS policies (migration 034, 13.3 KB), permission calculation functions (migration 035, 6.9 KB), and incremental feature additions through migration 065.

- **3 backend migrations** — Additional migrations in `backend/migrations/` covering the core schema (`001_initial_schema.up.sql`, 98 lines) and bot system tables (`002_bot_system_tables.sql`, 291 lines).

- **Core tables** — `users`, `servers`, `channels`, `messages`, `members`, `roles`, `member_roles`, `invites`, `reactions`, `friends`, `direct_messages`, `dm_conversations`, `dm_participants`, `voice_states`, `threads`, and associated join/junction tables.

- **Bot system tables** — `bots`, `bot_guilds`, `mod_settings`, `automod_settings`, `welcome_settings`, `level_settings`, `user_xp`, `ticket_settings`, `tickets`, `starboard_settings`, `starboard_entries`, and `warnings`.

#### Infrastructure
- **Docker Compose production stack** — 455-line `docker-compose.prod.yml` defining 9 containers across 3 isolated networks (`flicko_edge` for NGINX, `flicko_internal` for Go services, `flicko_monitor` for observability). Total resource allocation: ~3.5 GB RAM, ~3.15 CPU cores, leaving ~4.5 GB for OS and buffers on an 8 GB VPS.

- **NGINX reverse proxy** — 232-line `nginx/nginx.conf` with TLS termination (Cloudflare Origin certificates), 4 rate limit zones (api: 30 req/s, ws: 5 conn/s, upload: 2 req/s, auth: 5 req/min), WebSocket upgrade support, gzip compression, and JSON-formatted access logs for Loki ingestion.

- **Monitoring stack** — Prometheus (metrics TSDB, 15s scrape interval), Grafana (dashboards and alerting with auto-provisioned data sources), Loki (log aggregation with 30-day retention), Node Flutterrter (host CPU/RAM/disk/network metrics), and NGINX Flutterrter (request throughput and status codes).

- **Server setup automation** — `scripts/server-setup.sh` (36 KB) automates complete VPS initialization: system updates, Docker installation, UFW firewall (ports 80, 443, SSH only), fail2ban with SSH protection, SSH hardening (key-only auth, non-standard port), 2 GB swap file creation, kernel tuning for high-concurrency WebSocket workloads, and log rotation configuration.

- **GitHub Actions CI/CD** — `.github/workflows/docker-image.yml` triggers Docker image builds on push to `main`. Pre-commit hooks via Husky + lint-staged run Prettier on TypeScript/JSON/YAML/Markdown and gofmt on Go files.

#### Testing
- **42 Go test files** — Covering all major service domains: auth (3 files), AutoMod (`automod_service_test.go`, 5.7 KB), permissions (2 files), friends (`friend_service_test.go`, 3.9 KB), warnings (`warning_service_test.go`, 3.2 KB), reports (`report_service_test.go`, 2.6 KB), messaging, voice, DM reactions, performance metrics, and attachment cleanup. All tests use the table-driven pattern with `testify` v1.11.1 assertions.

- **Jest test infrastructure** — TypeScript test directories in `shared/stores/__tests__/` and `shared/services/__tests__/` with Jest v29.7.0.

#### Documentation
- **87 markdown files** — Comprehensive documentation suite across 12 categories: root (4), getting started (6), architecture (9), features (10), API reference (8), database (7), backend (8), frontend (7), deployment (6), security (5), testing (5), development (5), and diagrams (7). Includes 6 Mermaid architecture diagrams, glossary of 22 Flicko-specific terms, role-based reading guides, and complete cross-references.

### Security
- Applied security audit findings from conversation `806235ec` — 9 issues identified and fixed across critical (rate limiting, authorization), high (body limits, CSRF, error boundaries, file validation, XSS), and medium (crash reporting, log redaction) severity levels.

---

## [Unreleased]

### Planned
- End-to-end encryption for direct messages
- Web client (React/Next.js)
- Desktop client (Electron or Tauri)
- Custom bot API for third-party developers
- Webhook integrations
- Advanced search with filters
- Message scheduling
- Channel threads improvements
- Server analytics dashboard
- Push notification preferences granularity

---

## Migration Reference

The following table maps every database migration to its purpose. Use this when you need to understand what schema changes a specific migration introduced.

| # | Migration File | Lines | Purpose |
|---|---------------|-------|---------|
| 001 | `001_initial_schema.up.sql` | 98 | Core tables: users, servers, channels, messages, members, roles, invites |
| 002 | `002_bot_system_tables.sql` | 291 | Bot system: bots, bot_guilds, mod/automod/welcome/level/ticket/starboard settings |
| 003–033 | Various | — | Incremental feature tables, indexes, constraints, and column additions |
| 034 | `034_advanced_rls_policies.sql` | ~400 | Comprehensive Row-Level Security policies for all tables |
| 035 | `035_permission_calculation_functions.sql` | ~200 | SQL functions: calculate_permissions(), has_permission(), check_channel_permission() |
| 036–065 | Various | — | Additional features, indexes, performance optimizations, and schema refinements |

---

## Related Documentation

- [README (Documentation Hub)](README.md) — Master index of all documentation files with role-based navigation guides
- [Contributing Guide](CONTRIBUTING.md) — How to contribute changes including commit conventions that feed this changelog
- [Database: Migrations](database/migrations.md) — Detailed migration documentation with creation procedures and rollback instructions
- [Architecture: System Overview](architecture/system-overview.md) — Technical architecture context for understanding the changes documented here

## Quick Reference

| Item | Value |
|------|-------|
| **Current version** | 1.0.0 |
| **Total Supabase migrations** | 65 |
| **Total backend migrations** | 3 |
| **Changelog format** | Keep a Changelog 1.1.0 |
| **Versioning scheme** | Semantic Versioning 2.0.0 |

---

*Last Updated: 2026-04-11 | Version: 1.0.0 | Maintained by: Flicko Team*
