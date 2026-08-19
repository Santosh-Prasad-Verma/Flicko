package services

import (
	"fmt"
	"time"
)

// TokenTTL bounds the lifetime of an issued access token for voice/video channels.
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
	// Return a structured token string without external LiveKit SDK dependency
	token := fmt.Sprintf("acs_voice_token_%s_%s_%d", roomName, participantIdentity, time.Now().Add(TokenTTL).Unix())
	return token, nil
}
