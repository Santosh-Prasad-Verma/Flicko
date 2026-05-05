package services

import (
	"context"
	"fmt"
	"time"

	"github.com/flicko-org/flicko-backend/internal/cache"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type PermissionService interface {
	HasPermission(ctx context.Context, userID uuid.UUID, channelID uuid.UUID, permissionName string) (bool, error)
	HasServerPermission(ctx context.Context, userID uuid.UUID, serverID uuid.UUID, permissionName string) (bool, error)
	InvalidatePermissionCache(ctx context.Context, userID uuid.UUID, channelID uuid.UUID) error
}

type permissionService struct {
	db    *pgxpool.Pool
	redis cache.CacheLayer
}

func NewPermissionService(db *pgxpool.Pool, r cache.CacheLayer) PermissionService {
	return &permissionService{
		db:    db,
		redis: r,
	}
}

// HasPermission checks if a user has a specific permission in a channel.
// It checks Redis cache first, then falls back to calculating via DB function if needed.
func (s *permissionService) HasPermission(ctx context.Context, userID uuid.UUID, channelID uuid.UUID, permissionName string) (bool, error) {
	cacheKey := fmt.Sprintf("perm:%s:%s:%s", userID.String(), channelID.String(), permissionName)

	// 1. Try Cache First
	hasPermStr, err := s.redis.Get(ctx, cacheKey)
	if err == nil && hasPermStr != "" {
		return hasPermStr == "true", nil
	}

	// 2. Cache Miss: Query DB (uses the has_permission SQL function)
	var hasPerm bool
	err = s.db.QueryRow(ctx, "SELECT public.has_permission($1, $2, $3)", userID, channelID, permissionName).Scan(&hasPerm)
	if err != nil {
		return false, fmt.Errorf("failed to calculate permission: %w", err)
	}

	// 3. Cache Result (5 minute TTL per Task 1.21)
	permStr := "false"
	if hasPerm {
		permStr = "true"
	}

	err = s.redis.Set(ctx, cacheKey, permStr, 5*time.Minute)
	if err != nil {
		// Log cache error, but don't fail the permission check
		fmt.Printf("warning: failed to cache permission: %v\n", err)
	}

	return hasPerm, nil
}

// HasServerPermission checks if a user has a specific permission at the server level.
func (s *permissionService) HasServerPermission(ctx context.Context, userID uuid.UUID, serverID uuid.UUID, permissionName string) (bool, error) {
	cacheKey := fmt.Sprintf("perm_srv:%s:%s:%s", userID.String(), serverID.String(), permissionName)

	// 1. Try Cache First
	hasPermStr, err := s.redis.Get(ctx, cacheKey)
	if err == nil && hasPermStr != "" {
		return hasPermStr == "true", nil
	}

	// 2. Cache Miss: Query DB (uses the has_server_permission SQL function)
	var hasPerm bool
	err = s.db.QueryRow(ctx, "SELECT public.has_server_permission($1, $2, $3)", userID, serverID, permissionName).Scan(&hasPerm)
	if err != nil {
		return false, fmt.Errorf("failed to calculate server permission: %w", err)
	}

	// 3. Cache Result
	permStr := "false"
	if hasPerm {
		permStr = "true"
	}

	err = s.redis.Set(ctx, cacheKey, permStr, 5*time.Minute)
	if err != nil {
		fmt.Printf("warning: failed to cache server permission: %v\n", err)
	}

	return hasPerm, nil
}

// InvalidatePermissionCache clears the cache for a user in a channel or all channels.
func (s *permissionService) InvalidatePermissionCache(ctx context.Context, userID uuid.UUID, channelID uuid.UUID) error {
	var pattern string

	if channelID == uuid.Nil {
		// Invalidate all channels for this user (e.g., when a role is added/removed)
		pattern = fmt.Sprintf("perm:%s:*", userID.String())
	} else {
		// Invalidate specific channel for this user (e.g., channel override added)
		pattern = fmt.Sprintf("perm:%s:%s:*", userID.String(), channelID.String())
	}

	err := s.redis.DeletePattern(ctx, pattern)
	if err != nil {
		return fmt.Errorf("failed to invalidate permission cache: %w", err)
	}

	return nil
}
