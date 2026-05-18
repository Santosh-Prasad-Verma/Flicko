// Package handlers — E2EE endpoints.
//
// All of these endpoints carry only PUBLIC key material or per-conversation
// flags. The server cannot decrypt messages.
package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/gorilla/mux"
	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"

	"github.com/flicko-org/flicko-backend/internal/services/e2ee"
)

type E2EEHandler struct {
	keys      *e2ee.KeyStore
	envelopes e2ee.EnvelopeStore
	backups   e2ee.BackupStore
	escrow    e2ee.EscrowStore
	audit     e2ee.AuditStore
	handoff   e2ee.HandoffStore
	logger    *zap.Logger
}

func NewE2EEHandler(db *pgxpool.Pool, logger *zap.Logger) *E2EEHandler {
	return &E2EEHandler{
		keys:      e2ee.NewKeyStore(db, logger),
		envelopes: e2ee.NewEnvelopeStore(db, logger),
		backups:   e2ee.NewBackupStore(db, logger),
		escrow:    e2ee.NewEscrowStore(db, logger),
		audit:     e2ee.NewAuditStore(db, logger),
		handoff:   e2ee.NewHandoffStore(db, logger),
		logger:    logger.Named("handler.e2ee"),
	}
}

// ── Identity ────────────────────────────────────────────────────────────────

// PUT /e2ee/identity
// Body: { device_id, identity_pub, signing_pub, fingerprint }
func (h *E2EEHandler) UpsertIdentity(w http.ResponseWriter, r *http.Request) {
	uid := getUserID(r)
	if uid == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	var body struct {
		DeviceID    string `json:"device_id"`
		IdentityPub string `json:"identity_pub"`
		SigningPub  string `json:"signing_pub"`
		Fingerprint string `json:"fingerprint"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeError(w, http.StatusBadRequest, "invalid body")
		return
	}
	if body.DeviceID == "" || body.IdentityPub == "" || body.SigningPub == "" {
		writeError(w, http.StatusBadRequest, "device_id, identity_pub, signing_pub required")
		return
	}
	if err := h.keys.UpsertIdentity(r.Context(), e2ee.IdentityKey{
		UserID:      uid,
		DeviceID:    body.DeviceID,
		IdentityPub: body.IdentityPub,
		SigningPub:  body.SigningPub,
		Fingerprint: body.Fingerprint,
	}); err != nil {
		h.logger.Error("upsert identity failed", zap.Error(err))
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

// GET /e2ee/identity/{userId}
func (h *E2EEHandler) GetIdentity(w http.ResponseWriter, r *http.Request) {
	target := mux.Vars(r)["userId"]
	deviceID := r.URL.Query().Get("device_id")
	if target == "" {
		writeError(w, http.StatusBadRequest, "userId required")
		return
	}
	id, err := h.keys.GetIdentity(r.Context(), target, deviceID)
	if err != nil {
		writeError(w, http.StatusNotFound, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, id)
}

// ── Signed Prekey ───────────────────────────────────────────────────────────

// PUT /e2ee/signed-prekey
func (h *E2EEHandler) UpsertSignedPrekey(w http.ResponseWriter, r *http.Request) {
	uid := getUserID(r)
	if uid == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	var body struct {
		DeviceID  string `json:"device_id"`
		KeyID     int    `json:"key_id"`
		PublicKey string `json:"public_key"`
		Signature string `json:"signature"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeError(w, http.StatusBadRequest, "invalid body")
		return
	}
	if body.DeviceID == "" || body.PublicKey == "" || body.Signature == "" {
		writeError(w, http.StatusBadRequest, "device_id, public_key, signature required")
		return
	}
	if err := h.keys.UpsertSignedPrekey(r.Context(), uid, body.DeviceID, e2ee.SignedPrekey{
		KeyID:     body.KeyID,
		PublicKey: body.PublicKey,
		Signature: body.Signature,
	}); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

// ── One-Time Prekeys ────────────────────────────────────────────────────────

// PUT /e2ee/one-time-prekeys
// Body: { device_id, prekeys: [{key_id, public_key}, ...] }
func (h *E2EEHandler) PutOneTimePrekeys(w http.ResponseWriter, r *http.Request) {
	uid := getUserID(r)
	if uid == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	var body struct {
		DeviceID string                 `json:"device_id"`
		Prekeys  []e2ee.OneTimePrekey   `json:"prekeys"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeError(w, http.StatusBadRequest, "invalid body")
		return
	}
	if err := h.keys.PutOneTimePrekeys(r.Context(), uid, body.DeviceID, body.Prekeys); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	count, _ := h.keys.CountOneTimePrekeys(r.Context(), uid, body.DeviceID)
	writeJSON(w, http.StatusOK, map[string]any{"ok": true, "remaining": count})
}

// GET /e2ee/one-time-prekeys/count?device_id=...
func (h *E2EEHandler) CountOneTimePrekeys(w http.ResponseWriter, r *http.Request) {
	uid := getUserID(r)
	if uid == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	deviceID := r.URL.Query().Get("device_id")
	if deviceID == "" {
		writeError(w, http.StatusBadRequest, "device_id required")
		return
	}
	n, err := h.keys.CountOneTimePrekeys(r.Context(), uid, deviceID)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"count": n, "low": n < e2ee.MinOneTimePrekeysFloor})
}

// ── Bundle Fetch ────────────────────────────────────────────────────────────

// GET /e2ee/bundle/{userId}?device_id=optional
func (h *E2EEHandler) FetchBundle(w http.ResponseWriter, r *http.Request) {
	uid := getUserID(r)
	if uid == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	target := mux.Vars(r)["userId"]
	deviceID := r.URL.Query().Get("device_id")
	if target == "" {
		writeError(w, http.StatusBadRequest, "userId required")
		return
	}
	bundle, err := h.keys.FetchBundle(r.Context(), target, deviceID)
	if err != nil {
		writeError(w, http.StatusNotFound, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, bundle)
}

// ── Conversation State ──────────────────────────────────────────────────────

// POST /e2ee/conversations/{otherUserId}/enable
func (h *E2EEHandler) EnableConversation(w http.ResponseWriter, r *http.Request) {
	uid := getUserID(r)
	if uid == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	other := mux.Vars(r)["otherUserId"]
	if other == "" {
		writeError(w, http.StatusBadRequest, "otherUserId required")
		return
	}
	if err := h.keys.EnableConversation(r.Context(), uid, other); err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true, "enabled": true})
}

// GET /e2ee/conversations/{otherUserId}/state
func (h *E2EEHandler) GetConversationState(w http.ResponseWriter, r *http.Request) {
	uid := getUserID(r)
	if uid == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	other := mux.Vars(r)["otherUserId"]
	if other == "" {
		writeError(w, http.StatusBadRequest, "otherUserId required")
		return
	}
	enabled, err := h.keys.IsConversationEnabled(r.Context(), uid, other)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"enabled": enabled})
}
