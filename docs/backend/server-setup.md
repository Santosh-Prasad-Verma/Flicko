# Backend Server Setup

> *Last Updated: 2026-04-11 · Version: 1.0.0*

## Overview

The Go backend server is configured primarily through environment variables loaded in `backend/internal/config/config.go`. The `Config` struct holds all runtime configuration and is populated via `config.Load()` which reads from the environment and validates required values.

---

## Configuration Struct (`config.go`)

The `Config` struct (149 lines) defines all backend configuration:

```go
type Config struct {
    // Environment
    Environment string   // "development" or "production"

    // Database
    DatabaseURL     string  // PostgreSQL connection string
    DatabasePoolMax int     // Max connections (default: 20)
    DatabasePoolMin int     // Min idle connections (default: 5)

    // Redis
    RedisURL string  // Redis connection URL (rediss:// for TLS)

    // JWT
    JWTSecret         string // ≥32 char HMAC secret
    JWTPublicKeyPath  string // Ed25519 public key file
    JWTPrivateKeyPath string // Ed25519 private key file
    JWTIssuer         string // Token issuer claim
    JWTAccessTTL      int    // Access token TTL (seconds)
    JWTRefreshTTL     int    // Refresh token TTL (seconds)

    // Encryption
    EncryptionKey []byte // 32-byte AES-256-GCM key

    // Supabase
    SupabaseURL           string
    SupabaseAnonKey       string
    SupabaseServiceRoleKey string

    // Cloudinary
    CloudinaryCloudName    string
    CloudinaryAPIKey       string
    CloudinaryAPISecret    string
    CloudinaryUploadPreset string

    // LiveKit
    LiveKitAPIKey    string
    LiveKitAPISecret string
    LiveKitURL       string

    // Server
    Port        string // HTTP listen port
    MetricsPort string // Prometheus metrics port
}
```

## Validation during `Load()`

The `config.Load()` function:

1. **Reads environment variables** using `os.Getenv()` with sensible defaults
2. **Validates required variables** — panics with descriptive error if missing:
   - `DATABASE_URL` — always required
   - `JWT_SECRET` — must be ≥32 characters
   - `CLOUDINARY_CLOUD_NAME`, `CLOUDINARY_API_KEY`, `CLOUDINARY_API_SECRET` — required for media
3. **Handles encryption key** — In production, `ENCRYPTION_KEY` must be a 64-char hex string (32 bytes). In development, an ephemeral key is generated on startup with a warning log.
4. **Returns** the populated `*Config` struct

---

## Server Initialization (`main.go`)

The `main()` function (321 lines) follows this initialization sequence:

1. **Logger** → `zap.NewProduction()` or `zap.NewDevelopment()`
2. **Config** → `config.Load()` with validation
3. **Database** → `pgx.Connect()` with connection pool
4. **Redis** → `go-redis.NewClient()` with TLS for Upstash
5. **Services** → 95 service constructors with dependency injection
6. **Bot Registry** → Register and start all 8 bots
7. **Router** → Gorilla Mux with public + protected subrouters
8. **Middleware** → Apply 9-layer middleware stack
9. **HTTP Server** → `http.ListenAndServe()` on configured port
10. **Graceful Shutdown** → `signal.Notify(SIGTERM, SIGINT)` → 30s drain → close connections

## Related Docs
- [Backend Overview](overview.md)
- [Middleware](middleware.md)
- [Configuration](../getting-started/configuration.md)
