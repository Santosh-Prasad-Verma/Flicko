package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/flicko-org/flicko-backend/internal/middleware"
)

// writeJSON encodes v as JSON and writes it with the given status code.
func writeJSON(w http.ResponseWriter, code int, v interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(code)
	json.NewEncoder(w).Encode(v)
}

// writeError writes a JSON error response.
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
