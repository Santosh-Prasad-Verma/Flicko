package services

import (
	"errors"
	"time"

	"github.com/livekit/protocol/auth"
)

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

	grant := &auth.VideoGrant{
		RoomJoin:       true,
		Room:           roomName,
		CanPublish:     &canPub,
		CanPublishData: &canPubData,
	}

	at := auth.NewAccessToken(s.apiKey, s.apiSecret).
		AddGrant(grant).
		SetIdentity(participantIdentity).
		SetName(participantName).
		SetValidFor(time.Hour * 8)

	return at.ToJWT()
}
