# API Design Principles

> **Reading time:** ~15 minutes · **Audience:** Backend, Mobile Developers · **Last Updated:** 2026-04-11

This document outlines the design principles, conventions, and patterns used across Flicko's REST API. Whether you are building new endpoints in the Go `msg-service` or consuming them in the Flutter app, adhering to these rules ensures consistency and predictability.

---

## Table of Contents

- [Base Conventions](#base-conventions)
- [URL Structure](#url-structure)
- [Request & Response Envelopes](#request--response-envelopes)
- [Error Handling Schema](#error-handling-schema)
- [Pagination Strategy](#pagination-strategy)
- [Authentication Headers](#authentication-headers)
- [Handler Architecture](#handler-architecture-go)

---

## Base Conventions

1. **JSON Only:** All payloads (requests and responses) must be `application/json`. Form-data is only used for direct integrations (not defined in this API) to external providers.
2. **UTF-8:** All strings must be UTF-8 encoded.
3. **Snake_case Data:** JSON keys must always use `snake_case`, not `camelCase`. This maps cleanly to the PostgreSQL database columns.
4. **Dates & Times:** All timestamps must use ISO 8601 format with the UTC `Z` suffix (e.g., `2026-04-11T12:00:00Z`).
5. **IDs:** All resource identifiers are UUIDv4 strings.

---

## URL Structure

### The `/api/v1` Prefix
All endpoints sit behind the NGINX `/api/v1/` route prefix. NGINX strips `/api` before proxying to `msg-service`, so the Go router configuration starts at `/v1/`.

### Naming Resources
- URLs should represent noun resources, not verbs (e.g., `/users`, not `/getUsers`).
- Collections are always plural (`/servers`, `/channels`), even if referring to a single item (`/servers/{id}`).
- Nested resources should signify a strict parent-child relationship.

**Good:**
```http
GET /api/v1/servers/123/channels
POST /api/v1/channels/456/messages
```

**Bad:**
```http
POST /api/v1/sendMessage  # Verb instead of noun
GET /api/v1/server/123    # Singular collection
```

### The `@me` Alias
To fetch data relative to the currently authenticated user without knowing their ID, use the `@me` alias. The backend substitutes `@me` with the `user_id` extracted from the JWT.
```http
GET /api/v1/users/@me
PATCH /api/v1/users/@me
GET /api/v1/users/@me/servers
```

---

## Request & Response Envelopes

Flicko APIs do not use an explicit "data" envelope for successful responses. An array is returned directly for collections, and an object directly for single resources.

### Success: Fetching a single resource
```http
GET /api/v1/users/db3a2b10-...
```
**200 OK**
```json
{
  "id": "db3a2b10-...",
  "username": "tarun",
  "status": "online",
  "created_at": "2026-04-11T10:00:00Z"
}
```

### Success: Fetching a collection
```http
GET /api/v1/servers/@me/channels
```
**200 OK**
```json
[
  { "id": "1", "name": "general", "type": "text" },
  { "id": "2", "name": "announcements", "type": "announcement" }
]
```

### Mutation: Create or Update resource
Mutations return the fully hydrated resource as it exists in the database after the operation, including auto-generated fields like `created_at` or `id`.

```http
POST /api/v1/channels/123/messages
{
  "content": "Hello world"
}
```
**201 Created**
```json
{
  "id": "abc...",
  "channel_id": "123",
  "user_id": "db3a2b10-...",
  "content": "Hello world",
  "created_at": "2026-04-11T10:05:00Z"
}
```

---

## Error Handling Schema

Unlike successful responses, **errors are always enveloped** in a consistent structure. If the HTTP status code is >= 400, the client can safely assume the response body matches this schema.

```json
{
  "error": {
    "code": "validation_failed",
    "message": "The provided data was invalid.",
    "details": [
      {
        "field": "username",
        "error": "Must be between 3 and 32 characters."
      }
    ],
    "request_id": "req-9876abcde"
  }
}
```

- `code`: A snake_case enum literal intended for programmatic parsing. (See [Error Codes](../api/error-codes.md) for the full list).
- `message`: A human-readable summary of the error.
- `details`: (Optional). An array of field-level validation errors.
- `request_id`: Tracing ID mapped by the first layer of middleware. Always included for debugging correlation.

### Standard HTTP Status Codes

| Code | Meaning | Usage |
|------|---------|-------|
| 200 | OK | Read successful, or update successful |
| 201 | Created | Resource successfully created |
| 204 | No Content | Deletion successful (no body) |
| 400 | Bad Request | Validation errors, malformed JSON |
| 401 | Unauthorized | Missing, invalid, or expired JWT |
| 403 | Forbidden | User authenticated, but lacks RBAC permission |
| 404 | Not Found | Resource does not exist |
| 429 | Too Many Requests | Rate limit exceeded |
| 500 | Internal Server | Unhandled Go panic, database down, etc. |

---

## Pagination Strategy

Because Flicko deals with real-time streams of messages, **Cursor-Based Pagination** is used for dynamic collections (like messages) to prevent data shifting (when new items are added, traditional offset pagination skips or duplicates items).

Offset pagination is only used for slow-moving static lists (like Server Members).

### Cursor Pagination (Messages)

```http
GET /api/v1/channels/123/messages?limit=50&before=uuid-of-oldest-message-seen
```

Responses do not include metadata. To know if more pages exist, the client checks if `responses_array.length == limit`.

### Standard Query Parameters

- `limit`: `int` (default: 50, max: 100)
- `before`: `uuid` (fetch items created older than this ID)
- `after`: `uuid` (fetch items created newer than this ID)

---

## Authentication Headers

Every secured API route requires two headers:

1. **Authorization**
   ```http
   Authorization: Bearer eyJhbGciOiJIUzI1NiIsIn...
   ```

2. **X-CSRF-Token** (For mutating `POST`, `PUT`, `PATCH`, `DELETE` requests)
   ```http
   X-CSRF-Token: 1j9dka0...
   ```

Clients must also respect rate limiting headers sent back by the server:
- `X-RateLimit-Limit`: Maximum requests per window
- `X-RateLimit-Remaining`: Requests left in window
- `X-RateLimit-Reset`: Unix timestamp when window resets

---

## Handler Architecture (Go)

When writing new Go endpoints, follow this standard pattern inside `internal/handlers`:

```go
package handlers

import (
    "encoding/json"
    "net/http"
    // ...
)

// 1. Define Request Struct
type CreateServerRequest struct {
    Name     string `json:"name" validate:"required,min=2,max=100"`
    Template string `json:"template,omitempty"`
}

// 2. Define Handler Function
func (h *ServerHandler) HandleCreateServer(w http.ResponseWriter, r *http.Request) {
    // 3. Extract Context
    userID := r.Context().Value("user_id").(uuid.UUID)

    // 4. Decode & Validate Body
    var req CreateServerRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        util.RespondError(w, http.StatusBadRequest, "Invalid JSON body")
        return
    }
    if err := h.validator.Struct(req); err != nil {
        util.RespondValidationError(w, err)
        return
    }

    // 5. Delegate to Service Layer (Business Logic)
    server, err := h.serverService.CreateServer(r.Context(), userID, req.Name, req.Template)
    if err != nil {
        util.RespondServiceError(w, err)
        return
    }

    // 6. Respond Success
    util.RespondJSON(w, http.StatusCreated, server)
}
```

**Key Code Patterns:**
- **Thin Controllers:** Handlers only deserialize JSON, validate input types, and serialize the response.
- **Service Injection:** All database operations and business rules are delegated to the `serverService`.
- **Standardized Utilities:** Always use `util.RespondJSON` and `util.RespondError` to ensure the response envelope and Content-Type headers are correct.

---

## Related Documentation

- [Backend: Controllers](../backend/controllers.md) — How these design rules are applied in code
- [API: Error Codes](../api/error-codes.md) — Comprehensive list of error codes
- [Security: Middleware](../security/middleware.md) — Details on CSRF and Auth checks
- [Architecture: Data Flow](data-flow.md) — Sequence diagrams of API flows

---

*Last Updated: 2026-04-11 | Version: 1.0.0 | Maintained by: Flicko Team*
