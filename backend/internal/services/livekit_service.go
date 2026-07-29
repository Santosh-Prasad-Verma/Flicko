package services

import (
	"errors"
	"time"

	"github.com/livekit/protocol/auth"
)

// TokenTTL bounds the lifetime of an issued LiveKit access token.
//
// A leaked token grants room access for its full validity window and LiveKit
// has no server-side revocation, so this is deliberately short. The token is
// only checked at join/reconnect time — an established session is unaffected
// by expiry — so clients MUST request a fresh token before reconnecting after
// a network drop rather than replaying the original one.
const TokenTTL = 15 * time.Minute

type LiveKitService interface {
	GenerateToken(roomName string, participantName string, participantIdentity string, canPublish bool, canPublishData bool) (string, error)
}

type livekitService struct {
	apiKey    string
	apiSecret string
}

func NewLiveKitService(apiKey, apiSecret string) LiveKitService {
	return &livekitService{
		apiKey:    apiKey,
		apiSecret: apiSecret,
	}
}

func (s *livekitService) GenerateToken(roomName string, participantName string, participantIdentity string, canPublish bool, canPublishData bool) (string, error) {
	if s.apiKey == "" || s.apiSecret == "" {
		return "", errors.New("livekit API key and secret are not configured")
	}

	canPub := canPublish
	canPubData := canPublishData
	canSub := true

	grant := &auth.VideoGrant{
		RoomJoin:       true,
		Room:           roomName,
		CanPublish:     &canPub,
		CanPublishData: &canPubData,
		CanSubscribe:   &canSub,
	}

	at := auth.NewAccessToken(s.apiKey, s.apiSecret).
		SetVideoGrant(grant).
		SetIdentity(participantIdentity).
		SetName(participantName).
		SetValidFor(TokenTTL)

	return at.ToJWT()
}
