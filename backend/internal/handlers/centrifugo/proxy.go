package centrifugo

import (
	"context"
	"encoding/json"
	"net/http"
	"strings"

	"go.uber.org/zap"
)

type ProxyRequest struct {
	Client    string `json:"client"`
	Transport string `json:"transport"`
	Protocol  string `json:"protocol"`
	Encoding  string `json:"encoding"`
	User      string `json:"user"`
	Channel   string `json:"channel"`
}

type ProxyResponse struct {
	Result *SubscribeResult `json:"result,omitempty"`
	Error  *ProxyError      `json:"error,omitempty"`
}

type SubscribeResult struct{} // empty object means success

type ProxyError struct {
	Code    int    `json:"code"`
	Message string `json:"message"`
}

// GameAccessValidator checks if a user has permissions for a game
type GameAccessValidator interface {
	GetGameStatusAndPlayers(ctx context.Context, gameID string) (status string, pA string, pB string, err error)
}

type CentrifugoProxyHandler struct {
	logger *zap.Logger
	repo   GameAccessValidator
}

func NewCentrifugoProxyHandler(logger *zap.Logger, repo GameAccessValidator) *CentrifugoProxyHandler {
	return &CentrifugoProxyHandler{
		logger: logger,
		repo:   repo,
	}
}

// HandleSubscribeProxy handles POST /api/centrifugo/subscribe
// Centrifugo calls this hook to verify if a user has access to a channel.
func (h *CentrifugoProxyHandler) HandleSubscribeProxy(w http.ResponseWriter, r *http.Request) {
	var req ProxyRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		h.logger.Error("failed to decode proxy request", zap.Error(err))
		http.Error(w, "bad request", http.StatusBadRequest)
		return
	}

	w.Header().Set("Content-Type", "application/json")

	// Expecting channel format: "game:UUID"
	parts := strings.Split(req.Channel, ":")
	if len(parts) != 2 || parts[0] != "game" {
		json.NewEncoder(w).Encode(ProxyResponse{
			Error: &ProxyError{Code: 403, Message: "Permission denied: invalid channel format"},
		})
		return
	}

	gameID := parts[1]

	status, pA, pB, err := h.repo.GetGameStatusAndPlayers(r.Context(), gameID)
	if err != nil {
		h.logger.Error("failed to get game info", zap.Error(err), zap.String("game_id", gameID))
		json.NewEncoder(w).Encode(ProxyResponse{
			Error: &ProxyError{Code: 500, Message: "Internal server error"},
		})
		return
	}

	isParticipant := (req.User == pA || req.User == pB)

	// Authorization logic: Active games -> Only participants. Completed games -> Spectators allowed.
	if status == "active" && !isParticipant {
		h.logger.Warn("denied spectator access to active game", zap.String("user", req.User), zap.String("game", gameID))
		json.NewEncoder(w).Encode(ProxyResponse{
			Error: &ProxyError{Code: 403, Message: "Spectators not allowed in active games"},
		})
		return
	}

	// Success
	json.NewEncoder(w).Encode(ProxyResponse{
		Result: &SubscribeResult{},
	})
}
