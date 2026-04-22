package service

import (
	"context"
	"fmt"
	"os"
	"time"

	"go.uber.org/zap"
	lkauth "github.com/livekit/protocol/auth"

	fkerr "github.com/flicko-org/flicko/services/shared/errors"
)

// VoiceTokenInput is the input for generating a voice token.
type VoiceTokenInput struct {
	UserID    string
	ChannelID string
	ServerID  string
}

// VoiceService generates LiveKit access tokens.
type VoiceService struct {
	apiKey    string
	apiSecret string
	log       *zap.Logger
}

// NewVoiceService creates a VoiceService.
// Reads LIVEKIT_API_KEY and LIVEKIT_API_SECRET from environment.
func NewVoiceService(log *zap.Logger) *VoiceService {
	return &VoiceService{
		apiKey:    os.Getenv("LIVEKIT_API_KEY"),
		apiSecret: os.Getenv("LIVEKIT_API_SECRET"),
		log:       log,
	}
}

// GenerateToken creates a LiveKit JWT access token for the user.
//
// The room name follows the convention: "voice-{channelID}" so all
// participants in the same channel join the same LiveKit room.
//
// Note: Uses a simple HMAC-based JWT since the livekit-server-sdk-go
// dependency would add weight. For production you'd use:
//
//	import "github.com/livekit/protocol/auth"
//	at := auth.NewAccessToken(apiKey, apiSecret)
//	at.AddGrant(&auth.VideoGrant{RoomJoin: true, Room: roomName})
//	at.SetIdentity(userID)
//	token, _ := at.ToJWT()
//
// For now the handler returns a placeholder to be swapped with the
// real LiveKit SDK when ready.
func (s *VoiceService) GenerateToken(ctx context.Context, in VoiceTokenInput) (string, error) {
	if s.apiKey == "" || s.apiSecret == "" {
		return "", fkerr.ErrInternal(fmt.Errorf("voice service not configured: missing LIVEKIT credentials"))
	}

	if in.ChannelID == "" {
		return "", fkerr.ErrValidation("channel_id is required")
	}

	at := lkauth.NewAccessToken(s.apiKey, s.apiSecret)
	grant := &lkauth.VideoGrant{RoomJoin: true, Room: "voice-" + in.ChannelID}
	at.SetVideoGrant(grant).SetIdentity(in.UserID).SetValidFor(2 * time.Hour)
	token, err := at.ToJWT()
	if err != nil {
		s.log.Error("failed to generate livekit token", zap.Error(err))
		return "", fkerr.ErrInternal(fmt.Errorf("failed to generate voice token"))
	}

	s.log.Info("voice token generated",
		zap.String("user_id", in.UserID),
		zap.String("channel_id", in.ChannelID),
	)

	return token, nil
}
