package game

import (
	"encoding/json"
	"net/http"

	gameSvc "github.com/flicko-org/flicko-backend/internal/services/game"
	"github.com/gorilla/mux"
	"go.uber.org/zap"
)

type LudoHandler struct {
	logger *zap.Logger
	engine gameSvc.LudoEngine
}

func NewLudoHandler(logger *zap.Logger, engine gameSvc.LudoEngine) *LudoHandler {
	return &LudoHandler{
		logger: logger,
		engine: engine,
	}
}

type RollRequest struct {
	GameID   string `json:"game_id"`
	PlayerID string `json:"player_id"`
}

type MoveRequest struct {
	GameID   string `json:"game_id"`
	PlayerID string `json:"player_id"`
	TokenID  int    `json:"token_id"`
}

func (h *LudoHandler) HandleRoll(w http.ResponseWriter, r *http.Request) {
	var req RollRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.logger.Error("failed to decode roll request", zap.Error(err))
		http.Error(w, "bad request", http.StatusBadRequest)
		return
	}

	if req.GameID == "" || req.PlayerID == "" {
		http.Error(w, "game_id and player_id are required", http.StatusBadRequest)
		return
	}

	state, err := h.engine.RollDice(r.Context(), req.GameID, req.PlayerID)
	if err != nil {
		h.logger.Warn("failed to roll dice", zap.Error(err), zap.String("game_id", req.GameID), zap.String("player_id", req.PlayerID))
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(state)
}

func (h *LudoHandler) HandleMove(w http.ResponseWriter, r *http.Request) {
	var req MoveRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.logger.Error("failed to decode move request", zap.Error(err))
		http.Error(w, "bad request", http.StatusBadRequest)
		return
	}

	if req.GameID == "" || req.PlayerID == "" {
		http.Error(w, "game_id and player_id are required", http.StatusBadRequest)
		return
	}

	state, err := h.engine.MoveToken(r.Context(), req.GameID, req.PlayerID, req.TokenID)
	if err != nil {
		h.logger.Warn("failed to move token", zap.Error(err), zap.String("game_id", req.GameID), zap.String("player_id", req.PlayerID), zap.Int("token_id", req.TokenID))
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(state)
}

// HandleGetState returns the authoritative game state for [gameID]. Clients
// fall back to this when they detect a `moveNum` gap in their Centrifugo
// event stream — see ludo_online_sync.dart.
func (h *LudoHandler) HandleGetState(w http.ResponseWriter, r *http.Request) {
	gameID := mux.Vars(r)["gameId"]
	if gameID == "" {
		http.Error(w, "gameId is required", http.StatusBadRequest)
		return
	}
	state, err := h.engine.GetGameState(r.Context(), gameID)
	if err != nil {
		http.Error(w, err.Error(), http.StatusNotFound)
		return
	}
	w.Header().Set("Content-Type", "application/json")
	_ = json.NewEncoder(w).Encode(state)
}
