package services

import (
	"context"
	"fmt"
	"time"

	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// ─── Warning Service Interface ──────────────────────────────────────────────

type WarningService interface {
	IssueWarning(ctx context.Context, serverID, userID, moderatorID, reason string, severity models.WarningSeverity) (*models.Warning, *EscalationAction, error)
	GetWarnings(ctx context.Context, serverID, userID, executorID string) ([]*models.Warning, error)
	GetWarningCount(ctx context.Context, serverID, userID string) (int, error)
}

// EscalationAction describes what automatic action was triggered due to warning accumulation.
type EscalationAction struct {
	Action       string `json:"action"` // "timeout", "kick", or ""
	WarningCount int    `json:"warning_count"`
	Threshold    int    `json:"threshold"`
	IsEscalated  bool   `json:"is_escalated"`
}

// ─── Implementation ─────────────────────────────────────────────────────────

type warningService struct {
	db          *pgxpool.Pool
	permService PermissionService
	auditSvc    AuditLogService
	thresholds  models.EscalationThresholds
}

func NewWarningService(db *pgxpool.Pool, permService PermissionService, auditSvc AuditLogService) WarningService {
	return &warningService{
		db:          db,
		permService: permService,
		auditSvc:    auditSvc,
		thresholds:  models.DefaultEscalation,
	}
}

func (s *warningService) IssueWarning(ctx context.Context, serverID, userID, moderatorID, reason string, severity models.WarningSeverity) (*models.Warning, *EscalationAction, error) {
	serverUUID, err1 := uuid.Parse(serverID)
	userUUID, err2 := uuid.Parse(userID)
	modUUID, err3 := uuid.Parse(moderatorID)

	if err1 != nil || err2 != nil || err3 != nil {
		return nil, nil, fmt.Errorf("invalid uuid")
	}

	// ─── Validation ─────────────────────────────────────────────────
	if err := validateSeverity(severity); err != nil {
		return nil, nil, err
	}
	if len(reason) == 0 {
		return nil, nil, fmt.Errorf("reason is required")
	}

	// ─── Permission Check (KICK_MEMBERS or BAN_MEMBERS) ─────────────
	hasKick, err := s.permService.HasPermission(ctx, modUUID, serverUUID, "KICK_MEMBERS")
	if err != nil {
		return nil, nil, err
	}
	hasBan, err := s.permService.HasPermission(ctx, modUUID, serverUUID, "BAN_MEMBERS")
	if err != nil {
		return nil, nil, err
	}
	if !hasKick && !hasBan {
		return nil, nil, fmt.Errorf("unauthorized: requires KICK_MEMBERS or BAN_MEMBERS permission")
	}

	// ─── Prevent Self-Warning ───────────────────────────────────────
	if userID == moderatorID {
		return nil, nil, fmt.Errorf("cannot warn yourself")
	}

	// ─── Insert Warning ─────────────────────────────────────────────
	tx, err := s.db.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return nil, nil, err
	}
	defer tx.Rollback(ctx)

	query := `
		INSERT INTO public.warnings (server_id, user_id, moderator_id, reason, severity)
		VALUES ($1, $2, $3, $4, $5)
		RETURNING id, server_id, user_id, moderator_id, reason, severity, created_at
	`

	var w models.Warning
	err = tx.QueryRow(ctx, query, serverUUID, userUUID, modUUID, reason, severity).
		Scan(&w.ID, &w.ServerID, &w.UserID, &w.ModeratorID, &w.Reason, &w.Severity, &w.CreatedAt)
	if err != nil {
		return nil, nil, fmt.Errorf("failed to insert warning: %w", err)
	}

	// ─── Count Warnings for Escalation ──────────────────────────────
	var warningCount int
	err = tx.QueryRow(ctx, "SELECT COUNT(*) FROM public.warnings WHERE server_id = $1 AND user_id = $2", serverUUID, userUUID).Scan(&warningCount)
	if err != nil {
		return nil, nil, err
	}

	escalation := &EscalationAction{
		WarningCount: warningCount,
		IsEscalated:  false,
	}

	// ─── Automatic Escalation Logic ─────────────────────────────────
	if warningCount >= s.thresholds.KickAt {
		escalation.Action = "kick"
		escalation.Threshold = s.thresholds.KickAt
		escalation.IsEscalated = true

		// Audit the escalation
		_ = s.auditSvc.CreateLog(ctx, serverID, nil, models.ActionMemberKick, "user", &userID,
			strPtr(fmt.Sprintf("Auto-escalation: %d warnings reached kick threshold", warningCount)),
			map[string]interface{}{"warning_count": warningCount, "trigger": "auto_escalation"},
		)
	} else if warningCount >= s.thresholds.TimeoutAt {
		escalation.Action = "timeout"
		escalation.Threshold = s.thresholds.TimeoutAt
		escalation.IsEscalated = true

		// Audit the escalation
		_ = s.auditSvc.CreateLog(ctx, serverID, nil, models.ActionMemberKick, "user", &userID,
			strPtr(fmt.Sprintf("Auto-escalation: %d warnings reached timeout threshold", warningCount)),
			map[string]interface{}{"warning_count": warningCount, "trigger": "auto_escalation"},
		)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, nil, err
	}

	// Audit the warning itself
	_ = s.auditSvc.CreateLog(ctx, serverID, &moderatorID, models.AuditLogAction("member_warn"), "user", &userID, &reason,
		map[string]interface{}{"severity": severity, "total_warnings": warningCount},
	)

	return &w, escalation, nil
}

