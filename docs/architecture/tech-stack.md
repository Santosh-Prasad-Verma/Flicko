# Tech Stack

> **Reading time:** ~15 minutes · **Audience:** All Developers · **Last Updated:** 2026-04-24

Complete documentation of every technology, framework, library, and cloud service used in Flicko with version numbers, why each was chosen, and where it's used in the codebase.

---

## Backend Stack

### Go (v1.25)
**Role:** Primary language for all three backend microservices.
**Why:** Go's goroutine-based concurrency handles thousands of concurrent WebSocket connections with minimal memory overhead (~8 KB per goroutine). Single-binary compilation enables Alpine-based Docker images as small as 15 MB. Strong typing catches bugs at compile time. Excellent standard library for HTTP, crypto, and JSON.
**Where:** `backend/`, `services/ws-gateway/`, `services/msg-service/`, `services/shared/`, `mail-gateway/`

### Key Go Dependencies

| Package | Version | Purpose | Used In |
|---------|---------|---------|---------|
| `github.com/gorilla/mux` | v1.8.1 | HTTP router with path variables | All 3 services |
| `github.com/gorilla/websocket` | v1.5.3 | WebSocket upgrade and connection management | ws-gateway |
| `github.com/go-redis/redis/v9` | v9.7.1 | Redis client with TLS, Pub/Sub, pipelining | All 3 services |
| `github.com/golang-jwt/jwt/v5` | v5.2.1 | JWT parsing and HMAC-SHA256 validation | All 3 services |
| `github.com/joho/godotenv` | v1.5.1 | Load .env file into environment | All 3 services |
| `go.uber.org/zap` | v1.27.0 | Structured JSON logging (production-grade) | All 3 services |
| `github.com/lib/pq` | v1.10.9 | PostgreSQL driver for `database/sql` | All 3 services |
| `github.com/livekit/server-sdk-go` | v2.4.0 | LiveKit room token generation | backend |
| `github.com/stretchr/testify` | v1.11.1 | Test assertions (assert, require, mock) | 42 test files |
| `github.com/microcosm-cc/bluemonday` | v1.0.27 | HTML/XSS sanitization | backend middleware |
| `github.com/rs/cors` | v1.11.1 | CORS header management | All 3 services |
| `golang.org/x/crypto` | v0.32.0 | bcrypt, scrypt, and additional crypto | backend |
| `github.com/google/uuid` | v1.6.0 | UUID generation for request IDs, resource IDs | All 3 services |

---

## Frontend Stack

### Flutter (v3.22+)
**Role:** Primary framework for the cross-platform mobile application.
**Why:** Compiles to native ARM/x86 code for maximum performance (60/120fps). Single Dart codebase for both iOS and Android. Rich, customizable widget library allows for pixel-perfect Discord-like UI. Hot reload enables rapid iteration.
**Where:** `mobile/`

### Riverpod / GoRouter
**Role:** State management, dependency injection, and declarative routing for Flutter.
**Why:** Riverpod provides a compile-safe, testable way to manage reactive state across the app. GoRouter simplifies complex deep-linking and nested navigation structures required for a server/channel multi-pane interface.
**Where:** `mobile/lib/`

### Key Frontend Dependencies

| `flutter_riverpod` | 3.x | Reactive state management & DI | `mobile/lib/features/` |
| `go_router` | 17.x | Declarative routing & deep linking | `mobile/lib/core/router/app_router.dart` |
| `supabase_flutter` | 2.x | Supabase client (auth, realtime, storage) | `mobile/lib/core/services/` |
| `livekit_client` | 2.x | WebRTC voice/video implementation | `mobile/lib/features/voice/` |
| `stripe_flutter` | 12.x | Native payment sheet integration | `mobile/lib/features/premium/` |
| `cached_network_image` | 3.x | Efficient image caching and loading | `mobile/lib/common/widgets/` |
| `flutter_secure_storage` | 9.x | Encrypted storage for JWT tokens | `mobile/lib/core/services/` |
| `local_auth` | 2.x | Biometric auth (Face ID, Fingerprint) | `mobile/lib/features/auth/` |
| `appwrite` | 13.x | Appwrite SDK for storage and buckets | `mobile/lib/data/services/` |
| `flutter_vibrate`| — | Haptic feedback for interactions | `lib/common/` |

### Dart (v3.4+)
**Role:** Primary language for all mobile application code.
**Why:** Built-in sound null safety prevents null-reference crashes. Ahead-of-Time (AOT) compilation to native machine code ensures consistent performance. Dart's isolate model allows for high-performance background processing without blocking the UI thread.
**Where:** `mobile/lib/`

---

## Database Stack

### PostgreSQL 15+ (via Supabase)
**Role:** Primary relational database for all persistent data.
**Why:** ACID transactions ensure data consistency. Relational model naturally represents Discord-like hierarchies (servers → channels → messages). Row-Level Security enforces access rules at the database layer. Full-text search via `tsvector` indexes powers message search. Supabase provides managed hosting with connection pooling, backups, and a REST API.
**Where:** 94 migrations in `supabase/migrations/`, 3 in `backend/migrations/`

