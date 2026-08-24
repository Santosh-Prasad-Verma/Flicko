package services

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/flicko-org/flicko-backend/internal/cache"
	"github.com/flicko-org/flicko-backend/internal/database"
	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

// ChannelService is NOT wired into the HTTP router (cmd/server/main.go):
// channel CRUD is served by the direct architecture and REST endpoints.
// This service is retained as a reference / ready-made backend-owned path.
type ChannelService interface {
	CreateChannel(ctx context.Context, serverID, name string, channelType models.ChannelType, parentID *string, executorID string) (*models.Channel, error)
	GetChannel(ctx context.Context, channelID string) (*models.Channel, error)
	UpdateChannel(ctx context.Context, channelID string, updates map[string]interface{}, executorID string) (*models.Channel, error)
	DeleteChannel(ctx context.Context, channelID string, executorID string) error

	GetServerChannels(ctx context.Context, serverID string) ([]*models.Channel, error)
	CheckAccess(ctx context.Context, userID, channelID string) (bool, error)
}

type channelService struct {
	db           database.DatabaseClient
	cache        cache.CacheLayer
	permService  PermissionService
	auditService AuditLogService
}

func NewChannelService(db database.DatabaseClient, cache cache.CacheLayer, permService PermissionService, auditService AuditLogService) ChannelService {
	return &channelService{
		db:           db,
		cache:        cache,
		permService:  permService,
		auditService: auditService,
	}
}

func (s *channelService) CreateChannel(ctx context.Context, serverID string, name string, channelType models.ChannelType, parentID *string, executorID string) (*models.Channel, error) {
	if len(name) < 1 || len(name) > 100 {
		return nil, errors.New("channel name must be between 1 and 100 characters")
	}

	executorUUID, err := uuid.Parse(executorID)
	if err != nil {
		return nil, fmt.Errorf("invalid executor id: %w", err)
	}
	serverUUID, err := uuid.Parse(serverID)
	if err != nil {
		return nil, fmt.Errorf("invalid server id: %w", err)
	}

	// Permission Check
	hasPerm, err := s.permService.HasPermission(ctx, executorUUID, serverUUID, "MANAGE_CHANNELS")
	if err != nil {
		return nil, err
	}
	if !hasPerm {
		return nil, errors.New("unauthorized: requires MANAGE_CHANNELS permission")
	}

	// Calculate next position
	var nextPosition int
	posQuery := `SELECT COALESCE(MAX(position), 0) + 1 FROM public.channels WHERE server_id = $1`
	err = s.db.QueryRow(ctx, posQuery, serverID).Scan(&nextPosition)
	if err != nil {
		nextPosition = 0
	}

	query := `
		INSERT INTO public.channels (server_id, name, type, parent_id, position, created_at, updated_at)
		VALUES ($1, $2, $3, $4, $5, NOW(), NOW())
		RETURNING id, server_id, type, name, topic, position, parent_id, slowmode_seconds, default_thread_auto_archive, nsfw, created_at, updated_at
	`

	var channel models.Channel
	err = s.db.QueryRow(ctx, query, serverID, name, channelType, parentID, nextPosition).Scan(
		&channel.ID, &channel.ServerID, &channel.Type, &channel.Name, &channel.Topic,
		&channel.Position, &channel.ParentID, &channel.SlowmodeSeconds,
		&channel.DefaultThreadAutoArchive, &channel.NSFW,
		&channel.CreatedAt, &channel.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("error creating channel: %w", err)
	}

	// Invalidate server channels list cache
	s.cache.Delete(ctx, fmt.Sprintf("server:%s:channels", serverID))

	// Audit Log
	_ = s.auditService.CreateLog(ctx, serverID, &executorID, models.ActionChannelCreate, "channel", &channel.ID, nil, map[string]interface{}{
		"name": name,
		"type": channelType,
	})

	return &channel, nil
}

