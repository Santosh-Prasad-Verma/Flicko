package handler

import (
	"net/http"

	"github.com/go-chi/chi/v5"
	"go.uber.org/zap"

	"github.com/flicko-org/flicko/services/msg-service/internal/service"
	"github.com/flicko-org/flicko/services/shared/auth"
)

// SearchHandler handles message search routes.
type SearchHandler struct {
	svc *service.SearchService
	log *zap.Logger
}

// NewSearchHandler creates a SearchHandler.
func NewSearchHandler(svc *service.SearchService, log *zap.Logger) *SearchHandler {
	return &SearchHandler{svc: svc, log: log}
}

// Search handles GET /v1/channels/{channelID}/messages/search.
// Query: ?q=<query>&before=<cursor>&limit=25
func (h *SearchHandler) Search(w http.ResponseWriter, r *http.Request) {
	channelID := chi.URLParam(r, "channelID")
	userID := auth.UserIDFromContext(r.Context())
	query := r.URL.Query().Get("q")
	before := r.URL.Query().Get("before")
	limit := QueryInt(r, "limit", 25, 50)

	if query == "" {
		JSON(w, http.StatusOK, []interface{}{})
		return
	}

	results, err := h.svc.SearchMessages(r.Context(), service.SearchInput{
		ChannelID: channelID,
		UserID:    userID,
		Query:     query,
		Before:    before,
		Limit:     limit,
	})
	if err != nil {
		Error(w, h.log, err)
		return
	}

	var cursor string
	if len(results) > 0 {
		cursor = results[len(results)-1].ID
	}

	JSONList(w, results, cursor)
}
