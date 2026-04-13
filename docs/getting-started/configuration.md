# Configuration Reference

> **Reading time:** ~20 minutes · **Audience:** All Developers, DevOps · **Last Updated:** 2026-04-11

This document is the complete environment variable reference for every `.env` file across all Flicko services. Every variable is documented with its type, whether it's required, default value, valid values, and a detailed explanation of what it controls in the system. Variables are organized by the service that consumes them and grouped by functional category.

---

## Table of Contents

- [Configuration Loading](#configuration-loading)
- [Root Environment Variables (.env)](#root-environment-variables-env)
  - [Database Configuration](#database-configuration)
  - [Supabase Configuration](#supabase-configuration)
  - [Redis Configuration](#redis-configuration)
  - [JWT Authentication](#jwt-authentication)
  - [Encryption](#encryption)
  - [Cloudinary Configuration](#cloudinary-configuration)
  - [LiveKit Configuration](#livekit-configuration)
  - [Stripe Configuration](#stripe-configuration)
  - [Service Configuration](#service-configuration)
  - [CORS Configuration](#cors-configuration)
  - [Rate Limiting](#rate-limiting)
  - [Logging](#logging)
- [Mobile Environment Variables (mobile/.env)](#mobile-environment-variables-mobileenv)
- [ws-gateway Specific](#ws-gateway-specific)
- [msg-service Specific](#msg-service-specific)
- [Backend Specific](#backend-specific)
- [Docker Compose Overrides](#docker-compose-overrides)
- [NGINX Configuration Variables](#nginx-configuration-variables)

---

## Configuration Loading

All Go services load configuration through the `config.Load()` function defined in `backend/internal/config/config.go` (149 lines). This function performs the following steps at startup:

1. **Reads `.env` file** — Uses `godotenv.Load()` to load variables from the `.env` file in the project root. If the file doesn't exist, it falls back to system environment variables (useful in Docker containers where `env_file` is used).

2. **Validates required variables** — Checks that all mandatory variables are present and non-empty. If any required variable is missing, the service logs a fatal error and exits immediately. This fail-fast approach ensures you discover configuration problems at startup, not during a user request 3 hours later.

3. **Generates ephemeral keys** — In development mode (when `ENVIRONMENT=development` or `ENCRYPTION_KEY` is empty), the system auto-generates a random encryption key and logs a warning. This allows developers to start quickly without configuring encryption, but the warning makes it clear this is not suitable for production.

4. **Returns a Config struct** — All validated values are returned in a typed `Config` struct that services use throughout their lifecycle via dependency injection.

```go
// backend/internal/config/config.go
type Config struct {
    // Database
    DatabaseURL string
    
    // Supabase
    SupabaseURL           string
    SupabaseAnonKey       string
    SupabaseServiceRoleKey string
    
    // Redis
    RedisURL string
    
    // Auth
    JWTSecret string
    
    // Encryption
    EncryptionKey []byte
    
    // Cloudinary
    CloudinaryCloudName string
    CloudinaryAPIKey    string
    CloudinaryAPISecret string
    
    // LiveKit
    LiveKitURL       string
    LiveKitAPIKey    string
    LiveKitAPISecret string
    
    // Server
    Port        string
    Environment string
    LogLevel    string
}

func Load() (*Config, error) {
    // Load .env file (non-fatal if missing — allows pure env var config)
    _ = godotenv.Load()
    
    cfg := &Config{
        DatabaseURL:            mustGetEnv("DATABASE_URL"),
        SupabaseURL:            mustGetEnv("SUPABASE_URL"),
        SupabaseAnonKey:        mustGetEnv("SUPABASE_ANON_KEY"),
        SupabaseServiceRoleKey: mustGetEnv("SUPABASE_SERVICE_ROLE_KEY"),
        RedisURL:               mustGetEnv("REDIS_URL"),
        JWTSecret:              mustGetEnv("JWT_SECRET"),
        Port:                   getEnvWithDefault("PORT", "8080"),
        Environment:            getEnvWithDefault("ENVIRONMENT", "development"),
        LogLevel:               getEnvWithDefault("LOG_LEVEL", "info"),
    }
    
    // Handle encryption key - generate ephemeral if not set
    encKeyHex := os.Getenv("ENCRYPTION_KEY")
    if encKeyHex == "" {
        cfg.EncryptionKey = generateEphemeralKey()
        log.Println("⚠️  WARNING: Using ephemeral encryption key. Set ENCRYPTION_KEY for production.")
    } else {
        key, err := hex.DecodeString(encKeyHex)
        if err != nil || len(key) != 32 {
            return nil, fmt.Errorf("ENCRYPTION_KEY must be 64 hex characters (32 bytes)")
        }
        cfg.EncryptionKey = key
    }
    
    return cfg, nil
}
```

---

## Root Environment Variables (.env)

These variables are loaded by all three Go backend services. They live in the `.env` file at the project root.

### Database Configuration

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `DATABASE_URL` | String (URI) | ✅ Yes | — | PostgreSQL connection string |

**`DATABASE_URL`** is the most critical configuration variable in Flicko. It defines how all three Go services connect to the Supabase PostgreSQL database. The connection string must use the Supavisor connection pooler (port 6543), not the direct PostgreSQL port (5432), because Supavisor manages connection pools across all services to prevent connection exhaustion. With three services each opening their own pool (default 10 connections each), direct connections would quickly exhaust the 60-connection limit on most Supabase plans. Supavisor multiplexes these into a smaller number of backend connections.

**Format:**
```
postgresql://postgres.[PROJECT_REF]:[PASSWORD]@[HOST]:6543/postgres?sslmode=require
```

**Example:**
```env
DATABASE_URL=postgresql://postgres.abcdefgh:MyStr0ngP@ssw0rd@aws-0-us-east-1.pooler.supabase.com:6543/postgres?sslmode=require
```

**Where to find it:** Supabase Dashboard → Settings → Database → Connection String → URI (select "Transaction" mode for the pooler).

**What breaks if it's wrong:**
- Wrong password → `password authentication failed` error at startup
- Wrong host → `no such host` or `connection refused` error
- Port 5432 instead of 6543 → Works initially, but crashes under load with `too many connections`
- Missing `sslmode=require` → Connection refused (Supabase requires TLS)

### Supabase Configuration

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `SUPABASE_URL` | String (URL) | ✅ Yes | — | Supabase project URL |
| `SUPABASE_ANON_KEY` | String (JWT) | ✅ Yes | — | Public anonymous API key |
| `SUPABASE_SERVICE_ROLE_KEY` | String (JWT) | ✅ Yes | — | Service role key (bypasses RLS) |

**`SUPABASE_URL`** is the base URL for your Supabase project. It's used by the Go services to call the Supabase Auth API (for JWT verification fallback) and by the mobile app to initialize the Supabase client. The URL follows the format `https://[PROJECT_REF].supabase.co`. This URL is safe to expose in client-side code — it's the `SUPABASE_ANON_KEY` that determines what operations are allowed.

**`SUPABASE_ANON_KEY`** is the anonymous (public) API key for your Supabase project. This key is a JWT token with the `anon` role and is safe to include in the mobile app. All requests made with this key are subject to Row-Level Security (RLS) policies — the database enforces that users can only access data they're authorized to see. The mobile app uses this key to initialize the `@supabase/supabase-js` client for authentication and real-time subscriptions.

**`SUPABASE_SERVICE_ROLE_KEY`** is the service role API key that **bypasses all RLS policies**. It is used exclusively by backend services for administrative operations that need unrestricted database access — user management, bot operations, and system-level queries. This key must NEVER be exposed in client-side code, committed to version control, or logged. It is loaded only on the backend via `config.Load()` and passed to services via constructor injection.

**Where to find them:** Supabase Dashboard → Settings → API → Project URL and Project API Keys.

### Redis Configuration

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `REDIS_URL` | String (URI) | ✅ Yes | — | Redis connection string with TLS |

**`REDIS_URL`** is the connection string for the Upstash Redis instance. It must use the `rediss://` scheme (note: double 's') to enable TLS encryption. The Go Redis client (`services/shared/redis/`) parses this URL and automatically configures TLS when it detects the `rediss://` scheme. The URL includes the authentication password, host, and port.

**Format:**
```
rediss://default:[PASSWORD]@[HOST]:6379
```

**What Flicko stores in Redis** (and what breaks if the connection fails):

| Redis Usage | Data Stored | If Redis Is Down |
|-------------|-------------|-----------------|
| **Pub/Sub** | Message events keyed by channel ID | Real-time delivery stops; messages still persist to DB |
| **Session cache** | JWT session metadata, user preferences | Falls back to DB lookup; slightly slower auth |
| **Rate limit counters** | Request counts per IP/user with TTL | Rate limiting disabled; all requests pass |
| **Dead letter queue** | Failed message insertions | Failed messages are dropped instead of queued |
| **Bot config cache** | Bot settings by server ID | Falls back to DB query; slightly slower bot init |

### JWT Authentication

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `JWT_SECRET` | String | ✅ Yes | — | JWT signing secret (≥32 characters) |

**`JWT_SECRET`** is the HMAC-SHA256 secret key used by all three Go services to validate JWT tokens issued by Supabase Auth. When a user logs in through the mobile app, Supabase Auth issues a JWT token signed with this secret. On every subsequent API request, the Go middleware (`auth.go`) extracts the `Authorization: Bearer <token>` header, decodes the JWT, verifies the signature using this secret, extracts the `sub` claim (user ID), and adds it to the request context.

This secret must match the JWT secret configured in your Supabase project (found at Supabase Dashboard → Settings → API → JWT Secret). If the secrets don't match, all authenticated requests will fail with a `401 Unauthorized` response because the JWT signature verification will fail.

**Security requirements:**
- Minimum 32 characters for HMAC-SHA256
- Should be cryptographically random
- Must be identical across all three Go services (they share the same `.env`)
- Never commit to version control

### Encryption

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `ENCRYPTION_KEY` | String (Hex) | ⚠️ Dev optional | Auto-generated | AES-256-GCM encryption key (64 hex chars) |

**`ENCRYPTION_KEY`** is a 32-byte key (represented as 64 hexadecimal characters) used for AES-256-GCM encryption of sensitive data at rest. In production, this key must be set and securely stored. In development, if this variable is omitted, the `config.Load()` function generates an ephemeral random key and logs a warning. This means encrypted data from one development session cannot be decrypted in another session (after restart, the key changes).

**Generate a key:**
```bash
openssl rand -hex 32
# Output example: a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2
```

### Cloudinary Configuration

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `CLOUDINARY_CLOUD_NAME` | String | ✅ Yes | — | Cloudinary cloud name |
| `CLOUDINARY_API_KEY` | String (Numeric) | ✅ Yes | — | Cloudinary API key |
| `CLOUDINARY_API_SECRET` | String | ✅ Yes | — | Cloudinary API secret |

These three variables enable the Cloudinary direct upload flow. When a user uploads a file (avatar, banner, message attachment), the mobile app first requests a cryptographic signature from the backend (`GET /api/v1/cloudinary/sign`). The backend handler (`cloudinary.go`, 4.3 KB) uses the API secret to generate an HMAC-SHA256 signature over the upload parameters (timestamp, eager transforms, folder). The mobile app then uploads directly to Cloudinary with this signature, bypassing the Flicko backend entirely.

The `CLOUDINARY_API_SECRET` is used **only on the backend** for signature generation. The `CLOUDINARY_CLOUD_NAME` and `CLOUDINARY_API_KEY` are used on both the backend (for signature generation) and the mobile app (for constructing the upload URL).

**Where to find them:** Cloudinary Dashboard → Getting Started (top of the page shows all three values).

### LiveKit Configuration

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `LIVEKIT_URL` | String (WSS URL) | ✅ Yes | — | LiveKit server WebSocket URL |
| `LIVEKIT_API_KEY` | String | ✅ Yes | — | LiveKit API key |
| `LIVEKIT_API_SECRET` | String | ✅ Yes | — | LiveKit API secret |

These variables configure the LiveKit WebRTC SFU integration for voice and video channels. The backend uses the API key and secret to generate room tokens (JWTs signed with the LiveKit secret) that authorize users to join specific voice channels. The mobile app connects to the LiveKit URL using the `@livekit/react-native` SDK with the token received from the backend.

The `LIVEKIT_URL` must use the `wss://` protocol for secure WebSocket connections. For LiveKit Cloud, this is provided when you create a project. For self-hosted LiveKit, it's your server's WebSocket endpoint.

### Service Configuration

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `PORT` | String (Number) | ❌ No | `8080` | HTTP server listen port |
| `ENVIRONMENT` | String (Enum) | ❌ No | `development` | Runtime environment |
| `LOG_LEVEL` | String (Enum) | ❌ No | `info` | Minimum log level |

**`PORT`** determines which port the HTTP server binds to. In development, the `backend` and `ws-gateway` default to 8080, while `msg-service` defaults to 8081. In production with Docker Compose, NGINX proxies all external traffic to the internal container ports, so port conflicts between services are avoided by Docker networking.

**`ENVIRONMENT`** controls behavior that differs between development and production: in development, ephemeral encryption keys are allowed and CORS is more permissive; in production, `ENCRYPTION_KEY` must be explicitly set, and CORS is restricted to the configured origin.

**`LOG_LEVEL`** sets the minimum severity for structured JSON log output via Zap. Valid values are `debug`, `info`, `warn`, `error`. In development, `debug` is recommended to see all log output including request/response details. In production, `info` or `warn` reduces log volume and storage costs.

### CORS Configuration

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `CORS_ORIGIN` | String (URL) | ❌ No | `*` (dev) | Allowed CORS origin |

**`CORS_ORIGIN`** specifies which origins are allowed to make cross-origin requests to the API. In development, this defaults to `*` (allow all origins) for convenience. In production, this should be set to your specific domain (e.g., `https://app.flicko.dev`) to prevent unauthorized websites from making API calls with your users' credentials.

### Rate Limiting

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `RATE_LIMIT_REQUESTS` | Integer | ❌ No | `100` | Max requests per window |
| `RATE_LIMIT_WINDOW` | Duration | ❌ No | `60s` | Rate limit time window |

These variables configure the application-level Redis-backed rate limiter (the third tier of Flicko's 3-tier rate limiting system). This limiter operates per-user (identified by JWT `sub` claim) rather than per-IP, providing more accurate throttling for authenticated users. The NGINX rate limiter (per-IP) and Cloudflare rate limiter operate independently at their respective layers.

---

## Mobile Environment Variables (mobile/.env)

These variables are loaded by the React Native app via Expo's environment system. They are prefixed with `EXPO_PUBLIC_` to indicate they are embedded in the app bundle and are therefore NOT secret.

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `EXPO_PUBLIC_API_URL` | String (URL) | ✅ Yes | — | msg-service REST API base URL |
| `EXPO_PUBLIC_WS_URL` | String (URL) | ✅ Yes | — | ws-gateway WebSocket URL |
| `EXPO_PUBLIC_SUPABASE_URL` | String (URL) | ✅ Yes | — | Supabase project URL |
| `EXPO_PUBLIC_SUPABASE_ANON_KEY` | String (JWT) | ✅ Yes | — | Supabase anonymous key |

**`EXPO_PUBLIC_API_URL`** is the base URL the mobile app uses for all REST API calls. In local development, this must be set to your machine's LAN IP (not `localhost`) because the mobile simulator/device runs in a different network context. In production, this points to your NGINX reverse proxy (e.g., `https://api.flicko.dev`).

**`EXPO_PUBLIC_WS_URL`** is the WebSocket endpoint the mobile app connects to for real-time events. The path is typically `/ws`. In development: `ws://192.168.1.x:8080/ws`. In production: `wss://api.flicko.dev/ws`.

---

## ws-gateway Specific

The WebSocket gateway accepts these additional environment variables:

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `WS_MAX_CONNECTIONS` | Integer | ❌ No | `6000` | Maximum concurrent WebSocket connections |
| `WS_HEARTBEAT_INTERVAL` | Duration | ❌ No | `30s` | Heartbeat ping interval |
| `WS_HEARTBEAT_TIMEOUT` | Duration | ❌ No | `90s` | Miss 3 heartbeats before disconnect |
| `WS_READ_BUFFER_SIZE` | Integer | ❌ No | `1024` | WebSocket read buffer (bytes) |
| `WS_WRITE_BUFFER_SIZE` | Integer | ❌ No | `1024` | WebSocket write buffer (bytes) |

**`WS_MAX_CONNECTIONS`** caps the number of simultaneous WebSocket connections the gateway will accept. With the default 1 GB memory limit, 6,000 connections consume approximately 800 MB (each connection uses ~130 KB for the goroutine stack, read/write buffers, and connection metadata). Setting this higher than 6,000 requires increasing the memory limit in `docker-compose.prod.yml`.

## msg-service Specific

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `BATCH_SIZE` | Integer | ❌ No | `50` | Messages per batch insert |
| `BATCH_FLUSH_INTERVAL` | Duration | ❌ No | `50ms` | Maximum time before flush |
| `DLQ_RETRY_INTERVAL` | Duration | ❌ No | `30s` | Dead letter queue retry frequency |
| `DLQ_MAX_RETRIES` | Integer | ❌ No | `5` | Max retry attempts before discard |

## Backend Specific

| Variable | Type | Required | Default | Description |
|----------|------|----------|---------|-------------|
| `BOT_EVENT_BUFFER` | Integer | ❌ No | `100` | Event bus channel buffer size |
| `COMMAND_COOLDOWN` | Duration | ❌ No | `3s` | Per-user slash command cooldown |

---

## Docker Compose Overrides

In production, environment variables for NGINX, Prometheus, Grafana, and Loki are set directly in `docker-compose.prod.yml`:

| Variable | Container | Default | Description |
|----------|-----------|---------|-------------|
| `GF_SECURITY_ADMIN_PASSWORD` | grafana | `admin` | Grafana admin password |
| `GF_SECURITY_ADMIN_USER` | grafana | `admin` | Grafana admin username |
| `GF_SERVER_ROOT_URL` | grafana | `http://localhost:3000` | Grafana external URL |

---

## Related Documentation

- [Getting Started: Installation](installation.md) — Uses these variables during setup
- [Getting Started: Prerequisites](prerequisites.md) — How to obtain cloud service credentials
- [Deployment: Environment Setup](../deployment/environment-setup.md) — Production-specific environment configuration
- [Backend: Server Setup](../backend/server-setup.md) — How config.Load() processes these variables
- [Security: Data Protection](../security/data-protection.md) — Encryption key requirements and rotation

## Quick Reference

| Category | Variable Count | Most Critical |
|----------|---------------|--------------|
| Database | 1 | `DATABASE_URL` |
| Supabase | 3 | `SUPABASE_SERVICE_ROLE_KEY` |
| Redis | 1 | `REDIS_URL` |
| Auth | 1 | `JWT_SECRET` |
| Cloudinary | 3 | `CLOUDINARY_API_SECRET` |
| LiveKit | 3 | `LIVEKIT_API_SECRET` |
| Mobile | 4 | `EXPO_PUBLIC_API_URL` |

---

*Last Updated: 2026-04-11 | Version: 1.0.0 | Maintained by: Flicko Team*
