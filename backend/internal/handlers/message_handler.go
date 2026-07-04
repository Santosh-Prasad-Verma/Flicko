package handlers

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"regexp"
	"strings"
	"time"

	"github.com/flicko-org/flicko-backend/internal/middleware"
	"github.com/flicko-org/flicko-backend/internal/services"
	"github.com/flicko-org/flicko-backend/internal/services/ai/moderation"
	"github.com/gorilla/mux"
	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"
	"go.uber.org/zap"
)

var userMentionRegex = regexp.MustCompile(`<@!?([0-9a-fA-F-]+)>`)

type MessageHandler struct {
	db         *pgxpool.Pool
	redis      redis.Cmdable
	logger     *zap.Logger
	moderation moderation.Service           // optional; nil disables AI mod
	mentionSvc services.MentionService      // optional; nil skips mention processing
	notifSvc   services.NotificationService // optional; nil skips notification creation
}

func NewMessageHandler(db *pgxpool.Pool, logger *zap.Logger) *MessageHandler {
	return &MessageHandler{
		db:     db,
		logger: logger.Named("handler.message"),
	}
}

func (h *MessageHandler) WithRedis(rdb redis.Cmdable) *MessageHandler {
	h.redis = rdb
	return h
}

// WithModeration wires an AI moderation service into the message pipeline.
// Returns the receiver for chaining at construction time.
func (h *MessageHandler) WithModeration(svc moderation.Service) *MessageHandler {
	h.moderation = svc
	return h
}

// WithMentionService wires the mention processor into the message pipeline.
func (h *MessageHandler) WithMentionService(svc services.MentionService) *MessageHandler {
	h.mentionSvc = svc
	return h
}

// WithNotificationService wires notification creation into the message pipeline.
func (h *MessageHandler) WithNotificationService(svc services.NotificationService) *MessageHandler {
	h.notifSvc = svc
	return h
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
	userID, ok := ctx.Value(middleware.GetUserIDKey()).(string)
	if !ok {
		http.Error(w, "unauthorized", http.StatusUnauthorized)
		return
	}

	idempotencyKey := r.Header.Get("Idempotency-Key")
	var cacheKey string
	if idempotencyKey != "" {
		cacheKey = fmt.Sprintf("idempotency:%s:%s", userID, idempotencyKey)
		if h.redis != nil {
			cachedResp, err := h.redis.Get(ctx, cacheKey).Result()
			if err == nil && cachedResp != "" {
				w.Header().Set("Content-Type", "application/json")
				w.WriteHeader(http.StatusOK)
				_, _ = w.Write([]byte(cachedResp))
				return
			}
		}
	}

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

	// 4. AI moderation pre-send. Block + 403 on `blocked`; on `review`
	// we still publish but enqueue for human moderator decision (the
	// existing audit trail is what users see). Failures fail-open via
	// the service itself.
	var modSignalID string
	if h.moderation != nil {
		modRes, err := h.moderation.Check(ctx, moderation.CheckInput{
			UserID:    userID,
			ServerID:  serverID,
			ChannelID: channelID,
			Text:      payload.Content,
		})
		if err == nil {
			modSignalID = modRes.SignalID
			switch modRes.Decision {
			case moderation.DecisionBlocked:
				w.Header().Set("Content-Type", "application/json")
				w.WriteHeader(http.StatusForbidden)
				_ = json.NewEncoder(w).Encode(map[string]any{
					"error":     "blocked_by_automod",
					"category":  modRes.TopCat,
					"signal_id": modRes.SignalID,
				})
				return
			case moderation.DecisionReview:
				// Defer enqueue until after we have the message id.
			}
		}
	}

	// 5. Insert Message with is_silent flag
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

	// 6. If the AI scored "review", enqueue with the (now persisted)
	// message id so moderators can find it. Best-effort.
	if h.moderation != nil && modSignalID != "" {
		if err := h.moderation.EnqueueReview(ctx, modSignalID, serverID, payload.Content); err != nil {
			h.logger.Warn("ai mod enqueue review", zap.Error(err))
		}
	}

	// 7. Process mentions and create notifications (best-effort, async-safe).
	go h.processMentionsAndNotify(context.Background(), newID, payload.Content, userID, serverID)

	respData := map[string]string{
		"id": newID,
	}
	respBytes, _ := json.Marshal(respData)
	if cacheKey != "" && h.redis != nil {
		_ = h.redis.Set(ctx, cacheKey, string(respBytes), 24*time.Hour).Err()
	}

	w.Header().Set("Content-Type", "application/json")
	w.WriteHeader(http.StatusOK)
	_, _ = w.Write(respBytes)
}

func (h *MessageHandler) processMentionsAndNotify(ctx context.Context, messageID, content, authorID, serverID string) {
	if h.mentionSvc != nil {
		if err := h.mentionSvc.ProcessMentions(ctx, messageID, content, authorID, &serverID); err != nil {
			h.logger.Warn("failed to process mentions", zap.Error(err))
		}
	}
	if h.notifSvc != nil {
		matches := userMentionRegex.FindAllStringSubmatch(content, -1)
		seen := make(map[string]bool)
		for _, match := range matches {
			if len(match) < 2 {
				continue
			}
			mentionedUserID := match[1]
			if mentionedUserID == authorID || seen[mentionedUserID] {
				continue
			}
			seen[mentionedUserID] = true
			if _, err := h.notifSvc.CreateNotification(ctx, mentionedUserID, "mention", "You were mentioned", "You were mentioned in a message", nil); err != nil {
				h.logger.Warn("failed to create mention notification", zap.String("mentioned_user", mentionedUserID), zap.Error(err))
			}
		}
	}
}
