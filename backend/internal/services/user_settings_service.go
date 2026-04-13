package services

import (
	"context"
	"fmt"
	"time"

	"github.com/flicko-org/flicko-backend/internal/cache"
	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type UserSettingsService interface {
	GetUserSettings(ctx context.Context, userID string) (*models.UserSettings, error)
	UpdateUserSettings(ctx context.Context, userID string, settings *models.UserSettings) (*models.UserSettings, error)
}

type userSettingsService struct {
	db    *pgxpool.Pool
	redis cache.CacheLayer
}

func NewUserSettingsService(db *pgxpool.Pool, redis cache.CacheLayer) UserSettingsService {
	return &userSettingsService{
		db:    db,
		redis: redis,
	}
}

func (s *userSettingsService) GetUserSettings(ctx context.Context, userID string) (*models.UserSettings, error) {
	cacheKey := fmt.Sprintf("usersettings:%s", userID)

	// Try cache
	var settings models.UserSettings
	err := s.redis.GetJSON(ctx, cacheKey, &settings)
	if err == nil && settings.UserID != "" {
		return &settings, nil
	}

	userUUID, err := uuid.Parse(userID)
	if err != nil {
		return nil, fmt.Errorf("invalid user id format: %w", err)
	}

	// Fetch from DB
	query := `
		SELECT user_id, theme, notification_settings, privacy_settings, created_at, updated_at
		FROM public.user_settings
		WHERE user_id = $1
	`
	err = s.db.QueryRow(ctx, query, userUUID).Scan(
		&settings.UserID,
		&settings.Theme,
		&settings.NotificationSettings,
		&settings.PrivacySettings,
		&settings.CreatedAt,
		&settings.UpdatedAt,
	)

	if err != nil {
		if err == pgx.ErrNoRows {
			// Users might not have a settings row yet, typically initialized on registration, but if missing:
			return nil, fmt.Errorf("user settings not found")
		}
		return nil, fmt.Errorf("failed to fetch user settings: %w", err)
	}

	// Cache for 1 hour
	_ = s.redis.SetJSON(ctx, cacheKey, settings, time.Hour)

	return &settings, nil
}

func (s *userSettingsService) UpdateUserSettings(ctx context.Context, userID string, settings *models.UserSettings) (*models.UserSettings, error) {
	// Validate Theme
	if settings.Theme != "light" && settings.Theme != "dark" && settings.Theme != "high-contrast" {
		return nil, fmt.Errorf("invalid theme value")
	}

	userUUID, err := uuid.Parse(userID)
	if err != nil {
		return nil, fmt.Errorf("invalid user id format: %w", err)
	}

	query := `
		UPDATE public.user_settings
		SET theme = $1, notification_settings = $2, privacy_settings = $3, updated_at = NOW()
		WHERE user_id = $4
		RETURNING user_id, theme, notification_settings, privacy_settings, created_at, updated_at
	`

	var updated models.UserSettings
	err = s.db.QueryRow(ctx, query,
		settings.Theme,
		settings.NotificationSettings,
		settings.PrivacySettings,
		userUUID).Scan(
		&updated.UserID,
		&updated.Theme,
		&updated.NotificationSettings,
		&updated.PrivacySettings,
		&updated.CreatedAt,
		&updated.UpdatedAt,
	)

	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, fmt.Errorf("user settings not found for update")
		}
		return nil, fmt.Errorf("failed to update user settings: %w", err)
	}

	// Invalidate cache
	cacheKey := fmt.Sprintf("usersettings:%s", userID)
	_ = s.redis.Delete(ctx, cacheKey)

	// We could also proactively cache the newly updated state
	_ = s.redis.SetJSON(ctx, cacheKey, updated, time.Hour)

	return &updated, nil
}
