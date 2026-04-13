# Tech Stack

> **Reading time:** ~15 minutes · **Audience:** All Developers · **Last Updated:** 2026-04-11

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

### React Native (v0.81)
**Role:** Cross-platform mobile framework for iOS and Android.
**Why:** Single TypeScript codebase for both platforms. Large ecosystem of native modules. Hot reload for rapid development. React's component model enables reusable UI components.
**Where:** `mobile/`

### Expo SDK 54
**Role:** Build toolchain, development server, and native module management for React Native.
**Why:** Simplifies React Native development with managed workflows, OTA updates, and pre-configured native modules for camera, file system, biometric auth, secure storage, and notifications. File-based routing via Expo Router eliminates manual route configuration.
**Where:** `mobile/`

### Key Frontend Dependencies

| Package | Version | Purpose | Used In |
|---------|---------|---------|---------|
| `expo-router` | 4.x | File-based routing with deep linking | `mobile/app/` |
| `@react-navigation/native` | 7.x | Navigation primitives (stack, tab, drawer) | `mobile/app/` |
| `zustand` | 5.0 | Lightweight state management (22 stores) | `shared/stores/` |
| `@tanstack/react-query` | 5.x | Server state caching, background refetch | `mobile/`, `shared/` |
| `@supabase/supabase-js` | 2.x | Supabase client (auth, realtime, storage) | `shared/services/` |
| `@livekit/react-native` | 2.x | WebRTC voice/video client | `mobile/app/voice/` |
| `@stripe/stripe-react-native` | 0.x | Payment sheet for Flicko Plus | `mobile/app/flicko-plus.tsx` |
| `react-native-reanimated` | 3.x | 60fps native animations | `mobile/components/` |
| `react-native-gesture-handler` | 2.x | Native gesture recognition | `mobile/components/` |
| `expo-secure-store` | — | Encrypted storage for JWT tokens | `shared/services/auth.service.ts` |
| `expo-local-authentication` | — | Biometric auth (Face ID, fingerprint) | `mobile/app/settings/` |
| `expo-image-picker` | — | Camera and gallery access | `shared/services/mediaService.ts` |
| `expo-notifications` | — | Push notification handling | `shared/services/notificationService.ts` |
| `expo-haptics` | — | Haptic feedback for UI interactions | `mobile/components/` |

### TypeScript (v5.9)
**Role:** Type-safe JavaScript for all frontend code.
**Why:** Catches type errors at compile time, provides IntelliSense/autocompletion, and serves as documentation via interfaces. All 51 service files and 22 stores use TypeScript interfaces for data shapes.
**Where:** `mobile/`, `shared/`

---

## Database Stack

### PostgreSQL 15+ (via Supabase)
**Role:** Primary relational database for all persistent data.
**Why:** ACID transactions ensure data consistency. Relational model naturally represents Discord-like hierarchies (servers → channels → messages). Row-Level Security enforces access rules at the database layer. Full-text search via `tsvector` indexes powers message search. Supabase provides managed hosting with connection pooling, backups, and a REST API.
**Where:** 65 migrations in `supabase/migrations/`, 3 in `backend/migrations/`

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
- `push-notification` — Delivers push notifications via Expo's push service

---

## Cache & Messaging

### Redis (via Upstash)
**Role:** In-memory data store for Pub/Sub, caching, rate limiting, and dead letter queue.
**Why:** Sub-millisecond latency for Pub/Sub message delivery between services. Upstash provides serverless Redis with TLS encryption and a generous free tier (10K commands/day). Redis's Pub/Sub pattern is ideal for fire-and-forget real-time events.
**Where:** Used by all 3 Go services via `services/shared/redis/`

---

## Media & Communication

### Cloudinary
**Role:** Cloud-based image and video CDN with direct upload support.
**Why:** Direct upload (client → Cloudinary, bypassing the backend) reduces server load. HMAC-SHA256 signed uploads ensure security without exposing credentials. Built-in image transformations (resize, crop, format conversion) are applied via URL parameters. Global CDN ensures fast media delivery worldwide.
**Where:** `backend/internal/handlers/cloudinary.go`, `shared/services/cloudinaryService.ts`

### LiveKit Cloud
**Role:** WebRTC Selective Forwarding Unit for voice and video.
**Why:** SFU architecture scales better than peer-to-peer for group calls. Open-source with self-hosting option. Native React Native SDK. Handles codec negotiation, adaptive bitrate, and participant management automatically.
**Where:** `backend/internal/services/voice_service.go`, `mobile/app/voice/`

### Stripe
**Role:** Payment processing for Flicko Plus premium subscription.
**Why:** PCI-compliant payment infrastructure. React Native SDK provides native payment sheets. Webhook integration for subscription lifecycle events (created, renewed, cancelled).
**Where:** `shared/services/stripePaymentService.ts`, `mobile/app/flicko-plus.tsx`

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
| **Node Exporter** | latest | Host CPU/RAM/disk/network metrics | Docker container |
| **NGINX Exporter** | latest | Request throughput and status codes | Docker container |

---

## Development Tools

| Tool | Purpose | Configuration |
|------|---------|--------------|
| **Husky** | Git pre-commit hooks | `.husky/pre-commit` |
| **Prettier** | TS/JSON/YAML/MD formatting | `.prettierrc` |
| **lint-staged** | Run formatters on staged files only | `package.json` |
| **gofmt** | Go code formatting (enforced) | Husky pre-commit |
| **Jest** v29.7.0 | TypeScript unit testing | `jest.config.js` |
| **testify** v1.11.1 | Go test assertions | Used in 42 test files |
| **Zap** | Structured JSON logging | All Go services |

---

## Related Documentation

- [Architecture: System Overview](system-overview.md) — How these technologies work together
- [Getting Started: Prerequisites](../getting-started/prerequisites.md) — Installation for each technology
- [Getting Started: Configuration](../getting-started/configuration.md) — Environment variables for each service
- [Backend: Overview](../backend/overview.md) — Go dependency usage details

---

*Last Updated: 2026-04-11 | Version: 1.0.0 | Maintained by: Flicko Team*
