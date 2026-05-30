package handlers

import (
	"encoding/json"
	"errors"
	"net/http"
	"strconv"
	"time"

	"github.com/gorilla/mux"
	"go.uber.org/zap"

	"github.com/flicko-org/flicko-backend/internal/services/e2ee"
)

// ── Envelopes ───────────────────────────────────────────────────────────────

func (h *E2EEHandler) PushEnvelope(w http.ResponseWriter, r *http.Request) {
	uid := getUserID(r)
	if uid == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	var env e2ee.Envelope
	if err := json.NewDecoder(r.Body).Decode(&env); err != nil {
		writeError(w, http.StatusBadRequest, "invalid body")
		return
	}
	// Note: in sealed-sender, SenderUserID might be empty. 
	// If the client provides it, we can overwrite or leave it.
	if !env.IsSealed {
		env.SenderUserID = uid
	}
	
	if env.RecipientUserID == "" || len(env.Ciphertext) == 0 || len(env.Header) == 0 {
		writeError(w, http.StatusBadRequest, "recipient_user_id, header and ciphertext required")
		return
	}

	if err := h.envelopes.Push(r.Context(), env); err != nil {
		if errors.Is(err, e2ee.ErrEnvelopeReplay) {
			writeError(w, http.StatusConflict, "envelope replay rejected")
			return
		}
		h.logger.Error("push envelope failed", zap.Error(err))
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

func (h *E2EEHandler) PullEnvelopes(w http.ResponseWriter, r *http.Request) {
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
	
	limitStr := r.URL.Query().Get("limit")
	limit := 50
	if l, err := strconv.Atoi(limitStr); err == nil && l > 0 && l <= 100 {
		limit = l
	}

	afterStr := r.URL.Query().Get("after")
	var afterCursor int64
	if a, err := strconv.ParseInt(afterStr, 10, 64); err == nil {
		afterCursor = a
	}

	envs, err := h.envelopes.Pull(r.Context(), uid, deviceID, afterCursor, limit)
	if err != nil {
		h.logger.Error("pull envelopes failed", zap.Error(err))
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"envelopes": envs})
}

// ── Backup ──────────────────────────────────────────────────────────────────

func (h *E2EEHandler) PutBackupChunk(w http.ResponseWriter, r *http.Request) {
	uid := getUserID(r)
	if uid == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	var chunk e2ee.BackupChunk
	if err := json.NewDecoder(r.Body).Decode(&chunk); err != nil {
		writeError(w, http.StatusBadRequest, "invalid body")
		return
	}
	chunk.UserID = uid
	if len(chunk.Ciphertext) == 0 {
		writeError(w, http.StatusBadRequest, "ciphertext required")
		return
	}

	if err := h.backups.Put(r.Context(), chunk); err != nil {
		h.logger.Error("put backup chunk failed", zap.Error(err))
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

func (h *E2EEHandler) FetchBackupChunk(w http.ResponseWriter, r *http.Request) {
	uid := getUserID(r)
	if uid == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	indexStr := mux.Vars(r)["index"]
	index, err := strconv.Atoi(indexStr)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid index")
		return
	}

	chunk, err := h.backups.Fetch(r.Context(), uid, index)
	if err != nil {
		writeError(w, http.StatusNotFound, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, chunk)
}

func (h *E2EEHandler) BackupManifest(w http.ResponseWriter, r *http.Request) {
	uid := getUserID(r)
	if uid == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	manifest, err := h.backups.Manifest(r.Context(), uid)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, manifest)
}

func (h *E2EEHandler) DeleteBackup(w http.ResponseWriter, r *http.Request) {
	uid := getUserID(r)
	if uid == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	if err := h.backups.DeleteAll(r.Context(), uid); err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

// ── Escrow ──────────────────────────────────────────────────────────────────

func (h *E2EEHandler) GetEscrowPolicy(w http.ResponseWriter, r *http.Request) {
	uid := getUserID(r)
	if uid == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	// Org ID should be extracted from context or user session; assuming "default" for now if not multi-tenant
	orgID := r.URL.Query().Get("org_id")
	if orgID == "" {
		writeError(w, http.StatusBadRequest, "org_id required")
		return
	}
	policy, err := h.escrow.GetPolicy(r.Context(), orgID)
	if err != nil {
		writeError(w, http.StatusNotFound, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, policy)
}

// ── Audit ───────────────────────────────────────────────────────────────────

func (h *E2EEHandler) AppendAuditLog(w http.ResponseWriter, r *http.Request) {
	uid := getUserID(r)
	if uid == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	var event e2ee.VerificationEvent
	if err := json.NewDecoder(r.Body).Decode(&event); err != nil {
		writeError(w, http.StatusBadRequest, "invalid body")
		return
	}
	event.UserID = uid
	if event.PeerUserID == "" || event.Method == "" {
		writeError(w, http.StatusBadRequest, "peer_user_id and method required")
		return
	}
	event.OccurredAt = time.Now()

	if err := h.audit.Append(r.Context(), event); err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

func (h *E2EEHandler) ListAuditLogs(w http.ResponseWriter, r *http.Request) {
	uid := getUserID(r)
	if uid == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	peerUserID := mux.Vars(r)["subjectId"]
	if peerUserID == "" {
		writeError(w, http.StatusBadRequest, "subjectId path parameter required")
		return
	}
	logs, err := h.audit.List(r.Context(), peerUserID, 50)
	if err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"logs": logs})
}

// ── Handoff ─────────────────────────────────────────────────────────────────

func (h *E2EEHandler) CreateHandoff(w http.ResponseWriter, r *http.Request) {
	uid := getUserID(r)
	if uid == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	var req e2ee.HandoffRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		writeError(w, http.StatusBadRequest, "invalid body")
		return
	}
	req.UserID = uid
	if req.NewDeviceID == "" || len(req.NewDeviceIdentity) == 0 {
		writeError(w, http.StatusBadRequest, "new_device_id and new_device_identity required")
		return
	}

	if err := h.handoff.CreateRequest(r.Context(), req); err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}

func (h *E2EEHandler) ApproveHandoff(w http.ResponseWriter, r *http.Request) {
	uid := getUserID(r)
	if uid == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	requestID := mux.Vars(r)["requestId"]
	var body struct {
		WrappedKey string `json:"wrapped_key"`
	}
	if err := json.NewDecoder(r.Body).Decode(&body); err != nil {
		writeError(w, http.StatusBadRequest, "invalid body")
		return
	}

	if err := h.handoff.Approve(r.Context(), requestID, uid); err != nil {
		writeError(w, http.StatusInternalServerError, err.Error())
		return
	}
	writeJSON(w, http.StatusOK, map[string]any{"ok": true})
}
