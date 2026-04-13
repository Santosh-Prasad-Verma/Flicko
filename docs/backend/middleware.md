# Backend Middleware

> *Last Updated: 2026-04-11 · Version: 1.0.0*

## Overview

Flicko's backend applies a carefully ordered stack of middleware to every HTTP request. This middleware performs authentication, authorization, rate limiting, CSRF protection, input sanitization, and request filtering before the request reaches any handler. The middleware is implemented across multiple files in `backend/internal/middleware/` and applied in `cmd/server/main.go` during router setup.

The middleware is applied in a specific order — the **outermost middleware runs first** (receives the raw request from NGINX), and the **innermost runs last** (closest to the handler). This ordering is critical for correctness and security.

---

## Middleware Stack (Applied in Order)

```
Incoming Request from NGINX
    │
    ▼
┌──────────────────────────┐
│ 1. Request ID            │← Assigns X-Request-ID header for tracing
├──────────────────────────┤
│ 2. CORS                  │← Sets Access-Control-* headers
├──────────────────────────┤
│ 3. Timeout               │← Wraps context with 30s deadline
├──────────────────────────┤
│ 4. Request Body Limit    │← Enforces 10 MB max body size
├──────────────────────────┤
│ 5. Input Sanitization    │← Logs state-changing requests for audit
├──────────────────────────┤
│ 6. CSRF Protection       │← Validates X-CSRF-Token on POST/PUT/DELETE/PATCH
├──────────────────────────┤
│ 7. Request Filter        │← Redacts sensitive headers (Authorization, Cookie)
├──────────────────────────┤
│ 8. Rate Limiter          │← Redis-backed distributed rate limiting
├──────────────────────────┤
│ 9. Auth (protected only) │← JWT validation, sets userID in context
├──────────────────────────┤
│ 10. Authorization         │← Permission checks (RequireServerPermission, etc.)
└──────────────────────────┘
    │
    ▼
  Handler
```

---

## Middleware Deep-Dive

### 1. Request ID Middleware
**File:** `backend/internal/middleware/request_id.go`

Generates a unique UUID for every incoming request and attaches it as both an HTTP header (`X-Request-ID`) and a context value. This ID flows through all log entries, enabling end-to-end request tracing across services.

```go
// Sets X-Request-ID header and injects into request context
func RequestIDMiddleware(next http.Handler) http.Handler
```

**Usage in logs:** Every `zap.Logger` call includes `zap.String("request_id", requestID)`, making it possible to grep all log lines for a single request across services.

---

### 2. CORS Middleware
**File:** `backend/internal/middleware/cors.go`

Handles Cross-Origin Resource Sharing headers for mobile app and web clients. Configured via the `CORS_ORIGINS` environment variable (comma-separated list of allowed origins).

**Headers set:**
- `Access-Control-Allow-Origin` — From allowlist or request Origin
- `Access-Control-Allow-Methods` — GET, POST, PUT, DELETE, PATCH, OPTIONS
- `Access-Control-Allow-Headers` — Authorization, Content-Type, X-CSRF-Token, X-Request-ID
- `Access-Control-Allow-Credentials` — true
- `Access-Control-Max-Age` — 86400 (24h preflight cache)

**Preflight handling:** OPTIONS requests are short-circuited with 204 No Content after setting CORS headers.

---

### 3. Timeout Middleware
**File:** `backend/internal/middleware/timeout.go`

Wraps the request context with a deadline of `DefaultQueryTimeout` (30 seconds). If a handler or database query takes longer than this, the context is cancelled and the operation aborted. This prevents slow queries from holding connections indefinitely.

```go
const DefaultQueryTimeout = 30 * time.Second
```

---

### 4. Request Body Limit Middleware
**File:** `backend/internal/middleware/security.go` (lines 53-66)

Uses Go's built-in `http.MaxBytesReader` to enforce a maximum request body size. Any request body exceeding this limit triggers an automatic 413 Payload Too Large response.

