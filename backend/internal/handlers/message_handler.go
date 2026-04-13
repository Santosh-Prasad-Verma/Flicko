package handlers

import (
	"encoding/json"
	"net/http"
	"strings"
	"time"

	"github.com/gorilla/mux"
	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"
)

type MessageHandler struct {
	db     *pgxpool.Pool
	logger *zap.Logger
}

func NewMessageHandler(db *pgxpool.Pool, logger *zap.Logger) *MessageHandler {
	return &MessageHandler{
		db:     db,
		logger: logger.Named("handler.message"),
	}
}

type CreateMessagePayload struct {
	Content   string  `json:"content"`
	Type      string  `json:"type"`
	ReplyToID *string `json:"reply_to_id"`
	IsSilent  bool    `json:"is_silent"`
}

func (h *MessageHandler) CreateMessage(w http.ResponseWriter, r *http.Request) {
	ctx := r.Context()
	vars := mux.Vars(r)
	channelID := vars["channelId"]
	userID := ctx.Value("userID").(string)

	var payload CreateMessagePayload
	if err := json.NewDecoder(r.Body).Decode(&payload); err != nil {
		http.Error(w, "invalid request", http.StatusBadRequest)
		return
	}

	if len(payload.Content) < 1 || len(payload.Content) > 4000 {
		http.Error(w, "Message content must be between 1 and 4000 characters", http.StatusBadRequest)
		return
	}

	// 1. Fetch channel and server details
	var serverID string
	var slowmodeSeconds int
	err := h.db.QueryRow(ctx, "SELECT server_id, COALESCE(slowmode_seconds, 0) FROM channels WHERE id = $1", channelID).Scan(&serverID, &slowmodeSeconds)
	if err != nil {
		h.logger.Error("failed to find channel", zap.Error(err))
		http.Error(w, "channel not found", http.StatusNotFound)
		return
	}

	// 1.5. Check Slowmode
	if slowmodeSeconds > 0 {
		var lastMessageTime time.Time
		err = h.db.QueryRow(ctx, "SELECT created_at FROM messages WHERE channel_id = $1 AND author_id = $2 ORDER BY created_at DESC LIMIT 1", channelID, userID).Scan(&lastMessageTime)
		if err == nil {
			if time.Since(lastMessageTime).Seconds() < float64(slowmodeSeconds) {
				http.Error(w, "Slowdown! You are sending messages too fast.", http.StatusTooManyRequests)
				return
			}
		}
	}

	// 2. Check for User Timeout (Temporary Mute)
	var isTimedOut bool
	err = h.db.QueryRow(ctx, `
		SELECT EXISTS(
			SELECT 1 FROM server_members 
			WHERE server_id = $1 AND user_id = $2 AND timeout_until > now()
		)
	`, serverID, userID).Scan(&isTimedOut)
	if err == nil && isTimedOut {
		http.Error(w, "You are currently timed out and cannot send messages", http.StatusForbidden)
		return
	}

	// 3. Check @everyone / @here permissions
	if strings.Contains(payload.Content, "@everyone") || strings.Contains(payload.Content, "@here") {
		var canMentionEveryone bool
		// Check if owner, has PermMentionEveryone (1<<9 = 512), or PermAdministrator (1<<62 = 4611686018427387904)
		err = h.db.QueryRow(ctx, `
			SELECT EXISTS(
				SELECT 1 FROM servers s
				LEFT JOIN member_roles mr ON s.id = mr.server_id AND mr.user_id = $2
				LEFT JOIN roles r ON mr.role_id = r.id AND mr.server_id = r.server_id
				WHERE s.id = $1 AND (
					s.owner_id = $2 
					OR (COALESCE(r.permissions, 0) & 512) > 0 
					OR (COALESCE(r.permissions, 0) & 4611686018427387904) > 0
				)
			)
		`, serverID, userID).Scan(&canMentionEveryone)
		if err == nil && !canMentionEveryone {
			http.Error(w, "You do not have permission to use server-wide mentions", http.StatusForbidden)
			return
		}
	}

	// 4. Insert Message with is_silent flag
	var newID string
	err = h.db.QueryRow(ctx, `
		INSERT INTO messages (channel_id, author_id, content, type, reply_to_id, is_silent)
		VALUES ($1, $2, $3, $4, $5, $6) RETURNING id
	`, channelID, userID, payload.Content, payload.Type, payload.ReplyToID, payload.IsSilent).Scan(&newID)

	if err != nil {
		h.logger.Error("failed to insert message", zap.Error(err))
		http.Error(w, "internal server error", http.StatusInternalServerError)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(map[string]string{
		"id": newID,
	})
}
