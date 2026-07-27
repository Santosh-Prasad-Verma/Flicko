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

// tokenTTL bounds the lifetime of an issued LiveKit access token.
//
// LiveKit has no server-side revocation, so a leaked token is valid for its
// whole window. The token is only checked at join/reconnect time, so a short
// TTL does not interrupt an established session — but clients must request a
// fresh token when reconnecting instead of replaying the original.
const tokenTTL = 15 * time.Minute

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

// GenerateToken creates a LiveKit JWT access token for the user using the
// official livekit/protocol auth package (auth.NewAccessToken + VideoGrant).
// The returned token is a real, signed LiveKit JWT — not a placeholder.
//
// The room name follows the convention "voice-{channelID}" so all participants
// in the same channel join the same LiveKit room.
//
// NOTE: The production voice-token issuer is the Supabase edge function
// (supabase/functions/voice-token), which the mobile client calls via
// voice_repository.dart. That function additionally enforces membership,
// channel type, user limits and screen-share slots, and uses the room-name
// convention "channel_{channelId}". This msg-service /v1/voice/token route is
// wired (handler/router.go) but currently has no client caller. If it is ever
// put on the hot path, reconcile the room-name convention with the edge
// function above or voice participants will be split across two rooms.
func (s *VoiceService) GenerateToken(ctx context.Context, in VoiceTokenInput) (string, error) {
	if s.apiKey == "" || s.apiSecret == "" {
		return "", fkerr.ErrInternal(fmt.Errorf("voice service not configured: missing LIVEKIT credentials"))
	}

	if in.ChannelID == "" {
		return "", fkerr.ErrValidation("channel_id is required")
	}

	at := lkauth.NewAccessToken(s.apiKey, s.apiSecret)
	grant := &lkauth.VideoGrant{RoomJoin: true, Room: "voice-" + in.ChannelID}
	at.SetVideoGrant(grant).SetIdentity(in.UserID).SetValidFor(tokenTTL)
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
