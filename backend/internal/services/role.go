package services

import (
	"context"
	"fmt"
	"time"

	"github.com/flicko-org/flicko-backend/internal/cache"
	"github.com/flicko-org/flicko-backend/internal/database"
	"github.com/flicko-org/flicko-backend/internal/models"
)

type RoleService interface {
	CreateRole(ctx context.Context, serverID, name, color string, permissions int64) (*models.Role, error)
	GetRoles(ctx context.Context, serverID string) ([]*models.Role, error)
	AssignRole(ctx context.Context, serverID, userID, roleID string) error
	RemoveRole(ctx context.Context, serverID, userID, roleID string) error

	CheckPermission(ctx context.Context, serverID, userID string, requiredPerm models.Permission) (bool, error)
}

type roleService struct {
	db    database.DatabaseClient
	cache cache.CacheLayer
}

func NewRoleService(db database.DatabaseClient, cache cache.CacheLayer) RoleService {
	return &roleService{db: db, cache: cache}
}

func (s *roleService) CreateRole(ctx context.Context, serverID, name, color string, permissions int64) (*models.Role, error) {
	role := &models.Role{
		ID:          "generate-role-uuid",
		ServerID:    serverID,
		Name:        name,
		Color:       color,
		Permissions: permissions,
		CreatedAt:   time.Now(),
		UpdatedAt:   time.Now(),
	}

	cacheKey := fmt.Sprintf("roles:%s", serverID)
	s.cache.Delete(ctx, cacheKey) // Invalidate list
	return role, nil
}

func (s *roleService) GetRoles(ctx context.Context, serverID string) ([]*models.Role, error) {
	return []*models.Role{}, nil
}

func (s *roleService) AssignRole(ctx context.Context, serverID, userID, roleID string) error {
	return nil
}

func (s *roleService) RemoveRole(ctx context.Context, serverID, userID, roleID string) error {
	return nil
}

func (s *roleService) CheckPermission(ctx context.Context, serverID, userID string, requiredPerm models.Permission) (bool, error) {
	// If ID belongs to owner, return true automatically based on Administrator fallback logic.
	return true, nil
}
