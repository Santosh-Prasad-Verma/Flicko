package services

import (
	"context"
	"encoding/json"
	"fmt"
	"strings"
	"time"

	"github.com/flicko-org/flicko-backend/internal/cache"
	"github.com/flicko-org/flicko-backend/internal/database"
	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/google/uuid"
)

type AuditLogService interface {
	CreateLog(ctx context.Context, serverID string, actorID *string, actionType models.AuditLogAction, targetType string, targetID, reason *string, changes map[string]interface{}) error
	GetLogs(ctx context.Context, serverID, executorID string, actionType, actorID, targetType *string, limit, offset int) ([]*models.AuditLog, error)
}

type auditLogService struct {
	db          database.DatabaseClient
	cache       cache.CacheLayer
	permService PermissionService
}

func NewAuditLogService(db database.DatabaseClient, cache cache.CacheLayer, permService PermissionService) AuditLogService {
	return &auditLogService{
		db:          db,
		cache:       cache,
		permService: permService,
	}
}

func (s *auditLogService) CreateLog(ctx context.Context, serverID string, actorID *string, actionType models.AuditLogAction, targetType string, targetID, reason *string, changes map[string]interface{}) error {
	serverUUID, err := uuid.Parse(serverID)
	if err != nil {
		return fmt.Errorf("invalid server uuid")
	}

	var actorUUID *uuid.UUID
	if actorID != nil {
		id, err := uuid.Parse(*actorID)
		if err != nil {
			return fmt.Errorf("invalid actor uuid")
		}
		actorUUID = &id
	}

	var targetUUID *uuid.UUID
	if targetID != nil {
		id, err := uuid.Parse(*targetID)
		if err != nil {
			return fmt.Errorf("invalid target uuid")
		}
		targetUUID = &id
	}

	// Create the raw audit log model (with a generated UUID and current time)
	log := &models.AuditLog{
		ID:         uuid.New().String(),
		ServerID:   serverUUID.String(),
		ActionType: actionType,
		TargetType: targetType,
		CreatedAt:  time.Now().UTC(),
	}
	if actorUUID != nil {
		actStr := actorUUID.String()
		log.ActorID = &actStr
	}
	if targetUUID != nil {
		tgtStr := targetUUID.String()
		log.TargetID = &tgtStr
	}
	if reason != nil {
		log.Reason = reason
	}
	if changes != nil {
		log.Changes = changes
	}

	payload, err := json.Marshal(log)
	if err != nil {
		return fmt.Errorf("failed to serialize audit log for queue: %w", err)
	}

	// Push onto the list
	redisClient := s.cache.GetRedisClient()
	err = redisClient.LPush(ctx, "flicko:audit:queue", payload).Err()
	if err != nil {
		return fmt.Errorf("failed to queue audit log: %w", err)
	}

	return nil
}

func (s *auditLogService) GetLogs(ctx context.Context, serverID, executorID string, actionType, actorID, targetType *string, limit, offset int) ([]*models.AuditLog, error) {
	serverUUID, err1 := uuid.Parse(serverID)
	executorUUID, err2 := uuid.Parse(executorID)
	if err1 != nil || err2 != nil {
		return nil, fmt.Errorf("invalid uuid")
	}

	hasPerm, err := s.permService.HasPermission(ctx, executorUUID, serverUUID, "VIEW_AUDIT_LOG")
	if err != nil {
		return nil, err
	}
	if !hasPerm {
		return nil, fmt.Errorf("unauthorized: requires VIEW_AUDIT_LOG permission")
	}

	if limit <= 0 || limit > 100 {
		limit = 100
	}
	if offset < 0 {
		offset = 0
	}

	whereClauses := []string{"server_id = $1"}
	args := []interface{}{serverUUID}
	argID := 2

	if actionType != nil {
		whereClauses = append(whereClauses, fmt.Sprintf("action_type = $%d", argID))
		args = append(args, *actionType)
		argID++
	}
	if actorID != nil {
		aID, err := uuid.Parse(*actorID)
		if err != nil {
			return nil, fmt.Errorf("invalid actor uuid filter")
		}
		whereClauses = append(whereClauses, fmt.Sprintf("actor_id = $%d", argID))
		args = append(args, aID)
		argID++
	}
	if targetType != nil {
		whereClauses = append(whereClauses, fmt.Sprintf("target_type = $%d", argID))
		args = append(args, *targetType)
		argID++
	}

	args = append(args, limit, offset)
	limitArg := argID
	offsetArg := argID + 1

	query := fmt.Sprintf(`
		SELECT id, server_id, actor_id, action_type, target_type, target_id, reason, changes, created_at
		FROM public.audit_logs
		WHERE %s
		ORDER BY created_at DESC
		LIMIT $%d OFFSET $%d
	`, strings.Join(whereClauses, " AND "), limitArg, offsetArg)

	rows, err := s.db.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to query audit logs: %w", err)
	}
	defer rows.Close()

	var logs []*models.AuditLog
	for rows.Next() {
		var log models.AuditLog
		var actorID, targetID *uuid.UUID
		if err := rows.Scan(
			&log.ID, &log.ServerID, &actorID, &log.ActionType, &log.TargetType, &targetID, &log.Reason, &log.Changes, &log.CreatedAt,
		); err != nil {
			return nil, err
		}
		if actorID != nil {
			a := actorID.String()
			log.ActorID = &a
		}
		if targetID != nil {
			t := targetID.String()
			log.TargetID = &t
		}
		logs = append(logs, &log)
	}

	return logs, nil
}
