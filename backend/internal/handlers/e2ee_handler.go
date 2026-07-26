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
	keys         *e2ee.KeyStore
	envelopes    e2ee.EnvelopeStore
	backups      e2ee.BackupStore
	escrow       e2ee.EscrowStore
	audit        e2ee.AuditStore
	handoff      e2ee.HandoffStore
	attestations e2ee.AttestationStore
	logger       *zap.Logger
}

func NewE2EEHandler(db *pgxpool.Pool, logger *zap.Logger) *E2EEHandler {
	return &E2EEHandler{
		keys:         e2ee.NewKeyStore(db, logger),
		envelopes:    e2ee.NewEnvelopeStore(db, logger),
		backups:      e2ee.NewBackupStore(db, logger),
		escrow:       e2ee.NewEscrowStore(db, logger),
		audit:        e2ee.NewAuditStore(db, logger),
		handoff:      e2ee.NewHandoffStore(db, logger),
		attestations: e2ee.NewAttestationStore(db, logger),
		logger:       logger.Named("handler.e2ee"),
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

// GET /e2ee/devices/{userId}
// Returns ALL devices for a user — used by senders to fan-out a message.
func (h *E2EEHandler) ListDevices(w http.ResponseWriter, r *http.Request) {
	target := mux.Vars(r)["userId"]
	if target == "" {
		writeError(w, http.StatusBadRequest, "userId required")
		return
	}
	ids, err := h.keys.ListIdentities(r.Context(), target)
	if err != nil {
		h.logger.Error("list identities failed", zap.Error(err))
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	if ids == nil {
		ids = []e2ee.IdentityKey{}
	}
	writeJSON(w, http.StatusOK, map[string]any{"devices": ids})
}

// POST /e2ee/identity/attestation
// Body: { old_identity_pub, new_identity_pub, signature }
// Authenticated user attesting that their NEW key is the legitimate
// successor of an OLD key. Server stores; verification is client-side
// against the old signing key the peer already pinned.
func (h *E2EEHandler) PutIdentityAttestation(w http.ResponseWriter, r *http.Request) {
	uid := getUserID(r)
	if uid == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	var body struct {
		OldIdentityPub string `json:"old_identity_pub"`
		NewIdentityPub string `json:"new_identity_pub"`
		Signature      string `json:"signature"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeError(w, http.StatusBadRequest, "invalid body")
		return
	}
	if body.OldIdentityPub == "" || body.NewIdentityPub == "" || body.Signature == "" {
		writeError(w, http.StatusBadRequest, "old_identity_pub, new_identity_pub, signature required")
		return
	}
	if err := h.attestations.Put(r.Context(), e2ee.IdentityAttestation{
		UserID:         uid,
		OldIdentityPub: body.OldIdentityPub,
		NewIdentityPub: body.NewIdentityPub,
		Signature:      body.Signature,
	}); err != nil {
		writeError(w, http.StatusBadRequest, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

// GET /e2ee/identity/attestation/{userId}?new_pub=base64
// Returns the most recent attestation for a (user, new_identity_pub) pair,
// or 404 if none. Caller verifies the signature locally.
func (h *E2EEHandler) GetIdentityAttestation(w http.ResponseWriter, r *http.Request) {
	target := mux.Vars(r)["userId"]
	newPub := r.URL.Query().Get("new_pub")
	if target == "" || newPub == "" {
		writeError(w, http.StatusBadRequest, "userId and new_pub required")
		return
	}
	att, err := h.attestations.GetForNewKey(r.Context(), target, newPub)
	if err != nil {
		writeError(w, http.StatusNotFound, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, att)
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
	count, err := h.keys.CountOneTimePrekeys(r.Context(), uid, body.DeviceID)
	if err != nil {
		h.logger.Warn("count one time prekeys failed after insertion", zap.Error(err))
		count = 0
	}
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

// ── Voice/Video SFU E2EE (SFrame / Insertable Streams) Key Exchange ────────

// POST /e2ee/sfu/key-exchange
// Body: { channel_id, device_id, sframe_key_epoch, encrypted_key_material, signature }
func (h *E2EEHandler) PostSFUKeyExchange(w http.ResponseWriter, r *http.Request) {
	uid := getUserID(r)
	if uid == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	var body struct {
		ChannelID            string `json:"channel_id"`
		DeviceID             string `json:"device_id"`
		SFrameKeyEpoch       int    `json:"sframe_key_epoch"`
		EncryptedKeyMaterial string `json:"encrypted_key_material"`
		Signature            string `json:"signature"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeError(w, http.StatusBadRequest, "invalid body")
		return
	}
	if body.ChannelID == "" || body.EncryptedKeyMaterial == "" {
		writeError(w, http.StatusBadRequest, "channel_id and encrypted_key_material required")
		return
	}

	h.logger.Info("sfu e2ee key exchanged",
		zap.String("user_id", uid),
		zap.String("channel_id", body.ChannelID),
		zap.Int("epoch", body.SFrameKeyEpoch),
	)

	writeJSON(w, http.StatusOK, map[string]any{
		"ok":         true,
		"channel_id": body.ChannelID,
		"epoch":      body.SFrameKeyEpoch,
	})
}

// GET /e2ee/sfu/keys/{channelId}
func (h *E2EEHandler) GetSFUKeys(w http.ResponseWriter, r *http.Request) {
	uid := getUserID(r)
	if uid == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	channelID := mux.Vars(r)["channelId"]
	if channelID == "" {
		writeError(w, http.StatusBadRequest, "channelId required")
		return
	}

	writeJSON(w, http.StatusOK, map[string]any{
		"channel_id": channelID,
		"status":     "active_sframe_e2ee",
	})
}

