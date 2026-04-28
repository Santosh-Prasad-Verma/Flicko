# Flicko - Project Structure

## Directory Organization

Flicko is organized as a polyglot monorepo with clear separation between mobile client, backend services, infrastructure, and documentation.

### Root Structure
```
Flicko/
├── mobile/              # Flutter mobile application (iOS + Android)
├── backend/             # Go monolith - Bot system & commands
├── services/            # Go microservices (ws-gateway, msg-service)
├── supabase/            # Database migrations & Edge Functions
├── mail-gateway/        # Email service (Go)
├── nginx/               # Reverse proxy configuration
├── monitoring/          # Prometheus, Grafana, Loki configs
├── scripts/             # Deployment & utility scripts
├── docs/                # 121 documentation files
├── secrets/             # JWT keys (gitignored)
└── docker-compose.*.yml # Container orchestration
```

## Core Components

### 1. Mobile Application (`mobile/`)
**Type**: Flutter 3.22+ / Dart 3.4+  
**Purpose**: Cross-platform mobile client for iOS and Android

```
mobile/
├── lib/
│   ├── features/        # Feature-first modular architecture
│   │   ├── auth/        # Authentication & onboarding
│   │   ├── servers/     # Server management & channels
│   │   ├── messaging/   # Real-time chat & DMs
│   │   ├── voice/       # Voice/video channels
│   │   ├── profile/     # User profiles & settings
│   │   └── social/      # Friends & presence
│   ├── core/            # Shared utilities
│   │   ├── models/      # Data models
│   │   ├── services/    # API clients, WebSocket
│   │   ├── providers/   # Riverpod state management (50+)
│   │   └── theme/       # Design system
│   └── main.dart        # App entry point
├── assets/              # Images, fonts, translations
├── android/             # Android native configuration
├── ios/                 # iOS native configuration
└── pubspec.yaml         # Flutter dependencies
```

**Key Patterns**:
- Feature-first architecture with isolated modules
- Riverpod for state management and dependency injection
- GoRouter for declarative navigation (30+ routes)
- Repository pattern for data access
- 86 production-ready screens

### 2. Backend Monolith (`backend/`)
**Type**: Go 1.25.7  
**Purpose**: Bot framework, slash commands, RBAC

```
backend/
├── cmd/
│   └── server/          # Main entry point
├── internal/
│   ├── bots/            # 8 built-in bots + registry
│   │   ├── moderation.go
│   │   ├── automod.go
│   │   ├── welcome.go
│   │   ├── leveling.go
│   │   ├── music.go
│   │   ├── ticket.go
│   │   ├── poll.go
│   │   └── starboard.go
│   ├── middleware/      # 10-layer security middleware
│   ├── services/        # 95 service files (business logic)
│   ├── handlers/        # HTTP request handlers
│   ├── models/          # Domain models
│   └── database/        # Database access layer
├── migrations/          # 3 SQL migration files
├── go.mod               # Go dependencies
└── Dockerfile           # Production container image
```

**Key Patterns**:
- Bot Registry pattern for extensible bot system
- Middleware chain for security (JWT, CSRF, rate limiting)
- Service layer for business logic isolation
- Repository pattern for database access
- Structured logging with Zap

### 3. Microservices (`services/`)
**Type**: Go 1.25.7  
**Purpose**: High-performance stateless services

```
services/
├── ws-gateway/          # WebSocket gateway
│   ├── cmd/
│   ├── internal/
│   │   ├── manager/     # Connection manager (6,000 max)
│   │   ├── protocol/    # WebSocket protocol
│   │   └── pubsub/      # Redis pub/sub integration
│   └── Dockerfile.prod
├── msg-service/         # Message REST API
│   ├── cmd/
│   ├── internal/
│   │   ├── batch/       # Batch insert engine
│   │   ├── handlers/    # HTTP handlers
│   │   └── middleware/  # Idempotency, rate limiting
│   └── Dockerfile.prod
├── shared/              # Shared Go packages
│   ├── auth/            # JWT validation
│   ├── config/          # Configuration loading
│   ├── logger/          # Structured logging
│   ├── metrics/         # Prometheus metrics
│   ├── ratelimit/       # Redis-backed rate limiting
│   └── redis/           # Redis client wrapper
└── go.work              # Go workspace configuration
```

**Key Patterns**:
- Stateless design for horizontal scalability
- Connection pooling for database and Redis
- Batch processing for message insertion
- Idempotency keys for duplicate prevention
- Prometheus metrics instrumentation

### 4. Database Layer (`supabase/`)
**Type**: PostgreSQL 15+ with Supabase  
**Purpose**: Data persistence, auth, Edge Functions