```go
func RequestBodyLimitMiddleware(maxBytes int64, logger *zap.Logger) func(http.Handler) http.Handler
```

- **Default limit:** 10 MB (10 * 1024 * 1024 bytes)  
- **Upload endpoints:** May use a different limit (25 MB for file uploads)
- **Protection against:** Denial-of-service via oversized payloads

---

### 5. Input Sanitization Middleware
**File:** `backend/internal/middleware/security.go` (lines 68-89)

Logs all state-changing JSON requests (POST, PUT, PATCH) for audit purposes. The middleware itself does not modify the request body — doing so would prevent the handler from reading it. Instead, handlers are responsible for calling `SanitizeHTML()` before storing user input.

**The `SanitizeHTML()` function** (lines 91-115) provides XSS protection by:
1. Unescaping HTML entities
2. Removing dangerous patterns: `<script>`, `<iframe>`, `onclick=`, `javascript:`, `data:text/html`
3. Re-escaping the output for safe HTML rendering

```go
func SanitizeHTML(input string) string {
    // 1. Unescape HTML entities
    // 2. Remove XSS patterns (script, iframe, event handlers, javascript: URIs)
    // 3. Re-escape for safe output
}
```

---

### 6. CSRF Protection Middleware
**File:** `backend/internal/middleware/security.go` (lines 18-51)

Validates the `X-CSRF-Token` header on all state-changing HTTP methods (POST, PUT, DELETE, PATCH). This prevents cross-site request forgery attacks where a malicious site could trick a user's browser into making authenticated requests.

**Validation rules:**
- Only required for POST, PUT, DELETE, PATCH methods
- Token must be present in the `X-CSRF-Token` header
- Token must be at least 16 characters long
- Missing token → `403 CSRF_TOKEN_MISSING`
- Too-short token → `403 CSRF_TOKEN_INVALID`

```go
func CSRFMiddleware(logger *zap.Logger) func(http.Handler) http.Handler
```

**Logging:** Failed CSRF checks are logged with `zap.Warn` including the HTTP method, path, and client IP for security auditing.

---

### 7. Request Filter Middleware
**File:** `backend/internal/middleware/security.go` (lines 195-227)

Prevents sensitive data from being captured in access logs. Iterates over all request headers and redacts values for sensitive headers:

**Redacted headers:**
- `Authorization` → `***REDACTED***`
- `X-API-Key` → `***REDACTED***`
- `X-Auth-Token` → `***REDACTED***`
- `Cookie` → `***REDACTED***`

**Compliance:** This middleware satisfies MED-007 (prevent logging of sensitive data) from the security audit.

---

### 8. Distributed Rate Limiter
**File:** `backend/internal/middleware/distributed_ratelimit.go`

A Redis-backed rate limiter that enforces per-IP request limits. Unlike NGINX's per-IP limits (Layer 1), this is a Layer 2 limiter that can enforce per-user limits and works across multiple backend instances sharing the same Redis.

**Algorithm:** Token bucket with fixed window counters stored in Redis. Each key (`ratelimit:{ip}:{window}`) has a TTL equal to the window duration.

**Configuration:**
- Default: 50 requests per second per IP
- Redis key TTL: Window duration + 1 second buffer
- Response on limit: `429 Too Many Requests` with `Retry-After` header

**Why both NGINX and Redis rate limiting?**
- NGINX limits are fast (in-process, no network hop) but per-instance only
- Redis limits are slower (network hop to Redis) but distributed across all instances
- NGINX handles the first line of defense; Redis handles sophisticated per-user scenarios

---

### 9. Authentication Middleware
**File:** `backend/internal/middleware/auth.go`

The `Auth` middleware is applied only to protected routes (not health checks or public endpoints). It:

1. Extracts the `Authorization: Bearer <token>` header
2. Calls `AuthService.ValidateToken(token)` which:
   - Parses the JWT and validates signature (HMAC-SHA256 using `JWT_SECRET`)
   - Checks expiration, issuer, and audience claims
   - Falls back to Supabase API verification if HMAC fails (for key rotation scenarios)