func (s *channelService) GetChannel(ctx context.Context, channelID string) (*models.Channel, error) {
	cacheKey := fmt.Sprintf("channel:%s", channelID)
	var channel models.Channel
	err := s.cache.GetJSON(ctx, cacheKey, &channel)
	if err == nil {
		return &channel, nil
	}

	query := `
		SELECT id, server_id, type, name, topic, position, parent_id, slowmode_seconds, default_thread_auto_archive, nsfw, created_at, updated_at
		FROM public.channels
		WHERE id = $1
	`
	err = s.db.QueryRow(ctx, query, channelID).Scan(
		&channel.ID, &channel.ServerID, &channel.Type, &channel.Name, &channel.Topic,
		&channel.Position, &channel.ParentID, &channel.SlowmodeSeconds,
		&channel.DefaultThreadAutoArchive, &channel.NSFW,
		&channel.CreatedAt, &channel.UpdatedAt,
	)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errors.New("channel not found")
		}
		return nil, fmt.Errorf("error fetching channel: %w", err)
	}

	s.cache.SetJSON(ctx, cacheKey, &channel, 30*time.Minute)
	return &channel, nil
}

func (s *channelService) UpdateChannel(ctx context.Context, channelID string, updates map[string]interface{}, executorID string) (*models.Channel, error) {
	// Get current state for permission check and audit log
	oldChannel, err := s.GetChannel(ctx, channelID)
	if err != nil {
		return nil, err
	}

	executorUUID, err := uuid.Parse(executorID)
	if err != nil {
		return nil, fmt.Errorf("invalid executor id: %w", err)
	}

	if oldChannel.ServerID != nil {
		serverUUID, err := uuid.Parse(*oldChannel.ServerID)
		if err != nil {
			return nil, fmt.Errorf("invalid server id: %w", err)
		}

		// Permission Check
		hasPerm, err := s.permService.HasPermission(ctx, executorUUID, serverUUID, "MANAGE_CHANNELS")
		if err != nil {
			return nil, err
		}
		if !hasPerm {
			return nil, errors.New("unauthorized: requires MANAGE_CHANNELS permission")
		}
	}

	// Cache invalidation
	cacheKey := fmt.Sprintf("channel:%s", channelID)
	defer s.cache.Delete(ctx, cacheKey)

	allowedFields := map[string]bool{
		"name":                        true,
		"topic":                       true,
		"position":                    true,
		"parent_id":                   true,
		"slowmode_seconds":            true,
		"default_thread_auto_archive": true,
		"nsfw":                        true,
	}

	setClauses := []string{}
	args := []interface{}{channelID}
	argIdx := 2

	changes := map[string]interface{}{}
	for field, value := range updates {
		if !allowedFields[field] {
			continue
		}
		setClauses = append(setClauses, fmt.Sprintf("%s = $%d", field, argIdx))
		args = append(args, value)
		argIdx++
		changes[field] = value
	}

	if len(setClauses) == 0 {
		return oldChannel, nil
	}

	query := fmt.Sprintf(`
		UPDATE public.channels
		SET %s, updated_at = NOW()
		WHERE id = $1
		RETURNING id, server_id, type, name, topic, position, parent_id, slowmode_seconds, default_thread_auto_archive, nsfw, created_at, updated_at
	`, strings.Join(setClauses, ", "))

	var channel models.Channel
	err = s.db.QueryRow(ctx, query, args...).Scan(
		&channel.ID, &channel.ServerID, &channel.Type, &channel.Name, &channel.Topic,
		&channel.Position, &channel.ParentID, &channel.SlowmodeSeconds,
		&channel.DefaultThreadAutoArchive, &channel.NSFW,
		&channel.CreatedAt, &channel.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("error updating channel: %w", err)
	}

	// Invalidate server channels list if position or parent_id changed
	if channel.ServerID != nil {
		s.cache.Delete(ctx, fmt.Sprintf("server:%s:channels", *channel.ServerID))
		
		// Audit Log
		_ = s.auditService.CreateLog(ctx, *channel.ServerID, &executorID, models.ActionChannelUpdate, "channel", &channel.ID, nil, changes)
	}

	return &channel, nil
}

