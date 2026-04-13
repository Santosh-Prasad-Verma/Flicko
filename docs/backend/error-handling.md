# Backend Error Handling

> *Last Updated: 2026-04-11 · Version: 1.0.0*

## Overview

Flicko's backend follows a consistent, layered error handling strategy designed to:
- Never expose internal details to the client
- Always provide structured JSON error responses
- Always log errors with full context for debugging
- Always use appropriate HTTP status codes

---

## Error Response Format

All errors are returned as JSON with this structure:

```json
{
    "error": {
        "code": "ERROR_CODE",
        "message": "Human-readable error description"
    }
}
```

The `writeJSONError()` helper function in `backend/internal/middleware/security.go` ensures this format is consistent across all handlers and middleware.

---

## Error Handling by Layer

### Handler Layer
Handlers catch errors from the service layer and map them to appropriate HTTP responses:

```go
result, err := h.service.DoSomething(ctx, input)
if err != nil {
    h.logger.Error("operation failed",
        zap.String("user_id", userID),
        zap.String("input", input),
        zap.Error(err),
    )
    writeJSONError(w, http.StatusInternalServerError, "INTERNAL_ERROR", "Operation failed")
    return
}
```

**Key rule:** Handlers never return the raw `err.Error()` string to the client. This prevents leaking database queries, file paths, or internal state.

### Service Layer
Services return plain Go `error` values. They never write HTTP responses:

```go
func (s *UserService) GetByID(ctx context.Context, id uuid.UUID) (*User, error) {
    var user User
    err := s.db.QueryRow(ctx, "SELECT ... WHERE id = $1", id).Scan(&user.ID, ...)
    if err != nil {
        if errors.Is(err, pgx.ErrNoRows) {
            return nil, fmt.Errorf("user not found: %w", err)
        }
        return nil, fmt.Errorf("query user %s: %w", id, err)
    }
    return &user, nil
}
```

### Database Layer
Database errors are wrapped with context using `fmt.Errorf("operation: %w", err)` so the error chain includes:
- What operation was attempted
- Which resource was involved
- The original pgx/database error

### Bot Event Handlers
Bot event handlers are wrapped with **recovery middleware** to prevent panics from crashing the entire service:

```go
// Recovery middleware in event bus
defer func() {
    if r := recover(); r != nil {
        logger.Error("panic in event handler",
            zap.Any("panic", r),
            zap.String("event_type", string(event.Type)),
            zap.String("stack", string(debug.Stack())),
        )
    }
}()
```

---

## HTTP Status Code Mapping

| Status | When Used |
|--------|----------|
| 200 | Successful GET, PUT, PATCH |
| 201 | Successful POST (resource created) |
| 204 | Successful DELETE |
| 400 | Invalid input, missing parameters, malformed JSON |
| 401 | Missing/invalid JWT, expired token |
| 403 | CSRF failure, insufficient permissions |
| 404 | Resource not found |
| 409 | Duplicate resource (e.g., username already taken) |
| 413 | Request body or file exceeds size limit |
| 429 | Rate limited (NGINX or Redis layer) |
| 500 | Unexpected server error |

---

## Structured Logging

Every error is logged with `zap` structured fields for searchability:

```go
logger.Error("permission check failed",
    zap.String("user_id", userID.String()),
    zap.String("resource_id", resourceID),
    zap.String("permission", string(permission)),
    zap.String("request_id", requestID),
    zap.Error(err),
)
```

This produces JSON log entries that can be queried in Grafana/Loki:
```json
{
    "level": "error",
    "msg": "permission check failed",
    "user_id": "abc-123",
    "resource_id": "def-456",
    "permission": "MANAGE_SERVER",
    "request_id": "req-789",
    "error": "no rows in result set",
    "ts": "2026-04-11T00:00:00Z"
}
```

---

## Related Docs
- [Controllers](controllers.md) — Error response generation
- [Middleware](middleware.md) — Error middleware
- [Monitoring](../deployment/monitoring.md) — Log aggregation
