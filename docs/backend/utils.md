# Backend Utilities

> *Last Updated: 2026-04-11 · Version: 1.0.0*

## Overview

Backend utilities are spread across the shared Go packages (`services/shared/`) and inline helpers within each service. This document catalogs all utility functions and shared packages used across the three backend services.

---

## Shared Go Packages (`services/shared/`)

### `shared/auth/` — JWT Verification
Provides shared JWT token validation logic used by both `ws-gateway` and `msg-service`. Supports HMAC-SHA256 and Ed25519 signing algorithms.

**Key functions:**
- `VerifyToken(tokenString, secret) (*Claims, error)` — Validate and parse JWT
- `ExtractUserID(token) (string, error)` — Quick user ID extraction

### `shared/config/` — Configuration
Shared environment variable parsing and validation. Extracted common config between services so each service doesn't duplicate env loading.

### `shared/errors/` — Error Types
Standardized error types for consistent API error responses:
- `NotFoundError` — 404 responses
- `ValidationError` — 400 responses with field-level details
- `UnauthorizedError` — 401 responses
- `ForbiddenError` — 403 responses
- `ConflictError` — 409 responses (duplicate resources)
- `InternalError` — 500 responses

### `shared/id/` — ID Generation
UUID and snowflake ID helpers:
- `NewUUID() string` — Generate UUID v4
- `NewSnowflake() int64` — Twitter snowflake ID for ordering (used for message IDs)

### `shared/logger/` — Structured Logging
Zap logger initialization and configuration:
- `NewLogger(env string) *zap.Logger` — Creates production or development logger
- Production: JSON format, Info level, file+stdout output
- Development: Console format, Debug level, stdout only

### `shared/metrics/` — Prometheus Metrics
Pre-defined Prometheus counter/gauge/histogram helpers:
- `RegisterCounter(name, help) prometheus.Counter`
- `RegisterHistogram(name, help, buckets) prometheus.Histogram`
- `RegisterGauge(name, help) prometheus.Gauge`

### `shared/protocol/` — WebSocket Protocol
WebSocket frame types and opcodes used between `ws-gateway` and clients:
- `OpDispatch` — Server→Client event frame
- `OpHeartbeat` — Client→Server keepalive
- `OpIdentify` — Client→Server authentication
- `OpReady` — Server→Client session established
- `OpPresenceUpdate` — Bidirectional presence change
- `OpVoiceState` — Voice channel state change

### `shared/ratelimit/` — Rate Limiter
Token bucket implementation for per-connection rate limiting:
- `NewLimiter(rate, burst) *Limiter`
- `limiter.Allow() bool` — Check if request is allowed
- Used in ws-gateway for per-WebSocket message rate limiting

### `shared/redis/` — Redis Client
TLS-aware Redis connection factory:
- `NewClient(redisURL string) (*redis.Client, error)` — Parse URL, configure TLS for Upstash
- Handles both `redis://` and `rediss://` (TLS) schemes

### `shared/validate/` — Input Validation
Common API input validators:
- `ValidateUsername(s string) error` — 2-32 chars, alphanumeric + underscores
- `ValidateEmail(s string) error` — RFC 5322 format
- `ValidateServerName(s string) error` — 2-100 chars
- `ValidateChannelName(s string) error` — 1-100 chars, lowercase
- `ValidateMessageContent(s string) error` — 1-4000 chars, non-empty

---

## Frontend Shared Utilities (`shared/utils/`)

| File | Size | Purpose |
|------|------|---------|
| `validation.utils.ts` | 6.2 KB | Client-side form validation (email, username, password, etc.) |
| `error.utils.ts` | 4.8 KB | Error normalization, user-friendly error messages |
| `timestamps.ts` | 4.9 KB | Date/time formatting (relative, absolute, message timestamps) |
| `logger.utils.ts` | 1.8 KB | Console logging with levels and environment-aware verbosity |
| `rateLimit.utils.ts` | 2.2 KB | Client-side debounce and throttle utilities |
| `cn.ts` | 0.2 KB | Classname utility (conditional class joining) |
| `index.ts` | 0.3 KB | Barrel export |

---

## Related Docs
- [Backend Overview](overview.md) — Architecture
- [Services](services.md) — Business logic
