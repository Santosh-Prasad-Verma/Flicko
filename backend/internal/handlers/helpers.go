package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/flicko-org/flicko-backend/internal/middleware"
)

// Standardized error code constants
const (
	CodeValidationError    = "VALIDATION_ERROR"
	CodeNotFound           = "NOT_FOUND"
	CodeUnauthorized       = "UNAUTHORIZED"
	CodeForbidden          = "FORBIDDEN"
	CodeRateLimited        = "RATE_LIMITED"
	CodeInternalError      = "INTERNAL_ERROR"
	CodeServiceUnavailable = "SERVICE_UNAVAILABLE"
	CodeConflict           = "CONFLICT"
)

// APIError represents a standardized API error detail.
type APIError struct {
	Code      string `json:"code"`
	Message   string `json:"message"`
	Status    int    `json:"status"`
	RequestID string `json:"request_id,omitempty"`
}

// APIErrorResponse wraps APIError in an outer "error" object.
type APIErrorResponse struct {
	Error APIError `json:"error"`
}

// writeAPIError writes a standardized API error response.
func writeAPIError(w http.ResponseWriter, r *http.Request, status int, code string, message string) {
	var reqID string
	if r != nil {
		reqID = middleware.GetRequestID(r.Context())
	}
	resp := APIErrorResponse{
		Error: APIError{
			Code:      code,
			Message:   message,
			Status:    status,
			RequestID: reqID,
		},
	}
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(resp)
}

// WriteAPIError is an exported helper for writing standardized API error responses.
func WriteAPIError(w http.ResponseWriter, r *http.Request, status int, code string, message string) {
	writeAPIError(w, r, status, code, message)
}

// writeJSON encodes v as JSON and writes it with the given status code.
func writeJSON(w http.ResponseWriter, code int, v interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	_ = json.NewEncoder(w).Encode(v)
}

// writeError writes a JSON error response using standardized format.
func writeError(w http.ResponseWriter, code int, msg string) {
	writeJSON(w, code, map[string]string{"error": msg})
}

// getUserID extracts the authenticated user ID from the request context.
func getUserID(r *http.Request) string {
	if uid, ok := r.Context().Value(middleware.GetUserIDKey()).(string); ok {
		return uid
	}
	return ""
}
