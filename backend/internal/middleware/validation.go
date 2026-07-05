package middleware

import (
	"encoding/json"
	"fmt"
	"mime"
	"net/http"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
)

// APIError represents a standardized API error detail for middleware responses.
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

// writeAPIError writes a standardized API error response from middleware.
func writeAPIError(w http.ResponseWriter, r *http.Request, status int, code string, message string) {
	var reqID string
	if r != nil {
		reqID = GetRequestID(r.Context())
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

// ValidationMiddleware validates request Content-Type for write operations
// and checks UUID format for standard path parameters.
func ValidationMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		// 1. Validate Content-Type header on POST, PUT, PATCH requests
		if r.Method == http.MethodPost || r.Method == http.MethodPut || r.Method == http.MethodPatch {
			ct := r.Header.Get("Content-Type")
			if ct != "" {
				mediaType, _, err := mime.ParseMediaType(ct)
				if err != nil || (mediaType != "application/json" && mediaType != "multipart/form-data") {
					writeAPIError(w, r, http.StatusUnsupportedMediaType, "VALIDATION_ERROR", "Invalid or unsupported Content-Type header. Expected application/json or multipart/form-data")
					return
				}
			} else if r.ContentLength > 0 {
				writeAPIError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", "Content-Type header is required for POST/PUT/PATCH requests with body")
				return
			}
		}

		// 2. Validate UUID path parameters in gorilla/mux vars if present
		vars := mux.Vars(r)
		uuidParams := []string{
			"serverId",
			"channelId",
			"userId",
			"messageId",
			"otherUserId",
			"subjectId",
			"targetUserId",
			"installId",
			"mappingId",
			"jobId",
		}
		for _, param := range uuidParams {
			val, exists := vars[param]
			if !exists || val == "" || val == "@me" {
				continue
			}
			if _, err := uuid.Parse(val); err != nil {
				writeAPIError(w, r, http.StatusBadRequest, "VALIDATION_ERROR", fmt.Sprintf("Invalid UUID format for path parameter '%s'", param))
				return
			}
		}

		next.ServeHTTP(w, r)
	})
}