func (s *channelService) DeleteChannel(ctx context.Context, channelID string, executorID string) error {
	// Get channel first to know serverID for cache invalidation
	channel, err := s.GetChannel(ctx, channelID)
	if err != nil {
		return err
	}

	executorUUID, err := uuid.Parse(executorID)
	if err != nil {
		return fmt.Errorf("invalid executor id: %w", err)
	}

	if channel.ServerID != nil {
		serverUUID, err := uuid.Parse(*channel.ServerID)
		if err != nil {
			return fmt.Errorf("invalid server id: %w", err)
		}

		// Permission Check
		hasPerm, err := s.permService.HasPermission(ctx, executorUUID, serverUUID, "MANAGE_CHANNELS")
		if err != nil {
			return err
		}
		if !hasPerm {
			return errors.New("unauthorized: requires MANAGE_CHANNELS permission")
		}
	}

	query := `DELETE FROM public.channels WHERE id = $1`
	_, err = s.db.Exec(ctx, query, channelID)
	if err != nil {
		return fmt.Errorf("error deleting channel: %w", err)
	}

	s.cache.Delete(ctx, fmt.Sprintf("channel:%s", channelID))
	if channel.ServerID != nil {
		serverID := *channel.ServerID
		s.cache.Delete(ctx, fmt.Sprintf("server:%s:channels", serverID))

		// Audit Log
		_ = s.auditService.CreateLog(ctx, serverID, &executorID, models.ActionChannelDelete, "channel", &channelID, nil, map[string]interface{}{
			"name": channel.Name,
			"type": channel.Type,
		})
	}

	return nil
}

func (s *channelService) GetServerChannels(ctx context.Context, serverID string) ([]*models.Channel, error) {
	cacheKey := fmt.Sprintf("server:%s:channels", serverID)
	var channels []*models.Channel
	err := s.cache.GetJSON(ctx, cacheKey, &channels)
	if err == nil {
		return channels, nil
	}

	query := `
		SELECT id, server_id, type, name, topic, position, parent_id, slowmode_seconds, default_thread_auto_archive, nsfw, created_at, updated_at
		FROM public.channels
		WHERE server_id = $1
		ORDER BY position ASC
	`
	rows, err := s.db.Query(ctx, query, serverID)
	if err != nil {
		return nil, fmt.Errorf("error fetching server channels: %w", err)
	}
	defer rows.Close()

	for rows.Next() {
		var c models.Channel
		err := rows.Scan(
			&c.ID, &c.ServerID, &c.Type, &c.Name, &c.Topic,
			&c.Position, &c.ParentID, &c.SlowmodeSeconds,
			&c.DefaultThreadAutoArchive, &c.NSFW,
			&c.CreatedAt, &c.UpdatedAt,
		)
		if err != nil {
			return nil, fmt.Errorf("error scanning channel: %w", err)
		}
		channels = append(channels, &c)
	}
	if err := rows.Err(); err != nil {
		return nil, fmt.Errorf("error iterating server channels: %w", err)
	}

	s.cache.SetJSON(ctx, cacheKey, &channels, 1*time.Hour)
	return channels, nil
}

func (s *channelService) CheckAccess(ctx context.Context, userID, channelID string) (bool, error) {
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		return false, fmt.Errorf("invalid user id: %w", err)
	}
	channelUUID, err := uuid.Parse(channelID)
	if err != nil {
		return false, fmt.Errorf("invalid channel id: %w", err)
	}

	// Use PermissionService to check if user can view the channel
	return s.permService.HasPermission(ctx, userUUID, channelUUID, "VIEW_CHANNEL")
}
