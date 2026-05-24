package game

import (
	"context"
	"encoding/json"
	"net/http"

	"go.uber.org/zap"
)

type RejoinRequest struct {
	GameID string `json:"game_id"`
}

type RejoinResponse struct {
	Status              string          `json:"status"`
	IgnoreHistoryBefore int             `json:"ignoreHistoryBefore"`
	State               json.RawMessage `json:"state,omitempty"`
}

// GameStateService defines the dependency needed to pull the absolute source of truth
type GameStateService interface {
	GetGameState(ctx context.Context, gameID string) (json.RawMessage, int, error)
	GetAuthoritativeMoveNum(ctx context.Context, gameID string) (int, string, error)
}

type RejoinHandler struct {
	logger   *zap.Logger
	stateSvc GameStateService
}

func NewRejoinHandler(logger *zap.Logger, stateSvc GameStateService) *RejoinHandler {
	return &RejoinHandler{
		logger:   logger,
		stateSvc: stateSvc,
	}
}

// HandleRejoin handles POST /api/game/rejoin
// Mitigates Reconnect Storm race conditions. When a Centrifugo WebSocket reconnects, 
// Centrifugo automatically replays missed messages from its history buffer.
// However, the client might have successfully posted a move via HTTP right before dropping.
// To prevent applying the same move twice, the client calls this endpoint and discards 
// any buffered WebSocket events where event.moveNum <= ignoreHistoryBefore.
func (h *RejoinHandler) HandleRejoin(w http.ResponseWriter, r *http.Request) {
	var req RejoinRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.logger.Error("failed to decode rejoin request", zap.Error(err))
		http.Error(w, "bad request", http.StatusBadRequest)
		return
	}

	if req.GameID == "" {
		http.Error(w, "game_id is required", http.StatusBadRequest)
		return
	}

	// Read the exact move sequence directly from the master Redis Cache/Postgres DB
	stateRaw, moveNum, err := h.stateSvc.GetGameState(r.Context(), req.GameID)
	if err != nil {
		h.logger.Error("failed to get game state during rejoin", zap.Error(err), zap.String("game_id", req.GameID))
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}

	var statusObj struct {
		Status string `json:"status"`
	}
	_ = json.Unmarshal(stateRaw, &statusObj)
	
	status := "active"
	if statusObj.Status != "" {
		status = statusObj.Status
	}

	w.Header().Set("Content-Type", "application/json")
	
	response := RejoinResponse{
		Status:              status,
		IgnoreHistoryBefore: moveNum,
		State:               stateRaw,
	}

	if err := json.NewEncoder(w).Encode(response); err != nil {
		h.logger.Error("failed to encode rejoin response", zap.Error(err))
	}
}
