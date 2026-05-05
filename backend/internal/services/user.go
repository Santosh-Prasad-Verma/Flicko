package services

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/flicko-org/flicko-backend/internal/cache"
	"github.com/flicko-org/flicko-backend/internal/database"
	"github.com/flicko-org/flicko-backend/internal/models"
)

type UserService interface {
	GetUser(ctx context.Context, userID string) (*models.User, error)
	UpdateProfile(ctx context.Context, userID string, updates map[string]interface{}) (*models.User, error)
	SearchUsers(ctx context.Context, query string) ([]*models.User, error)
	UpdatePresence(ctx context.Context, userID string, status models.PresenceStatus, custom string) error
	GetPresence(ctx context.Context, userID string) (*models.Presence, error)
}

type userService struct {
	db    database.DatabaseClient
	cache cache.CacheLayer
}

func NewUserService(db database.DatabaseClient, cache cache.CacheLayer) UserService {
	return &userService{
		db:    db,
		cache: cache,
	}
}

func (s *userService) GetUser(ctx context.Context, userID string) (*models.User, error) {
	cacheKey := fmt.Sprintf("user:%s", userID)

	// Cache-aside pattern
	var user models.User
	err := s.cache.GetJSON(ctx, cacheKey, &user)
	if err == nil {
		return &user, nil
	}

	if s.db == nil {
		return &models.User{ID: userID, Username: "mock_user"}, nil
	}

	query := `
		SELECT id, username, discriminator, display_name, pronouns, email, avatar, banner, bio, status, 
			   custom_status, custom_status_emoji, custom_status_expires_at, 
			   accent_color, badges, flags, verified, created_at, updated_at, last_seen
		FROM public.profiles
		WHERE id = $1
	`
	row := s.db.QueryRow(ctx, query, userID)

	err = row.Scan(
		&user.ID, &user.Username, &user.Discriminator, &user.DisplayName, &user.Pronouns,
		&user.Email, &user.AvatarURL, &user.BannerURL, &user.Bio, &user.Status,
		&user.CustomStatus, &user.CustomStatusEmoji, &user.CustomStatusExpires,
		&user.AccentColor, &user.Badges, &user.Flags, &user.Verified,
		&user.CreatedAt, &user.UpdatedAt, &user.LastSeen,
	)
	if err != nil {
		return nil, fmt.Errorf("error fetching user: %w", err)
	}

	// Cache for 1 hour
	s.cache.SetJSON(ctx, cacheKey, &user, 1*time.Hour)

	return &user, nil
}

func (s *userService) UpdateProfile(ctx context.Context, userID string, updates map[string]interface{}) (*models.User, error) {
	// Invalidate cache
	cacheKey := fmt.Sprintf("user:%s", userID)
	defer s.cache.Delete(ctx, cacheKey)

	if s.db == nil {
		return &models.User{ID: userID, Username: "updated_mock_user"}, nil
	}

	allowedFields := map[string]bool{
		"username":                 true,
		"display_name":             true,
		"pronouns":                 true,
		"avatar":                   true,
		"banner":                   true,
		"bio":                      true,
		"accent_color":             true,
		"custom_status":            true,
		"custom_status_emoji":      true,
		"custom_status_expires_at": true,
	}

	setClauses := []string{}
	args := []interface{}{userID}
	argIdx := 2

	for field, value := range updates {
		if !allowedFields[field] {
			continue
		}
		setClauses = append(setClauses, fmt.Sprintf("%s = $%d", field, argIdx))
		args = append(args, value)
		argIdx++
	}

	if len(setClauses) == 0 {
		return s.GetUser(ctx, userID)
	}

	query := fmt.Sprintf(`
		UPDATE public.profiles
		SET %s, updated_at = NOW()
		WHERE id = $1
		RETURNING id, username, discriminator, display_name, pronouns, email, avatar, banner, bio, status, 
				  custom_status, custom_status_emoji, custom_status_expires_at, 
				  accent_color, badges, flags, verified, created_at, updated_at, last_seen
	`, strings.Join(setClauses, ", "))

	var user models.User
	row := s.db.QueryRow(ctx, query, args...)
	err := row.Scan(
		&user.ID, &user.Username, &user.Discriminator, &user.DisplayName, &user.Pronouns,
		&user.Email, &user.AvatarURL, &user.BannerURL, &user.Bio, &user.Status,
		&user.CustomStatus, &user.CustomStatusEmoji, &user.CustomStatusExpires,
		&user.AccentColor, &user.Badges, &user.Flags, &user.Verified,
		&user.CreatedAt, &user.UpdatedAt, &user.LastSeen,
	)
	if err != nil {
		return nil, fmt.Errorf("error updating profile: %w", err)
	}

	return &user, nil
}

func (s *userService) SearchUsers(ctx context.Context, query string) ([]*models.User, error) {
	if s.db == nil {
		return []*models.User{{ID: "1", Username: "mock_" + query}}, nil
	}

	sqlQuery := `
		SELECT id, username, discriminator, display_name, pronouns, email, avatar, banner, bio, status, 
			   custom_status, custom_status_emoji, custom_status_expires_at, 
			   accent_color, badges, flags, verified, created_at, updated_at, last_seen
		FROM public.profiles
		WHERE username ILIKE $1 OR display_name ILIKE $1
		LIMIT 20
	`
	rows, err := s.db.Query(ctx, sqlQuery, "%"+query+"%")
	if err != nil {
		return nil, fmt.Errorf("error searching users: %w", err)
	}
	defer rows.Close()

	users := []*models.User{}
	for rows.Next() {
		var user models.User
		err := rows.Scan(
			&user.ID, &user.Username, &user.Discriminator, &user.DisplayName, &user.Pronouns,
			&user.Email, &user.AvatarURL, &user.BannerURL, &user.Bio, &user.Status,
			&user.CustomStatus, &user.CustomStatusEmoji, &user.CustomStatusExpires,
			&user.AccentColor, &user.Badges, &user.Flags, &user.Verified,
			&user.CreatedAt, &user.UpdatedAt, &user.LastSeen,
		)
		if err != nil {
			return nil, fmt.Errorf("error scanning user: %w", err)
		}
		users = append(users, &user)
	}

	return users, nil
}

func (s *userService) UpdatePresence(ctx context.Context, userID string, status models.PresenceStatus, custom string) error {
	presence := &models.Presence{
		UserID:    userID,
		Status:    status,
		Custom:    custom,
		UpdatedAt: time.Now(),
	}

	cacheKey := fmt.Sprintf("presence:%s", userID)

	// 10-second TTL for presence
	return s.cache.SetJSON(ctx, cacheKey, presence, 10*time.Second)
}

func (s *userService) GetPresence(ctx context.Context, userID string) (*models.Presence, error) {
	cacheKey := fmt.Sprintf("presence:%s", userID)

	var presence models.Presence
	err := s.cache.GetJSON(ctx, cacheKey, &presence)
	if err != nil {
		// Default to offline if not found or error
		return &models.Presence{
			UserID:    userID,
			Status:    models.StatusOffline,
			UpdatedAt: time.Now(),
		}, nil
	}

	return &presence, nil
}