**Key PostgreSQL Features Used:**
- `gen_random_uuid()` — UUID primary key generation
- `tsvector` / `tsquery` — Full-text search on messages
- `JSONB` — Flexible configuration storage (bot settings)
- Row-Level Security — Database-enforced access control
- `CHECK` constraints — Input validation at the database layer
- `ON DELETE CASCADE` — Automatic cleanup of child records
- PostgreSQL functions — `calculate_permissions()`, `has_permission()`

### Supabase Auth
**Role:** User authentication and JWT token management.
**Why:** Handles registration, login, password reset, OAuth, JWT issuance, and token refresh out of the box. Backend services only need to validate JWTs — they don't manage passwords or sessions directly.
**Providers:** Email/password, Google, GitHub, Discord, Apple

### Supabase Edge Functions
**Role:** Serverless functions for isolated tasks.
**Functions deployed:**
- `gif-search` — Proxies GIPHY API requests (avoids exposing GIPHY API key to mobile client)
- `push-notification` — Delivers push notifications via Firebase Cloud Messaging (FCM) proxy

---

## Cache & Messaging

### Redis (via Upstash)
**Role:** In-memory data store for Pub/Sub, caching, rate limiting, and dead letter queue.
**Why:** Sub-millisecond latency for Pub/Sub message delivery between services. Upstash provides serverless Redis with TLS encryption and a generous free tier (10K commands/day). Redis's Pub/Sub pattern is ideal for fire-and-forget real-time events.
**Where:** Used by all 3 Go services via `services/shared/redis/`

---

## Media & Communication

### Appwrite Storage
**Role:** Cloud-based S3-compatible storage for media and user assets.
**Why:** Simplified file management with built-in permission systems. Multi-platform SDKs make it easy to integrate with Flutter. Managed buckets allow for separation of avatars, server icons, and message attachments. 
**Where:** `mobile/lib/data/services/appwrite_storage_service.dart`

### LiveKit Cloud
**Role:** WebRTC Selective Forwarding Unit for voice and video.
**Why:** SFU architecture scales better than peer-to-peer for group calls. Open-source with self-hosting option. Unified Flutter SDK. Handles codec negotiation, adaptive bitrate, and participant management automatically.
**Where:** `backend/internal/services/voice_service.go`, `mobile/lib/features/voice/`

### Stripe
**Role:** Payment processing for Flicko Plus premium subscription.
**Why:** PCI-compliant payment infrastructure. Flutter SDK provides native payment sheets. Webhook integration for subscription lifecycle events (created, renewed, cancelled).
**Where:** `mobile/lib/core/services/stripe_service.dart`, `mobile/lib/features/premium/premium_plus_screen.dart`

---

## Infrastructure

### Docker & Docker Compose
**Role:** Containerization and orchestration for production deployment.
**Why:** Reproducible deployments across environments. Multi-stage builds create optimized Alpine-based Go images (~15 MB). Docker Compose manages 9 containers with resource limits, health checks, and 3 isolated networks.
**Where:** `docker-compose.prod.yml` (455 lines), `docker-compose.dev.yml`, service Dockerfiles

### NGINX 1.25
**Role:** Reverse proxy, TLS termination, rate limiting, and WebSocket upgrade.
**Why:** Battle-tested reverse proxy with native WebSocket support. 4 rate limit zones protect against abuse. TLS termination with Cloudflare Origin certificates. Gzip compression reduces bandwidth. JSON-formatted access logs for Loki ingestion.
**Where:** `nginx/nginx.conf` (232 lines)

### Cloudflare
**Role:** DNS, CDN, WAF, DDoS protection, and bot challenge.
**Why:** Free tier provides essential security (WAF rules, DDoS mitigation) and performance (CDN caching, Brotli compression). Acts as the outermost defense layer. Provides Origin certificates for NGINX TLS.

---

## Monitoring Stack

| Tool | Version | Role | Where |
|------|---------|------|-------|
| **Prometheus** | latest | Metrics time-series database, 15s scrape interval | `monitoring/prometheus/` |
| **Grafana** | latest | Dashboards, alerting, auto-provisioned datasources | `monitoring/grafana/` |
| **Loki** | latest | Log aggregation with 30-day retention | `monitoring/loki/` |
| **Node Flutterrter** | latest | Host CPU/RAM/disk/network metrics | Docker container |
| **NGINX Flutterrter** | latest | Request throughput and status codes | Docker container |

---

## Development Tools

| Tool | Purpose | Configuration |
|------|---------|--------------|
| **Husky** | Git pre-commit hooks | `.husky/pre-commit` |
| **Dart Format** | Code formatting | `dart format .` |
| **flutter_test** | Flutter unit & widget testing | `lib/features/` |
| **gofmt** | Go code formatting (enforced) | Husky pre-commit |
| **testify** v1.11.1 | Go test assertions | Used in 42 test files |
| **Zap** | Structured JSON logging | All Go services |

---

## Related Documentation

- [Architecture: System Overview](system-overview.md) — How these technologies work together
- [Getting Started: Prerequisites](../getting-started/prerequisites.md) — Installation for each technology
- [Getting Started: Configuration](../getting-started/configuration.md) — Environment variables for each service
- [Backend: Overview](../backend/overview.md) — Go dependency usage details

---

*Last Updated: 2026-04-24 | Version: 1.1.0 | Maintained by: Flicko Team*
