package handlers

import (
	"net/http"
	"strconv"
	"time"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"
)

const (
	defaultSecurityListLimit = 50
	maxSecurityListLimit     = 200
)

type AuthSecurityHandler struct {
	db     *pgxpool.Pool
	logger *zap.Logger
}

func NewAuthSecurityHandler(db *pgxpool.Pool, logger *zap.Logger) *AuthSecurityHandler {
	return &AuthSecurityHandler{
		db:     db,
		logger: logger.Named("handler.auth_security"),
	}
}

type trustedDeviceResponse struct {
	ID                string     `json:"id"`
	DeviceName        string     `json:"device_name"`
	DeviceType        string     `json:"device_type,omitempty"`
	OS                string     `json:"os,omitempty"`
	Browser           string     `json:"browser,omitempty"`
	IPAddress         string     `json:"ip_address,omitempty"`
	Location          string     `json:"location,omitempty"`
	TrustedAt         time.Time  `json:"trusted_at"`
	LastUsedAt        time.Time  `json:"last_used_at"`
	RevokedAt         *time.Time `json:"revoked_at,omitempty"`
	RememberTokenUsed bool       `json:"remember_token_used"`
}

type loginEventResponse struct {
	ID           string    `json:"id"`
	EventType    string    `json:"event_type"`
	IPAddress    string    `json:"ip_address,omitempty"`
	UserAgent    string    `json:"user_agent,omitempty"`
	Location     string    `json:"location,omitempty"`
	RiskScore    float64   `json:"risk_score"`
	IsSuspicious bool      `json:"is_suspicious"`
	CreatedAt    time.Time `json:"created_at"`
}

func (h *AuthSecurityHandler) ListTrustedDevices(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	userUUID, err := uuid.Parse(userID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid user id")
		return
	}

	limit := getListLimit(r, defaultSecurityListLimit, maxSecurityListLimit)
	rows, err := h.db.Query(r.Context(), `
		SELECT id, device_name, COALESCE(device_type, ''), COALESCE(os, ''),
		       COALESCE(browser, ''), COALESCE(ip_address::text, ''), COALESCE(location, ''),
		       trusted_at, last_used_at, revoked_at, (remember_token_hash IS NOT NULL)
		FROM public.trusted_devices
		WHERE user_id = $1
		  AND revoked_at IS NULL
		ORDER BY COALESCE(last_used_at, trusted_at) DESC, trusted_at DESC
		LIMIT $2
	`, userUUID, limit)
	if err != nil {
		h.logger.Error("failed to list trusted devices", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to list trusted devices")
		return
	}
	defer rows.Close()

	devices := make([]trustedDeviceResponse, 0)
	for rows.Next() {
		var item trustedDeviceResponse
		if err = rows.Scan(
			&item.ID, &item.DeviceName, &item.DeviceType, &item.OS, &item.Browser,
			&item.IPAddress, &item.Location, &item.TrustedAt, &item.LastUsedAt,
			&item.RevokedAt, &item.RememberTokenUsed,
		); err != nil {
			h.logger.Error("failed to scan trusted device", zap.Error(err))
			writeError(w, http.StatusInternalServerError, "failed to list trusted devices")
			return
		}
		devices = append(devices, item)
	}
	if err = rows.Err(); err != nil {
		h.logger.Error("trusted devices row iteration failed", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to list trusted devices")
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"devices": devices,
		"count":   len(devices),
	})
}

func (h *AuthSecurityHandler) RevokeTrustedDevice(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	userUUID, err := uuid.Parse(userID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid user id")
		return
	}

	deviceID := mux.Vars(r)["id"]
	deviceUUID, err := uuid.Parse(deviceID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid device id")
		return
	}

	cmd, err := h.db.Exec(r.Context(), `
		UPDATE public.trusted_devices
		SET revoked_at = NOW(),
		    remember_token_hash = NULL,
		    updated_at = NOW()
		WHERE id = $1
		  AND user_id = $2
		  AND revoked_at IS NULL
	`, deviceUUID, userUUID)
	if err != nil {
		h.logger.Error("failed to revoke trusted device", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to revoke trusted device")
		return
	}
	if cmd.RowsAffected() == 0 {
		writeError(w, http.StatusNotFound, "trusted device not found")
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"status": "revoked",
		"id":     deviceUUID.String(),
	})
}

func (h *AuthSecurityHandler) ListLoginEvents(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	userUUID, err := uuid.Parse(userID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid user id")
		return
	}

	limit := getListLimit(r, defaultSecurityListLimit, maxSecurityListLimit)
	rows, err := h.db.Query(r.Context(), `
		SELECT id, event_type, COALESCE(ip_address::text, ''), COALESCE(user_agent, ''),
		       COALESCE(location, ''), risk_score, is_suspicious, created_at
		FROM public.login_events
		WHERE user_id = $1
		ORDER BY created_at DESC
		LIMIT $2
	`, userUUID, limit)
	if err != nil {
		h.logger.Error("failed to list login events", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to list login events")
		return
	}
	defer rows.Close()

	events := make([]loginEventResponse, 0)
	for rows.Next() {
		var item loginEventResponse
		if err = rows.Scan(
			&item.ID, &item.EventType, &item.IPAddress, &item.UserAgent,
			&item.Location, &item.RiskScore, &item.IsSuspicious, &item.CreatedAt,
		); err != nil {
			h.logger.Error("failed to scan login event", zap.Error(err))
			writeError(w, http.StatusInternalServerError, "failed to list login events")
			return
		}
		events = append(events, item)
	}
	if err = rows.Err(); err != nil {
		h.logger.Error("login events row iteration failed", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to list login events")
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"events": events,
		"count":  len(events),
	})
}

func getListLimit(r *http.Request, defaultLimit, maxLimit int) int {
	limit := defaultLimit
	if raw := r.URL.Query().Get("limit"); raw != "" {
		if parsed, err := strconv.Atoi(raw); err == nil && parsed > 0 {
			limit = parsed
		}
	}
	if limit > maxLimit {
		limit = maxLimit
	}
	return limit
}
