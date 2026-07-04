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
	InvalidateServerCache(ctx context.Context, serverID uuid.UUID) error
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

func (s *permissionService) getChannelServerID(ctx context.Context, channelID uuid.UUID) (uuid.UUID, error) {
	cacheKey := fmt.Sprintf("chan_srv:%s", channelID.String())
	srvIDStr, err := s.redis.Get(ctx, cacheKey)
	if err == nil && srvIDStr != "" {
		return uuid.Parse(srvIDStr)
	}

	var serverID uuid.UUID
	err = s.db.QueryRow(ctx, "SELECT server_id FROM public.channels WHERE id = $1", channelID).Scan(&serverID)
	if err != nil {
		return uuid.Nil, err
	}

	_ = s.redis.Set(ctx, cacheKey, serverID.String(), 24*time.Hour)
	return serverID, nil
}

func (s *permissionService) getGuildPermVersion(ctx context.Context, guildID uuid.UUID) (string, error) {
	versionKey := fmt.Sprintf("perm_version:%s", guildID.String())
	version, err := s.redis.Get(ctx, versionKey)
	if err != nil || version == "" {
		version = "1"
		_ = s.redis.Set(ctx, versionKey, version, 7*24*time.Hour)
	}
	return version, nil
}

func (s *permissionService) HasPermission(ctx context.Context, userID uuid.UUID, channelID uuid.UUID, permissionName string) (bool, error) {
	// 1. Resolve Server ID
	serverID, err := s.getChannelServerID(ctx, channelID)
	if err != nil {
		return false, fmt.Errorf("failed to resolve channel server ID: %w", err)
	}

	// 2. Get Server permission version
	version, err := s.getGuildPermVersion(ctx, serverID)
	if err != nil {
		return false, fmt.Errorf("failed to get guild permission version: %w", err)
	}

	// 3. Build Version-Tagged Cache Key
	cacheKey := fmt.Sprintf("perm:%s:%s:%s:%s:%s", serverID.String(), version, userID.String(), channelID.String(), permissionName)

	// Try Cache First
	hasPermStr, err := s.redis.Get(ctx, cacheKey)
	if err == nil && hasPermStr != "" {
		return hasPermStr == "true", nil
	}

	// Cache Miss: Query DB (uses the has_permission SQL function)
	var hasPerm bool
	err = s.db.QueryRow(ctx, "SELECT public.has_permission($1, $2, $3)", userID, channelID, permissionName).Scan(&hasPerm)
	if err != nil {
		return false, fmt.Errorf("failed to calculate permission: %w", err)
	}

	// Cache Result
	permStr := "false"
	if hasPerm {
		permStr = "true"
	}

	_ = s.redis.Set(ctx, cacheKey, permStr, 5*time.Minute)
	return hasPerm, nil
}

func (s *permissionService) HasServerPermission(ctx context.Context, userID uuid.UUID, serverID uuid.UUID, permissionName string) (bool, error) {
	// 1. Get Server permission version
	version, err := s.getGuildPermVersion(ctx, serverID)
	if err != nil {
		return false, fmt.Errorf("failed to get guild permission version: %w", err)
	}

	// 2. Build Version-Tagged Cache Key
	cacheKey := fmt.Sprintf("perm_srv:%s:%s:%s:%s", serverID.String(), version, userID.String(), permissionName)

	// Try Cache First
	hasPermStr, err := s.redis.Get(ctx, cacheKey)
	if err == nil && hasPermStr != "" {
		return hasPermStr == "true", nil
	}

	// Cache Miss: Query DB (uses the has_server_permission SQL function)
	var hasPerm bool
	err = s.db.QueryRow(ctx, "SELECT public.has_server_permission($1, $2, $3)", userID, serverID, permissionName).Scan(&hasPerm)
	if err != nil {
		return false, fmt.Errorf("failed to calculate server permission: %w", err)
	}

	// Cache Result
	permStr := "false"
	if hasPerm {
		permStr = "true"
	}

	_ = s.redis.Set(ctx, cacheKey, permStr, 5*time.Minute)
	return hasPerm, nil
}

func (s *permissionService) InvalidateServerCache(ctx context.Context, serverID uuid.UUID) error {
	versionKey := fmt.Sprintf("perm_version:%s", serverID.String())
	client := s.redis.GetRedisClient()
	if client != nil {
		_, err := client.Incr(ctx, versionKey).Result()
		if err != nil {
			return fmt.Errorf("failed to increment permission version: %w", err)
		}
	} else {
		// Fallback to manual set of +1
		version, err := s.redis.Get(ctx, versionKey)
		if err == nil && version != "" {
			var v int
			if _, err := fmt.Sscanf(version, "%d", &v); err == nil {
				_ = s.redis.Set(ctx, versionKey, fmt.Sprintf("%d", v+1), 7*24*time.Hour)
			}
		} else {
			_ = s.redis.Set(ctx, versionKey, "1", 7*24*time.Hour)
		}
	}
	return nil
}

func (s *permissionService) InvalidatePermissionCache(ctx context.Context, userID uuid.UUID, channelID uuid.UUID) error {
	if channelID != uuid.Nil {
		// Invalidate specific channel: get server ID and bump its version
		serverID, err := s.getChannelServerID(ctx, channelID)
		if err == nil && serverID != uuid.Nil {
			return s.InvalidateServerCache(ctx, serverID)
		}
	} else {
		// Invalidate all channels/servers for this user:
		// Since we don't have the server ID, look up all servers the user is a member of
		rows, err := s.db.Query(ctx, "SELECT server_id FROM public.server_members WHERE user_id = $1", userID)
		if err == nil {
			defer rows.Close()
			for rows.Next() {
				var serverID uuid.UUID
				if err := rows.Scan(&serverID); err == nil {
					_ = s.InvalidateServerCache(ctx, serverID)
				}
			}
		}
	}
	return nil
}
