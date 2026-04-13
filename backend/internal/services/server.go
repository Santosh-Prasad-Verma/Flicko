package services

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/flicko-org/flicko-backend/internal/cache"
	"github.com/flicko-org/flicko-backend/internal/database"
	"github.com/flicko-org/flicko-backend/internal/models"
)

type ServerService interface {
	CreateServer(ctx context.Context, ownerID, name, description, icon string) (*models.Server, error)
	GetServer(ctx context.Context, serverID string) (*models.Server, error)
	UpdateServer(ctx context.Context, serverID string, updates map[string]interface{}) (*models.Server, error)
	DeleteServer(ctx context.Context, serverID string) error

	JoinServer(ctx context.Context, userID, inviteCode string) (*models.Member, error)
	LeaveServer(ctx context.Context, serverID, userID string) error
	GetServerMembers(ctx context.Context, serverID string) ([]*models.Member, error)
}

type serverService struct {
	db    database.DatabaseClient
	cache cache.CacheLayer
}

func NewServerService(db database.DatabaseClient, cache cache.CacheLayer) ServerService {
	return &serverService{
		db:    db,
		cache: cache,
	}
}

func (s *serverService) CreateServer(ctx context.Context, ownerID, name, description, icon string) (*models.Server, error) {
	if len(name) < 2 || len(name) > 100 {
		return nil, errors.New("server name must be between 2 and 100 characters")
	}

	server := &models.Server{
		ID:          "generate-uuid", // MVP stub
		Name:        name,
		Description: description,
		OwnerID:     ownerID,
		IconURL:     icon,
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
	}

	// Persist to DB -> error logic goes here for true MVP if err
	cacheKey := fmt.Sprintf("server:%s", server.ID)
	s.cache.SetJSON(ctx, cacheKey, server, 10*time.Minute)

	return server, nil
}

func (s *serverService) GetServer(ctx context.Context, serverID string) (*models.Server, error) {
	cacheKey := fmt.Sprintf("server:%s", serverID)
	var server models.Server
	err := s.cache.GetJSON(ctx, cacheKey, &server)
	if err == nil {
		return &server, nil
	}

	// Fetch from DB
	if s.db == nil {
		return &models.Server{ID: serverID, Name: "MockServer"}, nil
	}

	return nil, errors.New("server not found")
}

func (s *serverService) UpdateServer(ctx context.Context, serverID string, updates map[string]interface{}) (*models.Server, error) {
	cacheKey := fmt.Sprintf("server:%s", serverID)
	s.cache.Delete(ctx, cacheKey)

	// Update DB
	return &models.Server{ID: serverID, Name: "UpdatedMockServer"}, nil
}

func (s *serverService) DeleteServer(ctx context.Context, serverID string) error {
	cacheKey := fmt.Sprintf("server:%s", serverID)
	s.cache.Delete(ctx, cacheKey)

	return nil
}

func (s *serverService) JoinServer(ctx context.Context, userID, inviteCode string) (*models.Member, error) {
	// Validate invite code and existence
	if inviteCode == "" {
		return nil, errors.New("invalid invite code") // 404 effectively
	}

	member := &models.Member{
		ID:       "uuid-member",
		ServerID: "test-server-id",
		UserID:   userID,
		JoinedAt: time.Now(),
	}

	return member, nil
}

func (s *serverService) LeaveServer(ctx context.Context, serverID, userID string) error {
	return nil
}

func (s *serverService) GetServerMembers(ctx context.Context, serverID string) ([]*models.Member, error) {
	return []*models.Member{}, nil
}