```
supabase/
├── migrations/          # 94 SQL migration files
│   ├── 001_create_profiles_table.sql
│   ├── 002_create_servers_table.sql
│   ├── 034_advanced_rls_policies.sql
│   ├── 062_bot_system_tables.sql
│   └── ...90 more migrations
├── functions/           # Supabase Edge Functions
│   ├── gif-search/      # GIPHY API integration
│   ├── push-notify/     # Push notification delivery
│   └── voice-token/     # LiveKit token generation
└── config.toml          # Supabase configuration
```

**Key Patterns**:
- Sequential migration numbering for version control
- Row-Level Security (RLS) policies for authorization
- Triggers for automated workflows
- Indexes for query optimization
- Edge Functions for serverless compute

### 5. Infrastructure (`nginx/`, `monitoring/`, `docker-compose.*.yml`)

#### NGINX Reverse Proxy
```
nginx/
├── nginx.conf           # Main configuration (232 lines)
├── conf.d/
│   ├── flicko.conf      # Routing rules
│   └── ssl.conf         # TLS configuration
└── ssl/
    ├── origin.pem       # Cloudflare Origin certificate
    └── origin-key.pem   # Private key
```

#### Monitoring Stack
```
monitoring/
├── prometheus.yml       # Metrics scraping configuration
├── loki-config.yml      # Log aggregation configuration
├── alerts.yml           # Alerting rules
└── grafana/
    ├── dashboards/      # Pre-built dashboards
    └── provisioning/    # Auto-provisioning configs
```

#### Container Orchestration
- `docker-compose.prod.yml`: 9 containers, 3 networks, 455 lines
- `docker-compose.dev.yml`: Development environment
- `docker-compose.zero.yml`: Minimal local setup

## Architectural Patterns

### Microservices Architecture
```
Client (Flutter) → Cloudflare → NGINX → [ws-gateway | msg-service | backend]
                                           ↓           ↓           ↓
                                        Supabase ← Redis (Upstash)
```

**Three Services Rationale**:
1. **ws-gateway**: Stateful WebSocket connections, scales independently
2. **msg-service**: Stateless REST API, horizontally scalable
3. **backend**: Monolithic bot system, in-process event bus

### Network Isolation
- **flicko_edge**: Internet-facing (NGINX only)
- **flicko_internal**: Services, database, Redis (no internet)
- **flicko_monitor**: Observability stack (no internet)

### Security Layers
1. **Cloudflare**: DDoS mitigation, WAF, CDN
2. **NGINX**: TLS termination, rate limiting (4 zones)
3. **Application**: JWT auth, CSRF, input sanitization
4. **Database**: Row-Level Security policies
5. **Docker**: Read-only filesystems, non-root processes

### Data Flow

#### Real-Time Messaging
```
Client → WebSocket → ws-gateway → Redis Pub/Sub → ws-gateway → Clients
                         ↓
                    msg-service → Supabase (batch insert)
```

#### REST API Request
```
Client → HTTPS → NGINX → msg-service → Supabase
                   ↓
              Rate Limit (Redis)
                   ↓
              JWT Validation
```

#### Bot Command
```
Client → HTTPS → NGINX → backend → Bot Registry → Bot Handler
                                        ↓
                                   Supabase + Redis
```

## Component Relationships

### Mobile ↔ Backend
- **WebSocket**: Real-time messaging, presence, typing indicators
- **REST API**: CRUD operations, file uploads, authentication
- **LiveKit**: Direct WebRTC connection for voice/video

### Backend Services ↔ Database
- **Supabase**: Primary data store with connection pooling
- **Redis**: Pub/Sub, rate limiting, session cache
- **Appwrite**: Media storage (images, videos, attachments)

### Monitoring ↔ Services
- **Prometheus**: Scrapes metrics from all Go services (15s interval)
- **Loki**: Aggregates JSON logs from all containers
- **Grafana**: Visualizes metrics and logs with dashboards

## Documentation Structure (`docs/`)

```
docs/
├── getting-started/     # 6 files - Installation, configuration
├── architecture/        # 9 files - System design, tech stack
├── features/            # 10 files - Feature deep-dives
├── api/                 # 8 files - API reference, endpoints
├── database/            # 7 files - Schema, migrations, ERD
├── backend/             # 8 files - Services, middleware
├── frontend/            # 7 files - Components, state management
├── deployment/          # 6 files - Docker, monitoring, CI/CD
├── security/            # 5 files - Auth, RBAC, data protection
├── testing/             # 5 files - Unit, integration, E2E tests
├── development/         # 5 files - Coding standards, git workflow
└── diagrams/            # 7 files - Mermaid diagrams
```

Total: **121 professionally written documentation files**
