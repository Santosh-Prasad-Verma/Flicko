# Health Check Endpoints
> *Last Updated: 2026-04-11 · Version: 1.0.0*

## Authentication Required
No

## Endpoints

### GET /api/v1/health
**Description:** Comprehensive health check with dependency status.
**File:** `backend/internal/handlers/health_handler.go`
**Response:**
```json
{"status": "healthy", "checks": {"database": "ok", "redis": "ok"}, "uptime": "2h30m"}
```

### GET /api/v1/healthz/live
**Description:** Kubernetes liveness probe. Returns 200 if process is alive.

### GET /api/v1/healthz/ready
**Description:** Kubernetes readiness probe. Returns 200 if service can accept traffic (DB + Redis connected).
