<p align="center">
  <img src="mobile/assets/Flicko_icon.png" alt="Flicko Logo" width="140" height="140" style="border-radius: 28px;" />
</p>

<h1 align="center">Flicko</h1>

<p align="center">
  <strong>A full-featured, production-ready, open-source Discord alternative</strong>
  <br />
  <em>Real-time messaging · Voice & Video · Bot framework · Self-hostable on a single VPS</em>
</p>

<p align="center">
  <img src="https://img.shields.io/badge/Go-1.25-00ADD8?style=for-the-badge&logo=go&logoColor=white" alt="Go" />
  <img src="https://img.shields.io/badge/React_Native-0.81-61DAFB?style=for-the-badge&logo=react&logoColor=black" alt="React Native" />
  <img src="https://img.shields.io/badge/Expo-SDK_54-000020?style=for-the-badge&logo=expo&logoColor=white" alt="Expo" />
  <img src="https://img.shields.io/badge/PostgreSQL-15+-4169E1?style=for-the-badge&logo=postgresql&logoColor=white" alt="PostgreSQL" />
  <img src="https://img.shields.io/badge/TypeScript-5.9-3178C6?style=for-the-badge&logo=typescript&logoColor=white" alt="TypeScript" />
  <img src="https://img.shields.io/badge/Docker-24+-2496ED?style=for-the-badge&logo=docker&logoColor=white" alt="Docker" />
  <img src="https://img.shields.io/badge/Redis-7+-DC382D?style=for-the-badge&logo=redis&logoColor=white" alt="Redis" />
  <img src="https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge" alt="License" />
</p>

<p align="center">
  <a href="#-quick-start"><strong>Quick Start »</strong></a> ·
  <a href="docs/README.md"><strong>Full Docs »</strong></a> ·
  <a href="docs/architecture/system-overview.md"><strong>Architecture »</strong></a> ·
  <a href="docs/features/feature-index.md"><strong>Features »</strong></a> ·
  <a href="docs/CONTRIBUTING.md"><strong>Contributing »</strong></a>
</p>

---

<p align="center">
  <img src="mobile/assets/flicko_banner_enhanced.png" alt="Flicko App Banner" style="max-width: 100%; border-radius: 12px; margin: 16px 0;" />
</p>

## 📖 Table of Contents