3. Sets the `userID` string in the request context using `context.WithValue()`
4. Returns `401 Unauthorized` if validation fails

**Context key:** Extracted via `GetUserIDFromContext(r)` which returns the string user ID or empty string.

---

### 10. Authorization Middleware
**File:** `backend/internal/middleware/authorization.go` (280 lines)

Three authorization middleware functions enforce permission checks at different resource levels:

#### `RequirePermission(permService, permission, resourceIDKey, logger)`
Generic permission check. Extracts the resource ID from query parameters or `X-Resource-ID-*` headers, then calls `permService.HasPermission()`.

#### `RequireServerPermission(permService, permission, serverIDKey, logger)`
Server-level permission check. Used on endpoints like `/servers/{id}/settings`. Validates that the authenticated user has the specified permission in the given server.

#### `RequireChannelPermission(permService, permission, channelIDKey, logger)`
Channel-level permission check. Used on endpoints like `/channels/{id}/messages`. Validates channel-specific permissions (e.g., `VIEW_MESSAGES`, `POST_MESSAGES`).

**Permission Types (26 total):**

| Category | Permissions |
|----------|------------|
| **Channel** | `VIEW_CHANNEL`, `MANAGE_CHANNEL`, `DELETE_CHANNEL` |
| **Server** | `VIEW_SERVER`, `MANAGE_SERVER`, `DELETE_SERVER`, `MANAGE_MEMBERS`, `MANAGE_ROLES` |
| **Message** | `VIEW_MESSAGES`, `POST_MESSAGES`, `DELETE_MESSAGES`, `EDIT_MESSAGES` |
| **Moderation** | `BAN_MEMBERS`, `MUTE_MEMBERS`, `MODERATE` |
| **Bot/Command** | `EXECUTE_COMMANDS`, `MANAGE_BOTS` |
| **Stream/Video** | `STREAM_VIDEO`, `VIEW_STREAMS` |

**Permission Service Interface:**
```go
type PermissionService interface {
    HasPermission(ctx, userID, resourceID, permission) (bool, error)
    HasServerPermission(ctx, userID, serverID, permission) (bool, error)
    HasChannelPermission(ctx, userID, channelID, permission) (bool, error)
    IsServerOwner(ctx, userID, serverID) (bool, error)
    IsChannelOwner(ctx, userID, channelID) (bool, error)
}
```

---

### File Upload Validation Middleware
**File:** `backend/internal/middleware/security.go` (lines 122-193)

Applied selectively to upload endpoints. Validates:
1. **File size** — Checks against `maxSize` parameter
2. **MIME type detection** — Reads the first 512 bytes to detect actual content type using `http.DetectContentType()`
3. **Allowed types** — Validates detected MIME against an allow-list (e.g., `image/jpeg`, `image/png`, `video/mp4`)

**Error responses:**
- `413 UPLOAD_TOO_LARGE` — File exceeds size limit
- `400 FILE_TYPE_NOT_ALLOWED` — MIME type not in allowed list
- `400 FILE_READ_ERROR` — Cannot read uploaded file

---

## Router Structure

The backend uses two Gorilla Mux subrouters:

```go
// Public routes — no authentication required
publicRouter := router.PathPrefix("/api/v1").Subrouter()
publicRouter.HandleFunc("/health", healthHandler.HealthCheck).Methods("GET")
publicRouter.HandleFunc("/healthz/live", healthHandler.LivenessProbe).Methods("GET")
publicRouter.HandleFunc("/healthz/ready", healthHandler.ReadinessProbe).Methods("GET")

// Protected routes — JWT authentication required
protectedRouter := router.PathPrefix("/api/v1").Subrouter()
protectedRouter.Use(middleware.Auth(authService, logger))
// All bot, command, and user endpoints registered here
```

---

## Related Docs
- [Backend Overview](overview.md) — Service architecture
- [Controllers](controllers.md) — HTTP handler layer
- [Security: Authentication](../security/authentication.md)
- [Rate Limiting](../api/rate-limiting.md)
