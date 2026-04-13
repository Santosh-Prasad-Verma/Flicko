// Package handler contains HTTP route handlers for messages, channels,
// guilds, uploads, and health.
//
// Response format contract (all endpoints):
//
//	Success:  {"data": {...}}
//	List:     {"data": [...], "cursor": "next_page_cursor"}
//	Error:    {"error": {"code": "RATE_LIMITED", "message": "..."}}
package handler

import (
	"encoding/json"
	"net/http"
	"strconv"

	"go.uber.org/zap"

	fkerr "github.com/flicko-org/flicko/services/shared/errors"
)

// ---------- Response envelopes ----------

type successResponse struct {
	Data interface{} `json:"data"`
}

type listResponse struct {
	Data   interface{} `json:"data"`
	Cursor string      `json:"cursor,omitempty"`
}

type errorBody struct {
	Code    fkerr.Code `json:"code"`
	Message string     `json:"message"`
}

type errorResponse struct {
	Error errorBody `json:"error"`
}

// ---------- Response writers ----------

// JSON writes a JSON success response: {"data": ...}.
func JSON(w http.ResponseWriter, status int, data interface{}) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(successResponse{Data: data})
}

// JSONList writes a paginated list response: {"data": [...], "cursor": "..."}.
func JSONList(w http.ResponseWriter, data interface{}, cursor string) {
	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_ = json.NewEncoder(w).Encode(listResponse{Data: data, Cursor: cursor})
}

// Error writes an error response mapped from a domain error.
// Internal errors are logged; the client sees a generic message.
func Error(w http.ResponseWriter, log *zap.Logger, err error) {
	code := fkerr.GetCode(err)
	msg := fkerr.GetMessage(err)
	status := fkerr.HTTPStatus(err)

	// Log internal errors at error level; others at debug.
	if code == fkerr.CodeInternal {
		log.Error("internal error", zap.Error(err))
	} else {
		log.Debug("client error", zap.String("code", string(code)), zap.Error(err))
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(status)
	_ = json.NewEncoder(w).Encode(errorResponse{
		Error: errorBody{Code: code, Message: msg},
	})
}

// ---------- Request helpers ----------

// DecodeJSON decodes a JSON request body into dst.
// Returns a domain error suitable for Error() on failure.
func DecodeJSON(r *http.Request, dst interface{}) error {
	if r.Body == nil {
		return fkerr.ErrInvalidJSON(nil)
	}
	dec := json.NewDecoder(r.Body)
	dec.DisallowUnknownFields()
	if err := dec.Decode(dst); err != nil {
		return fkerr.ErrInvalidJSON(err)
	}
	return nil
}

// QueryInt extracts an integer query parameter with a default and max.
func QueryInt(r *http.Request, key string, defaultVal, maxVal int) int {
	raw := r.URL.Query().Get(key)
	if raw == "" {
		return defaultVal
	}
	n, err := strconv.Atoi(raw)
	if err != nil || n <= 0 {
		return defaultVal
	}
	if n > maxVal {
		return maxVal
	}
	return n
}