func (s *warningService) GetWarnings(ctx context.Context, serverID, userID, executorID string) ([]*models.Warning, error) {
	serverUUID, err1 := uuid.Parse(serverID)
	userUUID, err2 := uuid.Parse(userID)
	executorUUID, err3 := uuid.Parse(executorID)
	if err1 != nil || err2 != nil || err3 != nil {
		return nil, fmt.Errorf("invalid uuid")
	}

	// Allow if user is looking at own warnings OR has MANAGE_GUILD
	if executorUUID != userUUID {
		hasPerm, err := s.permService.HasPermission(ctx, executorUUID, serverUUID, "MANAGE_GUILD")
		if err != nil {
			return nil, err
		}
		if !hasPerm {
			return nil, fmt.Errorf("unauthorized: you can only view your own warnings or require MANAGE_GUILD")
		}
	}

	rows, err := s.db.Query(ctx, `
		SELECT id, server_id, user_id, moderator_id, reason, severity, created_at
		FROM public.warnings
		WHERE server_id = $1 AND user_id = $2
		ORDER BY created_at DESC
	`, serverUUID, userUUID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var warnings []*models.Warning
	for rows.Next() {
		w := &models.Warning{}
		if err := rows.Scan(&w.ID, &w.ServerID, &w.UserID, &w.ModeratorID, &w.Reason, &w.Severity, &w.CreatedAt); err != nil {
			return nil, err
		}
		warnings = append(warnings, w)
	}

	return warnings, nil
}

func (s *warningService) GetWarningCount(ctx context.Context, serverID, userID string) (int, error) {
	serverUUID, err1 := uuid.Parse(serverID)
	userUUID, err2 := uuid.Parse(userID)
	if err1 != nil || err2 != nil {
		return 0, fmt.Errorf("invalid uuid")
	}

	var count int
	err := s.db.QueryRow(ctx, "SELECT COUNT(*) FROM public.warnings WHERE server_id = $1 AND user_id = $2", serverUUID, userUUID).Scan(&count)
	return count, err
}

// ─── Helpers ────────────────────────────────────────────────────────────────

func validateSeverity(s models.WarningSeverity) error {
	switch s {
	case models.SeverityLow, models.SeverityMedium, models.SeverityHigh, models.SeverityCritical:
		return nil
	}
	return models.ErrInvalidSeverity
}

func strPtr(s string) *string {
	return &s
}

// ─── Warning Acknowledger (Optional Advanced Pattern) ───────────────────────

// AcknowledgeInfo is a potential extension point. Users can acknowledge
// warnings, and the system tracks whether they've read the notice.
type AcknowledgeInfo struct {
	WarningID      string    `json:"warning_id"`
	AcknowledgedAt time.Time `json:"acknowledged_at"`
}
