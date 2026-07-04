package services

import (
	"context"
	"fmt"
	"time"

	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type MemberRoleService interface {
	AddRole(ctx context.Context, serverID, userID, roleID, executorID string) error
	RemoveRole(ctx context.Context, serverID, userID, roleID, executorID string) error
	GetRoles(ctx context.Context, serverID, userID string) ([]*models.MemberRole, error)
}

type memberRoleService struct {
	db           *pgxpool.Pool
	permService  PermissionService
	auditService AuditLogService
}

func NewMemberRoleService(db *pgxpool.Pool, permService PermissionService, auditService AuditLogService) MemberRoleService {
	return &memberRoleService{
		db:           db,
		permService:  permService,
		auditService: auditService,
	}
}

func (s *memberRoleService) validateHierarchy(ctx context.Context, serverUUID, targetRoleUUID, executorUUID uuid.UUID) error {
	var isOwner bool
	err := s.db.QueryRow(ctx, "SELECT owner_id = $1 FROM public.servers WHERE id = $2", executorUUID, serverUUID).Scan(&isOwner)
	if err != nil {
		return fmt.Errorf("failed to check server owner: %w", err)
	}
	if isOwner {
		return nil // Owner bypasses hierarchy
	}

	// Get target role position
	var targetPos int
	err = s.db.QueryRow(ctx, "SELECT position FROM public.roles WHERE id = $1", targetRoleUUID).Scan(&targetPos)
	if err != nil {
		return fmt.Errorf("target role not found: %w", err)
	}

	// Get executor highest role position
	var executorHighestPos int
	query := `
		SELECT COALESCE(MAX(r.position), -1) 
		FROM public.member_roles mr 
		JOIN public.roles r ON mr.role_id = r.id 
		WHERE mr.server_id = $1 AND mr.user_id = $2
	`
	err = s.db.QueryRow(ctx, query, serverUUID, executorUUID).Scan(&executorHighestPos)
	if err != nil {
		return fmt.Errorf("failed to determine executor highest role: %w", err)
	}

	if executorHighestPos <= targetPos {
		return fmt.Errorf("role hierarchy violation: cannot manage a role higher or equal to your highest role")
	}

	return nil
}

func (s *memberRoleService) AddRole(ctx context.Context, serverID, userID, roleID, executorID string) error {
	serverUUID, err1 := uuid.Parse(serverID)
	userUUID, err2 := uuid.Parse(userID)
	roleUUID, err3 := uuid.Parse(roleID)
	executorUUID, err4 := uuid.Parse(executorID)

	if err1 != nil || err2 != nil || err3 != nil || err4 != nil {
		return fmt.Errorf("invalid uuid")
	}

	// We can pass null channel (uuid.Nil) to check server-wide permission
	hasPerm, err := s.permService.HasPermission(ctx, executorUUID, serverUUID, "MANAGE_ROLES")
	if err != nil {
		return err
	}
	if !hasPerm {
		return fmt.Errorf("unauthorized: requires MANAGE_ROLES permission")
	}

	if err := s.validateHierarchy(ctx, serverUUID, roleUUID, executorUUID); err != nil {
		return err
	}

	_, err = s.db.Exec(ctx, "INSERT INTO public.member_roles (server_id, user_id, role_id) VALUES ($1, $2, $3) ON CONFLICT DO NOTHING", serverUUID, userUUID, roleUUID)
	if err != nil {
		return fmt.Errorf("failed to assign role: %w", err)
	}

	// Invalidate permission cache
	_ = s.permService.InvalidateServerCache(ctx, serverUUID)

	// Audit Log
	_ = s.auditService.CreateLog(ctx, serverID, &executorID, models.ActionMemberRoleUpdate, "user", &userID, nil, map[string]interface{}{
		"added_role_id": roleID,
	})

	return nil
}

func (s *memberRoleService) RemoveRole(ctx context.Context, serverID, userID, roleID, executorID string) error {
	serverUUID, err1 := uuid.Parse(serverID)
	userUUID, err2 := uuid.Parse(userID)
	roleUUID, err3 := uuid.Parse(roleID)
	executorUUID, err4 := uuid.Parse(executorID)

	if err1 != nil || err2 != nil || err3 != nil || err4 != nil {
		return fmt.Errorf("invalid uuid")
	}

	// We can pass null channel to check server-wide permission
	hasPerm, err := s.permService.HasPermission(ctx, executorUUID, serverUUID, "MANAGE_ROLES")
	if err != nil {
		return err
	}
	if !hasPerm {
		return fmt.Errorf("unauthorized: requires MANAGE_ROLES permission")
	}

	if err := s.validateHierarchy(ctx, serverUUID, roleUUID, executorUUID); err != nil {
		return err
	}

	res, err := s.db.Exec(ctx, "DELETE FROM public.member_roles WHERE server_id = $1 AND user_id = $2 AND role_id = $3", serverUUID, userUUID, roleUUID)
	if err != nil {
		return err
	}
	if res.RowsAffected() == 0 {
		return fmt.Errorf("role not assigned to user")
	}

	// Invalidate permission cache
	_ = s.permService.InvalidateServerCache(ctx, serverUUID)

	// Audit Log
	_ = s.auditService.CreateLog(ctx, serverID, &executorID, models.ActionMemberRoleUpdate, "user", &userID, nil, map[string]interface{}{
		"removed_role_id": roleID,
	})

	return nil
}

func (s *memberRoleService) GetRoles(ctx context.Context, serverID, userID string) ([]*models.MemberRole, error) {
	serverUUID, err1 := uuid.Parse(serverID)
	userUUID, err2 := uuid.Parse(userID)
	if err1 != nil || err2 != nil {
		return nil, fmt.Errorf("invalid uuid")
	}

	query := `SELECT server_id, user_id, role_id, assigned_at FROM public.member_roles WHERE server_id = $1 AND user_id = $2`
	rows, err := s.db.Query(ctx, query, serverUUID, userUUID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var roles []*models.MemberRole
	for rows.Next() {
		mr := &models.MemberRole{}
		var addedAt time.Time
		if err := rows.Scan(&mr.ServerID, &mr.UserID, &mr.RoleID, &addedAt); err != nil {
			return nil, err
		}
		mr.AddedAt = addedAt
		roles = append(roles, mr)
	}

	return roles, nil
}
