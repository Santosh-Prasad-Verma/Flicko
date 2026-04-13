package services

import (
	"context"
	"encoding/json"
	"fmt"
	"time"

	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// ─── Report Service Interface ───────────────────────────────────────────────

type ReportService interface {
	CreateReport(ctx context.Context, serverID, reporterID string, reportType models.ReportType, targetType models.ReportTargetType, targetID, description string, evidence map[string]interface{}) (*models.Report, error)
	GetReports(ctx context.Context, serverID, executorID string, status *models.ReportStatus, limit, offset int) ([]*models.Report, error)
	UpdateReportStatus(ctx context.Context, serverID, reportID, reviewerID string, newStatus models.ReportStatus) (*models.Report, error)
}

type reportService struct {
	db          *pgxpool.Pool
	permService PermissionService
	auditSvc    AuditLogService
}

func NewReportService(db *pgxpool.Pool, permService PermissionService, auditSvc AuditLogService) ReportService {
	return &reportService{
		db:          db,
		permService: permService,
		auditSvc:    auditSvc,
	}
}

func (s *reportService) CreateReport(ctx context.Context, serverID, reporterID string, reportType models.ReportType, targetType models.ReportTargetType, targetID, description string, evidence map[string]interface{}) (*models.Report, error) {
	reporterUUID, err := uuid.Parse(reporterID)
	if err != nil {
		return nil, fmt.Errorf("invalid reporter uuid")
	}

	// ─── Validation ─────────────────────────────────────────────────
	if err := validateReportType(reportType); err != nil {
		return nil, err
	}
	if err := validateReportTargetType(targetType); err != nil {
		return nil, err
	}
	if len(description) < 10 {
		return nil, models.ErrReportDescriptionLength
	}

	targetUUID, err := uuid.Parse(targetID)
	if err != nil {
		return nil, fmt.Errorf("invalid target uuid")
	}

	// ─── Duplicate Detection ────────────────────────────────────────
	var exists bool
	err = s.db.QueryRow(ctx,
		"SELECT EXISTS(SELECT 1 FROM public.reports WHERE reporter_id = $1 AND target_id = $2 AND status IN ('pending', 'under_review'))",
		reporterUUID, targetUUID,
	).Scan(&exists)
	if err != nil {
		return nil, fmt.Errorf("failed to check for duplicates: %w", err)
	}
	if exists {
		return nil, models.ErrDuplicateReport
	}

	// ─── Membership Validation (if server-scoped) ───────────────────
	var serverUUID *uuid.UUID
	if serverID != "" {
		parsed, err := uuid.Parse(serverID)
		if err != nil {
			return nil, fmt.Errorf("invalid server uuid")
		}
		serverUUID = &parsed

		var isMember bool
		err = s.db.QueryRow(ctx, "SELECT EXISTS(SELECT 1 FROM public.server_members WHERE server_id = $1 AND user_id = $2)", parsed, reporterUUID).Scan(&isMember)
		if err != nil {
			return nil, fmt.Errorf("failed to verify membership: %w", err)
		}
		if !isMember {
			return nil, fmt.Errorf("user is not a member of this server")
		}
	}

	// ─── Evidence Serialization ─────────────────────────────────────
	var evidenceJSON []byte
	if evidence != nil {
		evidenceJSON, err = json.Marshal(evidence)
		if err != nil {
			return nil, fmt.Errorf("failed to serialize evidence: %w", err)
		}
	}

	// ─── Insert ─────────────────────────────────────────────────────
	query := `
		INSERT INTO public.reports (server_id, reporter_id, report_type, target_type, target_id, description, evidence, status)
		VALUES ($1, $2, $3, $4, $5, $6, $7, 'pending')
		RETURNING id, server_id, reporter_id, report_type, target_type, target_id, description, evidence, status, reviewed_by, reviewed_at, created_at, updated_at
	`

	var report models.Report
	err = s.db.QueryRow(ctx, query, serverUUID, reporterUUID, reportType, targetType, targetUUID, description, evidenceJSON).
		Scan(&report.ID, &report.ServerID, &report.ReporterID, &report.ReportType, &report.TargetType, &report.TargetID, &report.Description, &report.Evidence, &report.Status, &report.ReviewedBy, &report.ReviewedAt, &report.CreatedAt, &report.UpdatedAt)
	if err != nil {
		return nil, fmt.Errorf("failed to insert report: %w", err)
	}

	return &report, nil
}

func (s *reportService) GetReports(ctx context.Context, serverID, executorID string, status *models.ReportStatus, limit, offset int) ([]*models.Report, error) {
	serverUUID, err1 := uuid.Parse(serverID)
	executorUUID, err2 := uuid.Parse(executorID)
	if err1 != nil || err2 != nil {
		return nil, fmt.Errorf("invalid uuid")
	}

	hasPerm, err := s.permService.HasPermission(ctx, executorUUID, serverUUID, "MANAGE_GUILD")
	if err != nil {
		return nil, err
	}
	if !hasPerm {
		return nil, fmt.Errorf("unauthorized: requires MANAGE_GUILD permission")
	}

	if limit <= 0 || limit > 100 {
		limit = 50
	}
	if offset < 0 {
		offset = 0
	}

	args := []interface{}{serverUUID, limit, offset}
	whereExtra := ""
	if status != nil {
		whereExtra = " AND status = $4"
		args = append(args, *status)
	}

	query := fmt.Sprintf(`
		SELECT id, server_id, reporter_id, report_type, target_type, target_id, description, evidence, status, reviewed_by, reviewed_at, created_at, updated_at
		FROM public.reports
		WHERE server_id = $1 %s
		ORDER BY created_at DESC
		LIMIT $2 OFFSET $3
	`, whereExtra)

	rows, err := s.db.Query(ctx, query, args...)
	if err != nil {
		return nil, fmt.Errorf("failed to query reports: %w", err)
	}
	defer rows.Close()

	var reports []*models.Report
	for rows.Next() {
		var r models.Report
		if err := rows.Scan(&r.ID, &r.ServerID, &r.ReporterID, &r.ReportType, &r.TargetType, &r.TargetID, &r.Description, &r.Evidence, &r.Status, &r.ReviewedBy, &r.ReviewedAt, &r.CreatedAt, &r.UpdatedAt); err != nil {
			return nil, err
		}
		reports = append(reports, &r)
	}

	return reports, nil
}

func (s *reportService) UpdateReportStatus(ctx context.Context, serverID, reportID, reviewerID string, newStatus models.ReportStatus) (*models.Report, error) {
	serverUUID, err1 := uuid.Parse(serverID)
	reportUUID, err2 := uuid.Parse(reportID)
	reviewerUUID, err3 := uuid.Parse(reviewerID)
	if err1 != nil || err2 != nil || err3 != nil {
		return nil, fmt.Errorf("invalid uuid")
	}

	hasPerm, err := s.permService.HasPermission(ctx, reviewerUUID, serverUUID, "MANAGE_GUILD")
	if err != nil {
		return nil, err
	}
	if !hasPerm {
		return nil, fmt.Errorf("unauthorized: requires MANAGE_GUILD permission")
	}

	if err := validateReportStatus(newStatus); err != nil {
		return nil, err
	}

	now := time.Now()
	query := `
		UPDATE public.reports
		SET status = $3, reviewed_by = $4, reviewed_at = $5, updated_at = NOW()
		WHERE id = $1 AND server_id = $2
		RETURNING id, server_id, reporter_id, report_type, target_type, target_id, description, evidence, status, reviewed_by, reviewed_at, created_at, updated_at
	`

	var r models.Report
	err = s.db.QueryRow(ctx, query, reportUUID, serverUUID, newStatus, reviewerUUID, now).
		Scan(&r.ID, &r.ServerID, &r.ReporterID, &r.ReportType, &r.TargetType, &r.TargetID, &r.Description, &r.Evidence, &r.Status, &r.ReviewedBy, &r.ReviewedAt, &r.CreatedAt, &r.UpdatedAt)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, fmt.Errorf("report not found")
		}
		return nil, fmt.Errorf("failed to update report: %w", err)
	}

	// Audit
	_ = s.auditSvc.CreateLog(ctx, serverID, &reviewerID, models.AuditLogAction("report_status_change"), "report", &reportID, nil,
		map[string]interface{}{"new_status": newStatus})

	return &r, nil
}

// ─── Validators ─────────────────────────────────────────────────────────────

func validateReportType(rt models.ReportType) error {
	switch rt {
	case models.ReportHarassment, models.ReportSpam, models.ReportInappropriateContent, models.ReportOther:
		return nil
	}
	return fmt.Errorf("invalid report_type: %s", rt)
}

func validateReportTargetType(tt models.ReportTargetType) error {
	switch tt {
	case models.ReportTargetMessage, models.ReportTargetUser, models.ReportTargetServer:
		return nil
	}
	return fmt.Errorf("invalid target_type: %s", tt)
}

func validateReportStatus(s models.ReportStatus) error {
	switch s {
	case models.ReportStatusPending, models.ReportStatusUnderReview, models.ReportStatusResolved, models.ReportStatusDismissed:
		return nil
	}
	return fmt.Errorf("invalid report status: %s", s)
}
