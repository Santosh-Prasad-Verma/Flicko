package handler

import (
	"encoding/json"
	"fmt"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/redis/go-redis/v9"
	"go.uber.org/zap"
	lkauth "github.com/livekit/protocol/auth"
	"github.com/livekit/protocol/webhook"

	"github.com/flicko-org/flicko/services/shared/protocol"
	fkerr "github.com/flicko-org/flicko/services/shared/errors"
)

// VoiceStateUpdatePayload is the payload pushed to clients via WebSockets
// when a participant joins or leaves a LiveKit room.
type VoiceStateUpdatePayload struct {
	ChannelID    string   `json:"channel_id"`
	UserID       string   `json:"user_id"`
	Event        string   `json:"event"`        // "join" or "leave"
	Participants []string `json:"participants"` // Current online users in the room
}

// LivekitWebhookHandler verifies and handles LiveKit room events.
type LivekitWebhookHandler struct {
	rdb       redis.Cmdable
	apiKey    string
	apiSecret string
	log       *zap.Logger
}

// NewLivekitWebhookHandler creates a LivekitWebhookHandler.
func NewLivekitWebhookHandler(rdb redis.Cmdable, log *zap.Logger) *LivekitWebhookHandler {
	return &LivekitWebhookHandler{
		rdb:       rdb,
		apiKey:    os.Getenv("LIVEKIT_API_KEY"),
		apiSecret: os.Getenv("LIVEKIT_API_SECRET"),
		log:       log.Named("livekit_webhook"),
	}
}

// ReceiveEvent handles POST /v1/voice/webhook.
func (h *LivekitWebhookHandler) ReceiveEvent(w http.ResponseWriter, r *http.Request) {
	if h.apiKey == "" || h.apiSecret == "" {
		h.log.Error("livekit credentials not set in environment")
		Error(w, h.log, fkerr.ErrInternal(fmt.Errorf("voice webhook service unconfigured")))
		return
	}

	// Verify webhook authenticity using LiveKit protocol helper
	authProvider := lkauth.NewSimpleKeyProvider(h.apiKey, h.apiSecret)
	event, err := webhook.ReceiveWebhookEvent(r, authProvider)
	if err != nil {
		h.log.Warn("failed to verify livekit webhook signature", zap.Error(err))
		w.WriteHeader(http.StatusUnauthorized)
		return
	}

	h.log.Info("received verified livekit webhook event",
		zap.String("event", event.Event),
		zap.String("room", event.Room.Name),
		zap.String("identity", event.Participant.Identity),
	)

	// LiveKit room names follow: "voice-{channelID}"
	roomName := event.Room.Name
	if !strings.HasPrefix(roomName, "voice-") {
		h.log.Debug("ignoring non-voice room webhook event", zap.String("room", roomName))
		w.WriteHeader(http.StatusOK)
		return
	}
	channelID := strings.TrimPrefix(roomName, "voice-")
	userID := event.Participant.Identity

	ctx := r.Context()
	redisKey := "flicko:voice:" + channelID + ":participants"

	var updateEvent string
	switch event.Event {
	case "participant_joined":
		updateEvent = "join"
		// SAdd adds participant to Redis Set
		if err := h.rdb.SAdd(ctx, redisKey, userID).Err(); err != nil {
			h.log.Error("failed to add participant to redis set", zap.Error(err))
			Error(w, h.log, fkerr.ErrInternal(err))
			return
		}
		// Set dynamic 2-hour TTL to prevent memory leaks if termination events are lost
		_ = h.rdb.Expire(ctx, redisKey, 2*time.Hour)

	case "participant_left":
		updateEvent = "leave"
		// SRem removes participant from Redis Set
		if err := h.rdb.SRem(ctx, redisKey, userID).Err(); err != nil {
			h.log.Error("failed to remove participant from redis set", zap.Error(err))
			Error(w, h.log, fkerr.ErrInternal(err))
			return
		}

	default:
		// Ignore other webhooks like track_published/unpublished for participant presence updates
		w.WriteHeader(http.StatusOK)
		return
	}

	// Fetch current set of active room participants
	participants, err := h.rdb.SMembers(ctx, redisKey).Result()
	if err != nil {
		h.log.Error("failed to fetch active participants from redis", zap.Error(err))
		Error(w, h.log, fkerr.ErrInternal(err))
		return
	}

	// Clean up empty sets
	if len(participants) == 0 && event.Event == "participant_left" {
		_ = h.rdb.Del(ctx, redisKey)
	}

	// Dispatch the VOICES_STATE_UPDATE payload
	payload := VoiceStateUpdatePayload{
		ChannelID:    channelID,
		UserID:       userID,
		Event:        updateEvent,
		Participants: participants,
	}

	// Construct standard opcode dispatch frame (OpDispatch = 0)
	msg, err := protocol.NewDispatch("VOICE_STATE_UPDATE", 0, payload)
	if err != nil {
		h.log.Error("failed to encode voice state update dispatch", zap.Error(err))
		Error(w, h.log, fkerr.ErrInternal(err))
		return
	}

	msgBytes, err := json.Marshal(msg)
	if err != nil {
		h.log.Error("failed to marshal dispatch frame to json", zap.Error(err))
		Error(w, h.log, fkerr.ErrInternal(err))
		return
	}

	// Publish to Redis Pub/Sub topic to trigger realtime WebSocket fanning out
	pubSubTopic := "rt:channel:" + channelID
	if err := h.rdb.Publish(ctx, pubSubTopic, msgBytes).Err(); err != nil {
		h.log.Error("failed to publish voice update to redis pubsub",
			zap.String("topic", pubSubTopic),
			zap.Error(err),
		)
		Error(w, h.log, fkerr.ErrInternal(err))
		return
	}

	h.log.Info("successfully broadcasted voice state update",
		zap.String("channel_id", channelID),
		zap.String("user_id", userID),
		zap.String("event", updateEvent),
		zap.Int("active_count", len(participants)),
	)

	w.WriteHeader(http.StatusOK)
}
