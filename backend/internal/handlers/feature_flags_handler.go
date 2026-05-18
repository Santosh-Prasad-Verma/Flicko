// Package handlers — feature-flag endpoint exposed to clients.
//
// GET /users/@me/config returns rollout flags relevant to the calling
// user. Currently:
//   - e2ee_v2_enabled       (server allows v2 at all)
//   - e2ee_v2_for_user      (this specific user is in the rollout cohort)
//
// Cohort selection uses a stable hash of the user id so a user does not
// flap in/out of the cohort across requests.
package handlers

import (
	"crypto/sha256"
	"encoding/binary"
	"net/http"

	"go.uber.org/zap"
)

type FeatureFlagsHandler struct {
	logger        *zap.Logger
	v2Enabled     bool
	v2RolloutPct  int
}

func NewFeatureFlagsHandler(logger *zap.Logger, v2Enabled bool, v2RolloutPct int) *FeatureFlagsHandler {
	return &FeatureFlagsHandler{
		logger:       logger.Named("handler.feature_flags"),
		v2Enabled:    v2Enabled,
		v2RolloutPct: clampPct(v2RolloutPct),
	}
}

func clampPct(v int) int {
	switch {
	case v < 0:
		return 0
	case v > 100:
		return 100
	default:
		return v
	}
}

// GetConfig returns the per-user feature flag bundle.
func (h *FeatureFlagsHandler) GetConfig(w http.ResponseWriter, r *http.Request) {
	uid := getUserID(r)
	if uid == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}

	inCohort := h.v2Enabled && bucket(uid) < h.v2RolloutPct
	writeJSON(w, http.StatusOK, map[string]any{
		"e2ee_v2_enabled":  h.v2Enabled,
		"e2ee_v2_for_user": inCohort,
	})
}

// bucket maps a user id deterministically into [0,100).
// Uses the first 8 bytes of SHA-256(user_id) modulo 100. Stable across
// process restarts so a user stays in the same cohort.
func bucket(userID string) int {
	sum := sha256.Sum256([]byte(userID))
	return int(binary.BigEndian.Uint64(sum[:8]) % 100)
}