- [✨ What is Flicko?](#-what-is-flicko)
- [🏗️ System Architecture](#️-system-architecture)
- [🚀 Features](#-features)
- [⚡ Quick Start](#-quick-start)
- [🛠️ Complete Tech Stack](#️-complete-tech-stack)
- [📁 Project Structure](#-project-structure)
- [🐳 Production Deployment](#-production-deployment)
- [🔒 Security Architecture](#-security-architecture)
- [📊 Monitoring & Observability](#-monitoring--observability)
- [🤖 Bot System Deep Dive](#-bot-system-deep-dive)
- [💾 Database Architecture](#-database-architecture)
- [🧪 Testing](#-testing)
- [📖 Documentation](#-documentation)
- [🤝 Contributing](#-contributing)
- [📊 Project Stats](#-project-stats)
- [📜 License](#-license)

---

## ✨ What is Flicko?

Flicko is a **complete, open-source communication platform** — think Discord, but fully self-hostable and built from scratch. It delivers a production-grade experience with real-time messaging over WebSockets, voice & video channels powered by LiveKit WebRTC, an extensible 8-bot moderation framework, direct messaging, rich media uploads via Cloudinary CDN, server management with granular role-based permissions, and a premium subscription tier with Stripe integration.

The entire platform runs on a **single 8 GB VPS** serving **3,000–5,000 concurrent users**, orchestrated through Docker Compose with 9 containers across 3 isolated networks, monitored by a full Prometheus + Grafana + Loki observability stack.

> **This is not a toy project.** Flicko has **65 database migrations**, **95 backend service files**, **51 frontend API services**, **22 Zustand state stores**, **42 Go unit test suites**, **26 granular permission types**, and **87 documentation files**. Every feature is fully implemented end-to-end, from mobile UI to database queries.

### Why Flicko?

| | Flicko | Discord | Revolt | Guilded |
|---|---|---|---|---|
| **Open Source** | ✅ MIT License | ❌ Proprietary | ✅ AGPL | ❌ Proprietary |
| **Self-Hostable** | ✅ Single VPS | ❌ | ✅ Complex setup | ❌ |
| **Mobile App** | ✅ iOS + Android | ✅ | ❌ Web only | ✅ |
| **Bot Framework** | ✅ 8 built-in bots | ❌ Third-party only | ❌ | ❌ |
| **Voice/Video** | ✅ LiveKit WebRTC | ✅ | ❌ | ✅ |
| **Mod Tools** | ✅ AutoMod + Manual | ✅ | ⚠️ Basic | ✅ |
| **Single VPS Deploy** | ✅ 8 GB RAM | N/A | ⚠️ 16+ GB | N/A |

---

## 🏗️ System Architecture

Flicko follows a **microservices architecture** with three Go backend services, a React Native mobile client, and managed cloud services for data persistence, real-time communication, and media delivery.

```mermaid
graph TB
    subgraph Client["📱 Client Layer"]
        APP["React Native Mobile App<br/>Expo SDK 54 · TypeScript 5.9<br/>iOS + Android"]
    end

    subgraph Edge["🌐 Edge Layer"]
        CF["☁️ Cloudflare<br/>CDN · WAF · DDoS Protection<br/>Bot Challenge · Origin TLS"]
        NGX["🔀 NGINX 1.25-alpine<br/>TLS Termination · Rate Limiting<br/>WebSocket Upgrade · Gzip<br/>4 Rate Limit Zones"]
    end

    subgraph Services["⚙️ Go Microservices"]
        WS["⚡ ws-gateway<br/>WebSocket Connection Manager<br/>Real-Time Event Fan-out<br/>Heartbeat · Presence Tracking<br/>6,000 Max Connections<br/>1 GB RAM · 1 CPU"]
        MSG["📨 msg-service<br/>Message REST API<br/>Batch Insert Engine (50 msg/50ms)<br/>Dead Letter Queue<br/>Attachment Processing<br/>512 MB RAM · 0.5 CPU"]
        BE["🤖 backend<br/>Bot Framework (8 Bots)<br/>Slash Command Router<br/>Cloudinary Signing<br/>Health Endpoints<br/>512 MB RAM · 0.5 CPU"]
    end

    subgraph Data["💾 Data Layer"]
        DB["🐘 Supabase PostgreSQL<br/>65 Migrations · RLS Policies<br/>Edge Functions · Realtime CDC"]
        REDIS["🔴 Upstash Redis<br/>Pub/Sub Messaging<br/>Session Cache · Rate Limits<br/>Dead Letter Queue · TLS"]
        CLOUD["☁️ Cloudinary CDN<br/>Avatar · Banner · Attachments<br/>On-the-fly Transforms<br/>Signed Direct Upload"]
        LK["🎙️ LiveKit Cloud<br/>Voice Channels · Video Chat<br/>Screen Sharing · WebRTC SFU"]
    end

    subgraph Monitor["📊 Observability"]
        PROM["Prometheus · Grafana · Loki<br/>Node Exporter · NGINX Exporter"]
    end

    APP -->|HTTPS REST| CF
    APP -->|WSS WebSocket| CF
    APP -->|Voice/Video| LK
    APP -->|Direct Upload| CLOUD
    CF --> NGX
    NGX -->|/ws| WS
    NGX -->|/api/*| MSG
    NGX -->|/bots, /commands| BE
    WS --> DB & REDIS
    MSG --> DB & REDIS & CLOUD
    BE --> DB & REDIS
    PROM -.->|Scrape /metrics| WS & MSG
```

### Why Three Services?

| Decision | Rationale |
|----------|-----------|
| **ws-gateway is separate** | Holds thousands of stateful WebSocket connections. REST API deployments don't drop active connections. Can be scaled independently based on concurrent user count. |
| **msg-service is separate** | Pure stateless REST API — horizontally scalable with `least_conn` load balancing. Batch insertion engine operates independently from real-time delivery. |
| **backend is monolithic** | Bot system uses in-process pub/sub event bus. Splitting 8 bots into microservices would add network overhead without benefit at this scale (< 10K users). |
| **Three Docker networks** | `flicko_edge` (internet-facing), `flicko_internal` (services, no internet), `flicko_monitor` (observability, no internet). Prevents lateral movement if a container is compromised. |

### Request Lifecycle

Every API request passes through **12 processing stages**:

```
Client → Cloudflare WAF → NGINX Rate Limit → Request ID → CORS →
Timeout (30s) → Body Limit (10MB) → Input Sanitization → CSRF Check →
Header Redaction → Redis Rate Limit → JWT Auth → Handler → Service → DB
```

---

## 🚀 Features

Flicko ships with **30+ fully implemented, production-quality features** across 6 domains:

### 💬 Communication

| Feature | Status | Implementation |
|---------|--------|---------------|
| **Real-time messaging** | ✅ | WebSocket via ws-gateway, Redis Pub/Sub fan-out |
| **Message editing & deletion** | ✅ | Soft-delete with `deleted_at`, edit history tracking |
| **Threads & replies** | ✅ | Parent message references, thread channels |
| **Typing indicators** | ✅ | Debounced WebSocket events with 8s timeout |
| **Read receipts** | ✅ | Per-user per-channel last-read tracking |
| **Reactions & emoji** | ✅ | Unicode + custom emoji, per-message reaction counts |
| **Message pinning** | ✅ | Pin/unpin with `MANAGE_MESSAGES` permission |
| **Message search** | ✅ | Full-text search with PostgreSQL `tsvector` |
| **GIF search** | ✅ | GIPHY API integration via Supabase Edge Function |
| **Polls** | ✅ | Multi-option polls with real-time vote updates |
| **Code blocks** | ✅ | Syntax highlighting in message renderer |

### 🎙️ Voice & Video

| Feature | Status | Implementation |
|---------|--------|---------------|
| **Voice channels** | ✅ | LiveKit WebRTC SFU with Opus codec |
| **Video chat** | ✅ | LiveKit video rooms with adaptive bitrate |
| **Screen sharing** | ✅ | Desktop/app sharing via LiveKit |
| **Push-to-talk** | ✅ | Client-side audio gating |
| **Voice activity detection** | ✅ | LiveKit VAD with speaking indicators |
| **DM voice/video calls** | ✅ | 1-on-1 calls via LiveKit |

### 🏰 Server Management

| Feature | Status | Implementation |
|---------|--------|---------------|
| **Server CRUD** | ✅ | Create, edit, delete, transfer ownership |
| **Invite system** | ✅ | Unique codes with max uses, expiry, vanity URLs |
| **Channel categories** | ✅ | Nested channels with drag-to-reorder |
| **Role management** | ✅ | 26 permission types with bitfield calculations |
| **Channel permission overwrites** | ✅ | Per-role and per-user channel overrides |
| **Server templates** | ✅ | Gaming, Study Group, Community presets |
| **Server boosting** | ✅ | Boost tiers with enhanced features |
| **Custom emoji & stickers** | ✅ | Upload and use per-server |
| **Audit log** | ✅ | All admin actions recorded with timestamps |
| **Server discovery** | ✅ | Browse and search public servers |

### 🤖 Bot System (8 Built-In Bots)

| Bot | Key Commands | Description |
|-----|-------------|-------------|
| **🛡️ Moderation** | `/ban`, `/kick`, `/mute`, `/warn`, `/purge` | Manual moderation with escalating warnings |
| **🤖 AutoMod** | Automatic | 8 content filters (invites, links, caps, spam, emoji, mentions, blacklist, duplicates) |
| **👋 Welcome** | Configurable | Custom join/leave messages, auto-role assignment |
| **📊 Leveling** | `/rank`, `/leaderboard` | XP per message, level-up announcements, role rewards |
| **🎵 Music** | `/play`, `/skip`, `/queue`, `/np` | Music playback in voice channels |
| **🎫 Ticket** | `/ticket` | Support ticket creation with categories |
| **📊 Poll** | `/poll` | In-channel polls with multi-option voting |
| **⭐ Starboard** | Automatic | Star reaction tracking, hall-of-fame channel |

### 👥 Social & Profiles

| Feature | Status | Implementation |
|---------|--------|---------------|
| **Friend requests** | ✅ | Send, accept, decline, block lifecycle |
| **Direct messages** | ✅ | 1-on-1 DMs with reactions and typing |
| **Group DMs** | ✅ | Up to 10 participants |
| **Online presence** | ✅ | Online, Idle, DnD, Offline with WebSocket tracking |
| **User profiles** | ✅ | Avatar, banner, bio, badges, status |
| **Activity feed** | ✅ | Mentions, friend requests, server events |
| **Push notifications** | ✅ | Supabase Edge Function delivery |
| **Account switching** | ✅ | Multi-account support |

### 💎 Premium & Media

| Feature | Status | Implementation |
|---------|--------|---------------|
| **Flicko Plus** subscription | ✅ | Stripe payment integration |
| **Image uploads** | ✅ | JPEG, PNG, GIF, WebP via Cloudinary |
| **Video uploads** | ✅ | MP4, WebM with size validation |
| **Avatar & banner** | ✅ | Signed direct upload to Cloudinary CDN |
| **File attachments** | ✅ | Multi-file with progress tracking |
| **Image transforms** | ✅ | Cloudinary on-the-fly resize/crop/format |
| **Animated avatars** | ✅ | Premium-only GIF avatar support |

---

## ⚡ Quick Start

### Prerequisites

| Tool | Version | Check |
|------|---------|-------|
| **Node.js** | ≥ 18.0 | `node --version` |
| **npm** | ≥ 9.0 | `npm --version` |
| **Go** | ≥ 1.22 | `go version` |
| **Docker** | ≥ 24.0 | `docker --version` |
| **Git** | ≥ 2.30 | `git --version` |

### Installation

```bash
# 1. Clone the repository
git clone https://github.com/Santosh-Prasad-Verma/Flicko.git
cd Flicko

# 2. Install root dependencies (Husky, Prettier, lint-staged)
npm install

# 3. Configure environment variables
cp .env.example .env
cp mobile/.env.example mobile/.env
# ⚠️  IMPORTANT: Fill in your Supabase, Redis, and Cloudinary credentials

# 4. Install mobile dependencies
cd mobile && npm install && cd ..

# 5. Start the backend services
cd services && go run ./msg-service/cmd/server    # Terminal 1
cd services && go run ./ws-gateway/cmd/gateway    # Terminal 2

# 6. Start the mobile app
cd mobile && npx expo start                        # Terminal 3
```

> **💡 First time?** Run `./setup.sh` for an interactive wizard that checks all prerequisites and guides you through configuration.

### Environment Variables (Key Ones)

```env
# Database (Supabase)
DATABASE_URL=postgresql://postgres.XXX:PASSWORD@HOST:6543/postgres?sslmode=require

# Redis (Upstash)
REDIS_URL=rediss://default:TOKEN@HOST.upstash.io:6379

# Auth
JWT_SECRET=your-32-character-minimum-secret-key

# Media
CLOUDINARY_CLOUD_NAME=your_cloud_name
CLOUDINARY_API_KEY=your_api_key
CLOUDINARY_API_SECRET=your_api_secret

# Voice/Video
LIVEKIT_API_KEY=your_livekit_key
LIVEKIT_API_SECRET=your_livekit_secret
LIVEKIT_URL=wss://your-livekit-server.livekit.cloud
```

📖 **Full configuration reference (169 variables):** [docs/getting-started/configuration.md](docs/getting-started/configuration.md)

---

## 🛠️ Complete Tech Stack

### Backend

| Technology | Version | Purpose |
|-----------|---------|---------|
| **Go** | 1.25 | Primary backend language — all 3 services |
| **Gorilla Mux** | 1.8 | HTTP router with middleware support |
| **pgx/v5** | 5.x | PostgreSQL driver with connection pooling |
| **go-redis/v9** | 9.x | Redis client with TLS support |
| **golang-jwt/v5** | 5.x | JWT token creation and validation |
| **Zap** | 1.27 | Structured JSON logging (zero-allocation) |
| **gorilla/websocket** | 1.5 | WebSocket implementation |
| **livekit-server-sdk** | — | LiveKit room/token management |

### Frontend

| Technology | Version | Purpose |
|-----------|---------|---------|
| **React Native** | 0.81 | Cross-platform mobile framework |
| **Expo** | SDK 54 | Development toolchain and build system |
| **TypeScript** | 5.9 | Type safety across all frontend code |
| **Zustand** | 5.0 | Lightweight state management (22 stores) |
| **React Query** | 5.x | Server state, caching, background refetch |
| **React Navigation** | 7.x | Stack + tab navigation |
| **Expo Router** | 4.x | File-based routing |
| **Reanimated** | 3.x | 60fps native animations |
| **expo-av** | — | Audio/video playback |
| **expo-secure-store** | — | Encrypted token storage (iOS Keychain, Android Keystore) |

### Database & Storage

| Technology | Purpose |
|-----------|---------|
| **Supabase (PostgreSQL 15+)** | Primary database with RLS, Edge Functions, Realtime |
| **65 SQL migrations** | Schema versioning with up/down migrations |
| **Row-Level Security** | Database-level authorization policies |
| **Upstash Redis** | Pub/Sub, session cache, rate limiting, DLQ |
| **Cloudinary** | Media CDN with signed direct uploads and transforms |
| **Backblaze B2** | Long-term backup storage |

### Infrastructure & DevOps

| Technology | Purpose |
|-----------|---------|
| **Docker + Docker Compose** | 9-container production orchestration |
| **NGINX 1.25** | Reverse proxy, TLS, rate limiting, gzip |
| **Cloudflare** | CDN, WAF, DDoS protection, DNS |
| **Prometheus** | Metrics collection (15s scrape interval) |
| **Grafana** | Dashboard visualization and alerting |
| **Loki** | Log aggregation with LogQL |
| **GitHub Actions** | CI/CD pipeline |
| **Husky + lint-staged** | Pre-commit formatting and linting |

---

## 📁 Project Structure

```
Flicko/
│
├── 📱 mobile/                          # React Native mobile application
│   ├── app/                            # File-based routing (30+ screens)
│   │   ├── (auth)/                     # Login (15 KB), Register (22 KB)
│   │   ├── (tabs)/                     # Home (23 KB), Friends (14 KB), DMs (12 KB)
│   │   ├── server/                     # Server detail, settings, channels
│   │   ├── dm/                         # DM conversation screens
│   │   ├── settings/                   # Account, appearance, notifications
│   │   └── flicko-plus.tsx             # Premium subscription (26 KB)
│   ├── components/                     # 20 component directories
│   │   ├── messages/                   # MessageList, MessageInput, MessageBubble
│   │   ├── voice/                      # VoiceControls, VoiceChannel
│   │   ├── bots/                       # BotConfig, BotDashboard
│   │   ├── moderation/                 # Ban, Kick, Report panels
│   │   ├── server/                     # ServerHeader, MemberList
│   │   ├── channels/                   # ChannelList, CreateChannel
│   │   ├── profile/                    # ProfileCard, EditProfile
│   │   └── ui/                         # Button, Input, Modal, Badge
│   ├── constants/                      # Design tokens (Colors, spacing, typography)
│   ├── assets/                         # Fonts (GG Sans), icons, splash
│   └── services/                       # Mobile-specific services
│
├── 🔗 shared/                          # Cross-platform TypeScript code
│   ├── services/                       # 51 API service files
│   │   ├── auth.service.ts             # Authentication flows
│   │   ├── serverService.ts            # Server CRUD
│   │   ├── messageService.ts           # Message operations
│   │   ├── cloudinaryService.ts        # Signed media uploads (12 KB)
│   │   ├── mediaService.ts             # Media processing (20 KB)
│   │   └── ...46 more services
│   ├── stores/                         # 22 Zustand state stores
│   │   ├── authStore.ts                # Session, user, auth state (6.5 KB)
│   │   ├── serverManagementStore.ts    # Server state (10 KB)
│   │   ├── messageStore.ts             # Message cache
│   │   ├── voiceStore.ts               # Voice channel state
│   │   └── ...18 more stores
│   ├── hooks/                          # Shared React hooks
│   ├── types/                          # TypeScript models (342 lines)
│   └── utils/                          # Validation, error, logging, timestamps
│
├── ⚙️ backend/                         # Go monolith — Bot system & commands
│   ├── cmd/server/main.go              # Entry point (321 lines)
│   ├── internal/
│   │   ├── bots/                       # 8 built-in bots + registry
│   │   │   ├── moderation.go           # /ban, /kick, /mute, /warn, /purge
│   │   │   ├── automod.go              # 8 automated content filters
│   │   │   ├── welcome.go              # Join/leave messages
│   │   │   ├── leveling.go             # XP, ranks, leaderboard
│   │   │   ├── music.go                # /play, /skip, /queue
│   │   │   ├── ticket.go               # Support tickets
│   │   │   ├── poll.go                 # Polls
│   │   │   └── starboard.go            # Star reaction tracking
│   │   ├── commands/                   # Slash command router (197 lines)
│   │   ├── events/                     # Event bus with typed events
│   │   ├── handlers/                   # 7 HTTP handler files
│   │   ├── middleware/                 # 10-layer security middleware
│   │   │   ├── auth.go                 # JWT validation
│   │   │   ├── authorization.go        # RBAC with 26 permission types
│   │   │   ├── rate_limiter.go         # Redis-backed rate limiting
│   │   │   └── security.go             # CSRF, XSS, body limits
│   │   ├── models/                     # 22 Go model structs
│   │   └── services/                   # 95 service files (business logic)
│   │       ├── automod_service.go      # AutoMod engine (14.2 KB — largest)
│   │       ├── friend_service.go       # Friendship lifecycle (10.1 KB)
│   │       ├── dm_message_service.go   # Direct messaging (6.1 KB)
│   │       └── ...92 more services
│   └── migrations/                     # 3 SQL migration files
│
├── 🔌 services/                        # Go microservices (production split)
│   ├── ws-gateway/                     # WebSocket gateway service
│   │   ├── cmd/gateway/main.go         # Entry point
│   │   ├── internal/
│   │   │   ├── hub/                    # Connection hub (subscribe/broadcast)
│   │   │   ├── connection/             # Per-client connection handler
│   │   │   └── presence/               # Online status tracking
│   │   └── Dockerfile.prod             # Multi-stage build
│   ├── msg-service/                    # Message REST API service
│   │   ├── cmd/server/main.go          # Entry point
│   │   ├── internal/
│   │   │   └── batcher/                # Batch insert engine
│   │   └── Dockerfile.prod
│   ├── shared/                         # Shared Go packages
│   │   ├── auth/                       # JWT verification
│   │   ├── config/                     # Env var parsing
│   │   ├── errors/                     # Standardized error types
│   │   ├── logger/                     # Zap logger factory
│   │   ├── metrics/                    # Prometheus helpers
│   │   ├── protocol/                   # WebSocket opcodes
│   │   ├── ratelimit/                  # Token bucket limiter
│   │   ├── redis/                      # TLS-aware Redis client
│   │   └── validate/                   # Input validators
│   └── go.work                         # Go workspace file
│
├── 🐘 supabase/                        # Supabase configuration
│   ├── migrations/                     # 65 SQL migration files
│   │   ├── 001_initial_schema.sql      # Users, servers, channels, messages
│   │   ├── 002_bot_system_tables.sql   # 8 bot config tables (291 lines)
│   │   ├── 034_advanced_rls.sql        # RLS policies (13.3 KB)
│   │   ├── 035_permission_functions.sql # Permission calculation (6.9 KB)
│   │   └── ...61 more migrations
│   └── functions/                      # Supabase Edge Functions
│
├── 📧 mail-gateway/                    # Email service (Go)
├── 🔀 nginx/                           # NGINX reverse proxy config (232 lines)
├── 📊 monitoring/                      # Prometheus, Grafana, Loki configs
├── 🔧 scripts/                         # Deploy, setup, health check scripts
├── 📄 docs/                            # 87 documentation files
├── docker-compose.prod.yml             # Production stack (455 lines, 9 containers)
├── docker-compose.dev.yml              # Development stack
├── .env.example                        # Environment template (169 variables)
├── setup.sh                            # Interactive setup wizard (9.7 KB)
└── package.json                        # Root: Husky, Prettier, lint-staged
```

📖 **Full annotated tree:** [docs/architecture/folder-structure.md](docs/architecture/folder-structure.md)

---

## 🐳 Production Deployment

Flicko is designed for self-hosted deployment on a **single 8 GB RAM VPS** using Docker Compose.

### Deployment Steps

```bash
# 1. Initial server setup (once — installs Docker, firewall, fail2ban, SSH hardening)
sudo ./scripts/server-setup.sh

# 2. Clone and configure
git clone https://github.com/Santosh-Prasad-Verma/Flicko.git
cd Flicko
cp .env.production.example .env
# Fill in production credentials

# 3. Generate JWT keys
./scripts/generate-jwt-keys.sh

# 4. Obtain Cloudflare Origin TLS certificates
# Save as secrets/origin.pem and secrets/origin-key.pem

# 5. Deploy
docker compose -f docker-compose.prod.yml up -d --build

# 6. Verify
./scripts/check-health.sh
curl https://api.flicko.dev/api/v1/healthz/ready
```

### Container Resource Allocation

| Container | RAM Limit | CPU Limit | Network | Purpose |
|-----------|-----------|-----------|---------|---------|
| **NGINX** | 128 MB | 0.25 | `flicko_edge` | TLS termination, rate limiting, caching |
| **ws-gateway** | 1 GB | 1.0 | `flicko_internal` | 6,000 WebSocket connections |
| **msg-service** | 512 MB | 0.5 | `flicko_internal` | REST API, batch message insertion |
| **backend** | 512 MB | 0.5 | `flicko_internal` | Bot framework, slash commands |
| **Prometheus** | 512 MB | 0.25 | `flicko_monitor` | Metrics TSDB (15s scrape) |
| **Grafana** | 256 MB | 0.25 | `flicko_monitor` | Dashboards & alerting |
| **Loki** | 512 MB | 0.25 | `flicko_monitor` | Log aggregation |
| **Node Exporter** | 64 MB | 0.1 | `flicko_monitor` | Host system metrics |
| **NGINX Exporter** | 32 MB | 0.05 | `flicko_monitor` | NGINX request metrics |
| **Total** | **~3.5 GB** | **~3.15** | **3 networks** | *Leaves ~4.5 GB for OS + buffers* |

### Docker Security Hardening

All Go service containers run with:
- `read_only: true` — Read-only container filesystem
- `no-new-privileges: true` — Prevents privilege escalation
- `USER nonroot:nonroot` — Non-root process
- Multi-stage builds — Only compiled binary in final image (no source code)
- Alpine 3.19 base — Minimal attack surface (~5 MB)

### Recommended VPS Providers

| Provider | Plan | RAM / CPU | Monthly Cost |
|----------|------|-----------|-------------|
| **Hetzner** | CX31 | 8 GB / 2 vCPU | ~€8.50 |
| **DigitalOcean** | Droplet | 8 GB / 2 vCPU | ~$48 |
| **Azure** | B2s | 4 GB / 2 vCPU | Free with $100 student credit |

📖 **Full deployment guide:** [docs/deployment/overview.md](docs/deployment/overview.md)

---

## 🔒 Security Architecture

Flicko implements **defense-in-depth** across 5 independent security layers:

```
Layer 0: Cloudflare (Edge)
    ├── DDoS auto-mitigation (unlimited, unmetered)
    ├── WAF rules (SQL injection, XSS, bot detection)
    ├── JavaScript challenge + CAPTCHA for suspicious traffic
    └── Origin TLS (encrypted Cloudflare ↔ NGINX)

Layer 1: NGINX (Reverse Proxy)
    ├── TLS termination with Cloudflare Origin certificates
    ├── Rate limiting — 4 independent zones:
    │    ├── api_limit:    30 requests/second
    │    ├── ws_limit:      5 connections/second
    │    ├── upload_limit:  2 requests/second
    │    └── auth_limit:    5 requests/minute
    ├── Request body limit: 25 MB max
    └── Slowloris protection: 10s read/send timeouts

Layer 2: Go Application
    ├── JWT authentication (HMAC-SHA256 / Ed25519)
    ├── CSRF protection (X-CSRF-Token, ≥16 chars)
    ├── XSS input sanitization on all inputs
    ├── File upload validation (MIME type + size)
    ├── Redis-backed distributed rate limiting
    ├── RBAC with 26 permission types (bitfield)
    ├── Sensitive header redaction in all logs
    └── AES-256-GCM encryption at rest

Layer 3: Database (PostgreSQL)
    ├── Row-Level Security (RLS) policies
    ├── Connection encryption (sslmode=require)
    ├── Supavisor connection pooling
    └── CHECK constraints on all inputs

Layer 4: Infrastructure (Docker)
    ├── 3 isolated Docker networks (edge/internal/monitor)
    ├── Read-only container filesystems
    ├── Non-root container processes
    ├── Memory + CPU resource limits
    └── fail2ban + SSH key-only authentication
```

### Permission System (26 Types)

Flicko uses **Discord-style bitfield permissions** with channel-level overwrites:

| Category | Permissions |
|----------|------------|
| **Channel** | View Channel, Manage Channel, Delete Channel |
| **Server** | View Server, Manage Server, Delete Server, Manage Members, Manage Roles |
| **Message** | View Messages, Post Messages, Delete Messages, Edit Messages |
| **Moderation** | Ban Members, Mute Members, Moderate |
| **Bot** | Execute Commands, Manage Bots |
| **Voice** | Stream Video, View Streams |

Permissions are enforced at **two independent layers**: application middleware (Go) and database (PostgreSQL RLS policies with `calculate_permissions()` functions).

📖 **Full security documentation:** [docs/security/overview.md](docs/security/overview.md)

---

## 📊 Monitoring & Observability

The production stack includes a complete observability pipeline:

| Component | Purpose | Metrics/Logs Collected |
|-----------|---------|----------------------|
| **Prometheus** | Metrics TSDB | `ws_connections_total`, `msg_batch_latency`, `go_goroutines`, CPU, RAM, disk |
| **Grafana** | Dashboards | System overview, WebSocket health, API latency, NGINX traffic |
| **Loki** | Log aggregation | JSON structured logs from all Go services + NGINX access logs |
| **Node Exporter** | Host metrics | CPU per core, memory, disk I/O, network, file descriptors |
| **NGINX Exporter** | Proxy metrics | Requests/sec, status codes, upstream latency |

All Go services output **structured JSON logs** via Zap:
```json
{
  "level": "info",
  "msg": "message created",
  "user_id": "abc-123",
  "channel_id": "def-456",
  "request_id": "req-789",
  "ts": "2026-04-11T00:00:00Z"
}
```

📖 **Full monitoring guide:** [docs/deployment/monitoring.md](docs/deployment/monitoring.md)

---

## 🤖 Bot System Deep Dive

Flicko includes **8 built-in bots** registered at startup via the Bot Registry pattern:

```go
// backend/cmd/server/main.go — Bot initialization
registry := bots.NewRegistry(db, redis, logger)
registry.Register(bots.NewModerationBot(services))
registry.Register(bots.NewAutoModBot(services))
registry.Register(bots.NewWelcomeBot(services))
registry.Register(bots.NewLevelingBot(services))
registry.Register(bots.NewMusicBot(services))
registry.Register(bots.NewTicketBot(services))
registry.Register(bots.NewPollBot(services))
registry.Register(bots.NewStarboardBot(services))
registry.StartAll()
```

### AutoMod Engine (8 Content Filters)

The AutoMod bot (`automod_service.go` — 14.2 KB, the largest service file) processes every message through configurable filters:

| Filter | Detection Method | Action |
|--------|-----------------|--------|
| **Invite Links** | Regex: `discord.gg/`, `invite.gg/`, etc. | Delete + warn |
| **External Links** | URL pattern matching with allowlist | Delete + warn |
| **Excessive Caps** | % uppercase threshold (configurable, default 70%) | Delete + warn |
| **Emoji Spam** | Emoji count per message | Delete + warn |
| **Mass Mentions** | @mention count limit | Delete + warn |
| **Duplicate Messages** | Content hash comparison in time window | Delete + warn |
| **Word Blacklist** | Glob pattern matching | Delete + warn |
| **Spam Detection** | Rate-based (similar messages in short window) | Delete + mute |

### Warning Escalation

| Warning Count | Automatic Action |
|--------------|-----------------|
| 1 | Warning recorded, DM sent to user |
| 3 | Automatic 1-hour mute |
| 5 | Automatic kick from server |
| 7+ | Automatic permanent ban |

📖 **Full bot documentation:** [docs/features/bot-system.md](docs/features/bot-system.md)

---

## 💾 Database Architecture

**65 Supabase migrations** define the complete schema:

### Core Tables

| Table | Purpose | Key Columns |
|-------|---------|-------------|
| `users` | User accounts | id, username, email, avatar_url, banner_url, theme |
| `servers` | Server (guild) metadata | id, name, owner_id, icon_url, description |
| `channels` | Text/voice/category channels | id, server_id, type, name, position, parent_id |
| `messages` | Chat messages | id, channel_id, author_id, content, reply_to_id |
| `members` | Server membership | server_id, user_id, nickname, joined_at |
| `roles` | Role definitions | server_id, name, color, position, permissions (bigint) |
| `invites` | Server invite codes | code, server_id, max_uses, uses, expires_at |
| `friends` | Friend relationships | user_id, friend_user_id, status |
| `reactions` | Message reactions | message_id, user_id, emoji |
| `voice_states` | Voice channel state | user_id, channel_id, self_mute, self_deaf |
| `threads` | Thread channels | parent_channel_id, parent_message_id, archived |

### Bot System Tables

| Table | Purpose |
|-------|---------|
| `bots`, `bot_guilds` | Bot registry and per-server enablement |
| `mod_settings` | Moderation configuration (log channel, DM settings) |
| `automod_settings` | AutoMod filter toggles and thresholds |
| `welcome_settings` | Welcome/goodbye message templates |
| `level_settings`, `user_xp` | XP configuration and user progress |
| `ticket_settings`, `tickets` | Support ticket system |
| `starboard_settings`, `starboard_entries` | Star reaction tracking |

📖 **Full database documentation:** [docs/database/overview.md](docs/database/overview.md) · [ERD Diagram](docs/diagrams/database-erd.md)

---

## 🧪 Testing

### Go Backend (42 Test Files)

```bash
# Run all tests
cd backend && go test -v ./...

# Run with coverage report
cd backend && go test -coverprofile=coverage.out ./...
go tool cover -html=coverage.out -o coverage.html

# Run specific test suite
cd backend && go test -v -run TestAutoModService ./internal/services/
```

### TypeScript (Jest)

```bash
cd mobile && npx jest --coverage
```

### Health Checks

```bash
# Docker container health
docker compose -f docker-compose.prod.yml ps

# Application health endpoints
curl https://api.flicko.dev/api/v1/health
curl https://api.flicko.dev/api/v1/healthz/ready

# Script-based check
./scripts/check-health.sh
```

📖 **Full testing guide:** [docs/testing/overview.md](docs/testing/overview.md)

---

## 📖 Documentation

The `/docs` directory contains **87 professionally written markdown files** across 12 categories:

| Section | Files | Description |
|---------|-------|-------------|
| 📘 [Getting Started](docs/getting-started/overview.md) | 6 | Prerequisites, installation, configuration (169 env vars), quick start, troubleshooting |
| 🏗️ [Architecture](docs/architecture/system-overview.md) | 9 | System design, tech stack, folder structure, data flow, auth flow, API design, state management |
| ✨ [Features](docs/features/feature-index.md) | 10 | Feature index + 9 deep-dives (messaging, voice, bots, servers, moderation, DMs, social, media, premium) |
| 🔌 [API Reference](docs/api/api-overview.md) | 8 | Endpoints, authentication, error codes, rate limiting + 4 endpoint groups |
| 🐘 [Database](docs/database/overview.md) | 7 | Schema, ERD, models, relationships, indexes, migrations, seeding |
| ⚙️ [Backend](docs/backend/overview.md) | 8 | Services (95 files), middleware (10 layers), controllers, models, utils, error handling |
| 📱 [Frontend](docs/frontend/overview.md) | 7 | Components (20 dirs), routes (30+ screens), state management (22 stores), styling |
| 🐳 [Deployment](docs/deployment/overview.md) | 6 | Docker (9 containers), monitoring, CI/CD, cloud options, environment setup |
| 🔒 [Security](docs/security/overview.md) | 5 | 5-layer defense, auth, RBAC (26 permissions), data protection, vulnerabilities |
| 🧪 [Testing](docs/testing/overview.md) | 5 | Unit tests (42 files), integration tests, E2E, coverage targets |
| 🛠️ [Development](docs/development/coding-standards.md) | 5 | Coding standards, git workflow, dev environment, scripts, debugging |
| 📐 [Diagrams](docs/diagrams/README.md) | 7 | 6 Mermaid diagrams: system architecture, DB ERD, API flow, auth flow, deployment, components |

📖 **Documentation index:** [docs/README.md](docs/README.md)

---

## 🤝 Contributing

We welcome contributions of all kinds! Please read our [Contributing Guide](docs/CONTRIBUTING.md) and [Code of Conduct](docs/CODE_OF_CONDUCT.md) before getting started.

### Development Workflow

```bash
# 1. Fork the repository and clone
git clone https://github.com/YOUR_USERNAME/Flicko.git
cd Flicko && npm install

# 2. Create a feature branch
git checkout -b feature/your-amazing-feature

# 3. Make changes and ensure quality
npm run format                          # Prettier formatting
cd backend && gofmt -w . && go test ./... # Go formatting + tests
cd mobile && npx eslint . --ext .ts,.tsx  # TypeScript linting

# 4. Commit with conventional commit messages
git commit -m "feat: add voice channel muting support"

# 5. Push and open a Pull Request
git push origin feature/your-amazing-feature
```

### Commit Convention

| Prefix | Usage |
|--------|-------|
| `feat:` | New feature |
| `fix:` | Bug fix |
| `docs:` | Documentation update |
| `refactor:` | Code refactoring |
| `test:` | Adding or updating tests |
| `chore:` | Dependencies, CI, tooling |

---

## 📊 Project Stats

| Metric | Count |
|--------|-------|
| **Go backend service files** | 95 |
| **Frontend API service files** | 51 |
| **Zustand state stores** | 22 |
| **Database migrations** | 65 (Supabase) + 3 (backend) |
| **Go unit test files** | 42 |
| **Built-in bots** | 8 |
| **Permission types** | 26 |
| **Middleware layers** | 10 |
| **Go model structs** | 22 |
| **Mobile app screens** | 30+ |
| **Component directories** | 20 |
| **Environment variables** | 169 |
| **Docker containers (prod)** | 9 |
| **Docker networks** | 3 (isolated) |
| **Feature count** | 30+ |
| **Documentation files** | 87 |
| **Lines in `docker-compose.prod.yml`** | 455 |
| **Lines in `main.go` (backend)** | 321 |
| **AutoMod service (largest file)** | 14.2 KB |

---

## 📜 License

This project is licensed under the **MIT License** — see the [LICENSE](LICENSE) file for details.

---

<p align="center">
  <img src="mobile/assets/Flicko_icon.png" alt="Flicko" width="48" height="48" style="border-radius: 12px;" />
</p>

<p align="center">
  <strong>Flicko — Open-source communication, reimagined.</strong>
</p>

<p align="center">
  <sub>
    Made with ❤️ by <a href="https://github.com/Santosh-Prasad-Verma">Santosh Prasad Verma</a> &amp; <a href="https://github.com/Santosh-Prasad-Verma/Flicko/graphs/contributors">contributors</a>
  </sub>
</p>

<p align="center">
  <a href="#-quick-start">Quick Start</a> ·
  <a href="docs/README.md">Documentation</a> ·
  <a href="docs/features/feature-index.md">Features</a> ·
  <a href="docs/CONTRIBUTING.md">Contribute</a> ·
  <a href="docs/CHANGELOG.md">Changelog</a>
</p>
