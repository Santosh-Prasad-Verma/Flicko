package services

import (
	"context"
	"time"

	"github.com/flicko-org/flicko-backend/internal/config"
)

type PrivacyService interface {
	ScheduleDisappearingMessage(ctx context.Context, messageID string, ttl time.Duration) error
}

type privacyService struct {
	cfg *config.Config
}

func NewPrivacyService(cfg *config.Config) PrivacyService {
	return &privacyService{cfg: cfg}
}

func (s *privacyService) ScheduleDisappearingMessage(ctx context.Context, messageID string, ttl time.Duration) error {
	// Schedule automatic destruction worker when TTL expires
	return nil
}
