# Folder Structure

> **Reading time:** ~15 minutes · **Audience:** All Developers · **Last Updated:** 2026-04-11

This document provides a complete annotated directory tree for the Flicko monorepo. Every directory and key file is listed with its purpose, approximate size, and which service owns it. Use this as your primary map for navigating the codebase.

---

## Root Directory

```
Flicko/
├── backend/                    # Go monolith: Bot framework, services, middleware
├── services/                   # Go microservices: ws-gateway, msg-service, shared packages
├── mobile/                     # Flutter app: Riverpod state management, GoRouter, modular architecture
├── mobile/lib/                 # Flutter source: features, core, data models
├── mobile/assets/              # App assets: icons, fonts, banners
├── mobile/pubspec.yaml         # Flutter dependencies
├── supabase/                   # Supabase config: 94 SQL migrations, Edge Functions
├── mail-gateway/               # Go email service
├── nginx/                      # NGINX reverse proxy config
├── monitoring/                 # Prometheus, Grafana, Loki configurations
├── scripts/                    # Deployment and setup scripts
├── docs/                       # 121 documentation files
├── .github/                    # GitHub Actions CI/CD, issue templates
├── .husky/                     # Git hooks (pre-commit: gofmt + dart format)
├── docker-compose.prod.yml     # Production: 9 containers, 3 networks (455 lines)
├── docker-compose.dev.yml      # Development stack
├── .env.example                # Environment variable template
├── package.json                # Root: Husky + lint-staged
├── setup.sh                    # Interactive setup wizard (9.7 KB)
├── README.md                   # Project README
└── .gitignore                  # Git ignore rules
```

---

## backend/ — Bot Framework & Service Layer

The `backend/` directory contains the largest Go service — the bot framework with 8 built-in bots, 95 service files covering all business logic, 22 data models, and the 10-layer security middleware pipeline.

