package handlers

import (
	"encoding/json"
	"net/http"

	"github.com/gorilla/mux"
	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"
)

type EmojiHandler struct {
	db     *pgxpool.Pool
	logger *zap.Logger
}

func NewEmojiHandler(db *pgxpool.Pool, logger *zap.Logger) *EmojiHandler {
	return &EmojiHandler{
		db:     db,
		logger: logger.Named("handler.emoji"),
	}
}

type CustomEmoji struct {
	ID        string `json:"id"`
	ServerID  string `json:"server_id"`
	Name      string `json:"name"`
	URL       string `json:"url"`
	CreatedBy string `json:"created_by,omitempty"`
}

func (h *EmojiHandler) GetServerEmojis(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	vars := mux.Vars(r)
	serverID := vars["serverId"]

	rows, err := h.db.Query(ctx, 
		`SELECT id, server_id, name, url, created_by 
		 FROM server_emojis WHERE server_id = $1`, serverID)
	if err != nil {
		h.logger.Error("failed to query emojis", zap.Error(err))
		http.Error(w, "internal service error", http.StatusInternalServerError)
		return
	}
	defer rows.Close()

	var emojis []CustomEmoji
	for rows.Next() {
		var e CustomEmoji
		var createdBy *string
		if err := rows.Scan(&e.ID, &e.ServerID, &e.Name, &e.URL, &createdBy); err != nil {
			h.logger.Error("failed to scan emoji", zap.Error(err))
			continue
		}
		if createdBy != nil {
			e.CreatedBy = *createdBy
		}
		emojis = append(emojis, e)
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]interface{}{"emojis": emojis})
}

// Mobile devices call Appwrite SDK explicitly. When finished, they POST back the payload.
func (h *EmojiHandler) CreateEmoji(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	vars := mux.Vars(r)
	serverID := vars["serverId"]
	userID := ctx.Value("userID").(string) // from Auth middleware

	var req struct {
		Name string `json:"name"`
		URL  string `json:"url"`
	}
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, "invalid request", http.StatusBadRequest)
		return
	}

	var newID string
	err := h.db.QueryRow(ctx,
		`INSERT INTO server_emojis (server_id, name, url, created_by)
		 VALUES ($1, $2, $3, $4) RETURNING id`, 
		 serverID, req.Name, req.URL, userID).Scan(&newID)
	
	if err != nil {
		h.logger.Error("failed to create emoji", zap.Error(err))
		http.Error(w, "error inserting emoji", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{"id": newID, "status": "success"})
}
