package services

import (
	"context"
	"fmt"

	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type PermissionOverwriteService interface {
	SetOverwrite(ctx context.Context, channelID, targetType, targetID string, allow, deny int64, executorID string) error
	RemoveOverwrite(ctx context.Context, channelID, targetType, targetID string, executorID string) error
}

type permissionOverwriteService struct {
	db           *pgxpool.Pool
	permService  PermissionService
	auditService AuditLogService
}

func NewPermissionOverwriteService(db *pgxpool.Pool, permService PermissionService, auditService AuditLogService) PermissionOverwriteService {
	return &permissionOverwriteService{
		db:           db,
		permService:  permService,
		auditService: auditService,
	}
}

func (s *permissionOverwriteService) SetOverwrite(ctx context.Context, channelID, targetType, targetID string, allow, deny int64, executorID string) error {
	chanUUID, err1 := uuid.Parse(channelID)
	executorUUID, err2 := uuid.Parse(executorID)
	targetUUID, err3 := uuid.Parse(targetID)

	if err1 != nil || err2 != nil || err3 != nil {
		return fmt.Errorf("invalid uuid")
	}

	if targetType != "role" && targetType != "user" {
		return fmt.Errorf("targetType must be 'role' or 'user'")
	}

	hasPerm, err := s.permService.HasPermission(ctx, executorUUID, chanUUID, "MANAGE_ROLES")
	if err != nil {
		return fmt.Errorf("permission check failed: %w", err)
	}
	if !hasPerm {
		return fmt.Errorf("unauthorized: requires MANAGE_ROLES permission")
	}

	query := `
		INSERT INTO public.permission_overwrites (channel_id, target_type, target_id, allow, deny, updated_at)
		VALUES ($1, $2, $3, $4, $5, NOW())
		ON CONFLICT (channel_id, target_type, target_id) 
		DO UPDATE SET allow = EXCLUDED.allow, deny = EXCLUDED.deny, updated_at = NOW()
	`

	_, err = s.db.Exec(ctx, query, chanUUID, targetType, targetUUID, allow, deny)
	if err != nil {
		return fmt.Errorf("failed to upsert permission overwrite: %w", err)
	}

	// Invalidate permission cache
	if targetType == "user" {
		_ = s.permService.InvalidatePermissionCache(ctx, targetUUID, chanUUID)
	} else {
		// For roles, we ideally invalidate all users with that role.
		// For now, we clear the entire channel's cache for safety.
		// A more surgical approach would use a Redis SET of user IDs per role.
		_ = s.permService.InvalidatePermissionCache(ctx, uuid.Nil, chanUUID)
	}

	// Audit Log
	_ = s.auditService.CreateLog(ctx, "server-id-placeholder", &executorID, models.ActionMemberRoleUpdate, "channel", &channelID, nil, map[string]interface{}{
		"overwrite_target_type": targetType,
		"overwrite_target_id":   targetID,
		"allow":                 allow,
		"deny":                  deny,
	})

	return nil
}

func (s *permissionOverwriteService) RemoveOverwrite(ctx context.Context, channelID, targetType, targetID string, executorID string) error {
	chanUUID, err1 := uuid.Parse(channelID)
	executorUUID, err2 := uuid.Parse(executorID)
	targetUUID, err3 := uuid.Parse(targetID)

	if err1 != nil || err2 != nil || err3 != nil {
		return fmt.Errorf("invalid uuid")
	}

	hasPerm, err := s.permService.HasPermission(ctx, executorUUID, chanUUID, "MANAGE_ROLES")
	if err != nil {
		return fmt.Errorf("permission check failed: %w", err)
	}
	if !hasPerm {
		return fmt.Errorf("unauthorized: requires MANAGE_ROLES permission")
	}

	res, err := s.db.Exec(ctx, "DELETE FROM public.permission_overwrites WHERE channel_id = $1 AND target_type = $2 AND target_id = $3", chanUUID, targetType, targetUUID)
	if err != nil {
		return fmt.Errorf("failed to remove permission overwrite: %w", err)
	}
	if res.RowsAffected() == 0 {
		return fmt.Errorf("overwrite not found")
	}

	return nil
}