```
backend/
├── cmd/
│   └── server/
│       └── main.go                          # Entry point (321 lines) — 10-step init
│
├── internal/
│   ├── bots/                                # 8 built-in bot implementations
│   │   ├── moderation.go                    # 🛡️ Ban, kick, mute, warn, purge, unban, unmute
│   │   ├── automod.go                       # 🤖 8 content filters (invite, link, caps, emoji, mention, dup, blacklist, spam)
│   │   ├── welcome.go                       # 👋 Join/leave messages, auto-role, template vars
│   │   ├── leveling.go                      # 📊 XP system, levels, role rewards, leaderboard
│   │   ├── music.go                         # 🎵 Voice channel playback, queue, skip, volume
│   │   ├── ticket.go                        # 🎫 Support tickets, private channels, assignment
│   │   ├── poll.go                          # 📊 Polls with options, votes, expiry
│   │   └── starboard.go                     # ⭐ Star reactions, threshold, cross-post
│   │
│   ├── commands/
│   │   └── router.go                        # Slash command dispatcher (197 lines)
│   │
│   ├── events/
│   │   └── bus.go                           # In-process event bus (Subscribe/Publish)
│   │
│   ├── handlers/                            # HTTP handlers (thin controllers)
│   │   ├── auth.go                          # Registration, login, token refresh
│   │   ├── server.go                        # Server CRUD endpoints
│   │   ├── channel.go                       # Channel management endpoints
│   │   ├── message.go                       # Message CRUD endpoints
│   │   ├── cloudinary.go                    # Upload signature generation (4.3 KB)
│   │   ├── voice.go                         # LiveKit token generation
│   │   ├── invite.go                        # Invite code generation/validation
│   │   ├── role.go                          # Role CRUD, permission management
│   │   ├── friend.go                        # Friend request lifecycle
│   │   ├── dm.go                            # Direct message endpoints
│   │   └── ...                              # Additional feature handlers
│   │
│   ├── middleware/                           # 10-layer security pipeline
│   │   ├── auth.go                          # Layer 8: JWT validation (HMAC-SHA256)
│   │   ├── authorization.go                 # Layer 9-10: RBAC checks (280 lines)
│   │   ├── rate_limiter.go                  # Layer 7: Redis-backed distributed rate limiting
│   │   ├── security.go                      # Layers 2-6: CORS, timeout, body limit, XSS, CSRF (228 lines)
│   │   └── request_id.go                    # Layer 1: UUID generation per request
│   │
│   ├── models/                              # 22 Go struct definitions
│   │   ├── user.go                          # User model with profile fields
│   │   ├── server.go                        # Server model
│   │   ├── channel.go                       # Channel model (4 types)
│   │   ├── message.go                       # Message model (reactions, threads, pins)
│   │   ├── member.go                        # Server membership
│   │   ├── role.go                          # Roles with 26 permission bits
│   │   ├── invite.go                        # Invite codes
│   │   ├── friend.go                        # Friendship status
│   │   ├── voice_state.go                   # Voice channel participation
│   │   ├── dm_conversation.go               # DM conversation metadata
│   │   ├── dm_message.go                    # DM message content
│   │   ├── bot.go                           # Bot registration
│   │   ├── warning.go                       # Moderation warnings
│   │   ├── ticket.go                        # Support tickets
│   │   └── ...                              # Additional models
│   │
│   ├── services/                            # 95 service files (ALL business logic)
│   │   ├── server.go                        # Server CRUD (3.3 KB)
│   │   ├── channel_service.go               # Channel lifecycle
│   │   ├── message_service.go               # Message operations
│   │   ├── permission_service.go            # Permission calculation (2.5 KB)
│   │   ├── permission_overwrite_service.go  # Channel-level overrides
│   │   ├── member_role_service.go           # Role assignment (4.9 KB)
│   │   ├── invite_service.go                # Invite management (6.2 KB)
│   │   ├── friend_service.go                # Friend lifecycle (10.1 KB)
│   │   ├── dm_message_service.go            # DM operations (6.1 KB)
│   │   ├── dm_reaction_service.go           # DM reactions (3.4 KB)
│   │   ├── voice_service.go                 # Voice state + token gen
│   │   ├── screen_share_service.go          # Screen sharing
│   │   ├── presence_service.go              # Online status (3.3 KB)
│   │   ├── automod_service.go               # AutoMod engine (14.2 KB — LARGEST)
│   │   ├── mod_service.go                   # Manual moderation
│   │   ├── audit_service.go                 # Audit logging (4.3 KB)
│   │   ├── boost_service.go                 # Server boosting (6.6 KB)
│   │   ├── community_service.go             # Server discovery (5.5 KB)
│   │   ├── leveling_service.go              # XP calculations
│   │   ├── ticket_service.go                # Ticket management
│   │   ├── starboard_service.go             # Starboard logic
│   │   ├── role_service.go                  # Role management
│   │   ├── reaction_service.go              # Message reactions
│   │   ├── thread_service.go                # Message threads
│   │   ├── search_service.go                # Full-text search (tsvector)
│   │   ├── report_service.go                # User reports
│   │   ├── notification_service.go          # Push notification triggers
│   │   └── ...                              # 70+ additional services
│   │
│   └── config/
│       └── config.go                        # Env loading + validation (149 lines)
│
├── migrations/                              # Backend-specific migrations
│   ├── 001_initial_schema.up.sql            # Core tables (98 lines)
│   ├── 002_bot_system_tables.sql            # Bot tables (291 lines)
│   └── 003_indexes.sql                      # Performance indexes
│
├── go.mod                                   # Go module: github.com/.../backend
├── go.sum                                   # Dependency lockfile
└── Dockerfile                               # Multi-stage: Go build → Alpine runtime
```

---

## services/ — WebSocket Gateway & Message API

```
services/
├── go.work                                  # Go workspace linking all service modules
│
├── ws-gateway/                              # WebSocket Gateway Service
│   ├── cmd/gateway/main.go                  # Entry point
│   ├── internal/
│   │   ├── hub/hub.go                       # Connection manager, channel subscriptions
│   │   ├── connection/connection.go         # Per-client goroutines, heartbeat
│   │   └── presence/presence.go             # Online status tracking
│   ├── go.mod
│   └── Dockerfile
│
├── msg-service/                             # REST API Service
│   ├── cmd/server/main.go                   # Entry point
│   ├── internal/
│   │   ├── batcher/batcher.go               # Batch insertion engine (50/batch, 50ms flush)
│   │   └── handlers/                        # HTTP handlers
│   ├── go.mod
│   └── Dockerfile
```

