# Controllers & Handlers

> **Reading time:** ~7 minutes · **Audience:** Backend Developers · **Last Updated:** 2026-04-11

Flicko maintains a strict separation of concerns within the Go backend. Rather than dumping SQL logic, authorization checks, and JSON decoding into massive tangled functions, we utilize the specific Handler (Controller) Layer.

---

## The Handler's Purpose

Handlers reside in `backend/internal/handlers/`. Their sole responsibility is bridging HTTP to Go constructs.

**A well-formed Handler MUST ONLY:**
1. Extract URL parameters (e.g., `{server_id}`) and Query params.
2. Ensure the JWT user context exists.
3. Deserialize JSON body into a strictly typed Request struct.
4. Pass the Struct to the standard Validator to check basic length/type constraints.
5. Invoke a function on the injected `Service` layer.
6. Translate the multiple return values `(result, error)` from the Service into a standardized HTTP JSON envelope (`ResponseWriter`).

**A Handler MUST NEVER:**
1. Write a raw SQL string.
2. Look up permission bits itself.
3. Call an external API (like Supabase Auth or Stripe) directly.

---

## Standard Handler Anatomy

```go
package handlers

import (
    "encoding/json"
    "net/http"
    "github.com/go-chi/chi/v5"
    "github.com/google/uuid"
    // ...
)

// 1. Definition containing injected Service
type ChannelHandler struct {
    service services.ChannelService
    validator *validator.Validate // github.com/go-playground/validator
}

// 2. Request Payload Schema
type CreateChannelRequest struct {
    Name     string    `json:"name" validate:"required,min=2,max=100"`
    Type     string    `json:"type" validate:"oneof=text voice"`
    ParentID *uuid.UUID `json:"parent_id,omitempty"` // Pointer for nullable
}

func (h *ChannelHandler) CreateChannel(w http.ResponseWriter, r *http.Request) {
    // A. Extract Path Vars
    serverIDStr := chi.URLParam(r, "server_id")
    serverID, err := uuid.Parse(serverIDStr)
    if err != nil {
        util.RespondError(w, http.StatusBadRequest, "Invalid server_id format")
        return
    }

    // B. Extract Context Variables (Placed here by Middleware)
    userID := r.Context().Value("user_id").(uuid.UUID)

    // C. Decode & Validate Body
    var req CreateChannelRequest
    if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
        util.RespondError(w, http.StatusBadRequest, "Malformed JSON")
        return
    }
    if err := h.validator.Struct(req); err != nil {
        util.RespondValidationError(w, err) // Returns standard details array
        return
    }

    // D. Delegate to Business Service
    // The service handles RBAC, collision checks, and SQL insertion.
    channel, err := h.service.Create(r.Context(), userID, serverID, req)
    if err != nil {
        util.RespondServiceError(w, err) // Transforms service errors to HTTP 403, 404, 500
        return
    }

    // E. Uniform HTTP Response
    util.RespondJSON(w, http.StatusCreated, channel)
}
```

---

## The `util.Respond*` Helpers

You'll notice raw `w.Write()` is never used. `backend/pkg/util/http.go` forces uniform JSON shapes.

- `RespondJSON(w, http.StatusOK, data)`: Sets `Content-Type: application/json` and simply marshals the data struct.
- `RespondError(w, status, code, message)`: Wraps the error into the Flicko `{ "error": {} }` schema.
- `RespondServiceError(w, err)`: Specialized helper. Flicko services natively return custom errors (e.g., `errors.PermissionDenied()`). This helper unboxes the custom Go error interface and translates it to HTTP 403 Forbidden automatically, abstracting the translation.

---

## Writing Tests

Because Handlers accept Interfaces via Dependency Injection, testing them is incredibly simple. We use Mock generation (via `gomock`) for the Services. 

You can write a simple HTTP test by instantiating an `httptest.NewRecorder()`, passing it a mock service, and verifying that the Handler responds with 400 Bad Request when missing JSON fields are sent, without needing to spin up a PostgreSQL database.