---

## mobile/ — Flutter Application

The `mobile/` directory contains the cross-platform Flutter application. It follows a modular, feature-first architecture where each domain (auth, server, messaging, etc.) has its own folder containing presentation, domain, and data logic.

```
mobile/
├── lib/
│   ├── main.dart                       # App entry point — ProviderScope init
│   │
│   ├── core/                           # App-wide infrastructure
│   │   ├── router/                     # GoRouter configuration (app_router.dart)
│   │   ├── theme/                      # Theme definitions (Light/Dark/AMOLED)
│   │   ├── constants/                  # Global constants (API URLs, keys)
│   │   ├── network/                    # API clients and WebSocket logic
│   │   ├── error_handling/             # App-wide error handling
│   │   ├── extensions/                 # Dart extensions for UI/logic
│   │   ├── services/                   # App-wide services
│   │   └── utils/                      # Formatting and validation helpers
│   │
│   ├── features/                       # Modular feature-first architecture
│   │   ├── auth/                       # Authentication (Login, Register, Reset)
│   │   ├── server/                     # Server discovery, creation, management
│   │   ├── channel/                    # Channel list, reordering, settings
│   │   ├── messaging/                  # Real-time chat, attachments, reactions
│   │   ├── voice/                      # LiveKit integration, voice HUD
│   │   ├── video/                      # Video grid, screen share
│   │   ├── dm/                         # Direct messages and group DMs
│   │   ├── profile/                    # User profiles (public & private)
│   │   ├── settings/                   # App, privacy, voice settings
│   │   └── premium/                    # Flicko Plus & plus subscriptions
│   │
│   └── data/                           # Data layer (shared across features)
│       ├── models/                     # Data models (JSON serialization)
│       ├── repositories/               # Repository implementations
│       ├── datasources/                # Remote/Local data sources
│       ├── clients/                    # Specific API clients
│       └── services/                   # Data-focused services
│
├── assets/                             # Static assets (images, icons, fonts)
├── android/                            # Android native project files
├── ios/                                # iOS native project files
├── test/                               # Flutter unit and widget tests
└── pubspec.yaml                        # Flutter dependencies and config
```

---

## supabase/ — Database & Edge Functions

```
supabase/
├── migrations/                              # 65 SQL migration files
│   ├── 001_initial_schema.up.sql            # Core tables (98 lines)
│   ├── 002_bot_system_tables.sql            # Bot system (291 lines)
│   ├── ...
│   ├── 034_advanced_rls_policies.sql        # RLS policies (13.3 KB)
│   ├── 035_permission_calculation_functions.sql  # SQL functions (6.9 KB)
│   └── 065_*.sql                            # Latest migration
│
├── functions/                               # Supabase Edge Functions
│   ├── gif-search/                          # GIPHY API integration
│   └── push-notification/                   # Push notification delivery
│
└── config.toml                              # Supabase project config
```

---

## Infrastructure Files

```
nginx/
└── nginx.conf                               # NGINX config (232 lines)
                                              # TLS, 4 rate limit zones, WebSocket upgrade

monitoring/
├── prometheus/
│   └── prometheus.yml                       # Scrape config (15s interval)
├── grafana/
│   ├── provisioning/
│   │   ├── datasources/                     # Auto-provisioned: Prometheus + Loki
│   │   └── dashboards/                      # Pre-configured dashboards
│   └── dashboards/                          # Dashboard JSON files
└── loki/
    └── loki-config.yml                      # 30-day retention

scripts/
├── server-setup.sh                          # VPS initialization (36 KB)
└── health-check.sh                          # Service health verification

docker-compose.prod.yml                      # Production (455 lines, 9 containers, 3 networks)
docker-compose.dev.yml                       # Development stack
```

---

## Related Documentation

- [Architecture: System Overview](system-overview.md) — How these directories map to the 3-service architecture
- [Architecture: Tech Stack](tech-stack.md) — Dependencies used in each directory
- [Backend: Overview](../backend/overview.md) — Deep dive into backend/ structure
- [Frontend: Overview](../frontend/overview.md) — Deep dive into mobile/ and shared/ structure

---

*Last Updated: 2026-04-24 | Version: 1.0.0 | Maintained by: Flicko Team*
