package handlers

import (
	"encoding/json"
	"io"
	"net/http"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/gorilla/mux"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"
)

const (
	defaultExportFormat            = "json"
	defaultExportRetentionDays     = 30
	defaultExportRetentionDuration = time.Duration(defaultExportRetentionDays) * 24 * time.Hour
	defaultDeletionGraceDays       = 7
	defaultDeletionRetentionDays   = 30
)

type PrivacyHandler struct {
	db     *pgxpool.Pool
	logger *zap.Logger
}

func NewPrivacyHandler(db *pgxpool.Pool, logger *zap.Logger) *PrivacyHandler {
	return &PrivacyHandler{
		db:     db,
		logger: logger.Named("handler.privacy"),
	}
}

type exportRequest struct {
	Format string `json:"format"`
}

type exportArtifactResponse struct {
	ID             string     `json:"id"`
	Status         string     `json:"status"`
	StoragePath    string     `json:"storage_path,omitempty"`
	FileName       string     `json:"file_name,omitempty"`
	ContentType    string     `json:"content_type,omitempty"`
	FileSizeBytes  *int64     `json:"file_size_bytes,omitempty"`
	Checksum       string     `json:"checksum,omitempty"`
	RetentionUntil *time.Time `json:"retention_until,omitempty"`
	CreatedAt      time.Time  `json:"created_at"`
	UpdatedAt      time.Time  `json:"updated_at"`
}

type deleteAccountRequest struct {
	Reason string `json:"reason"`
}

type deletionAuditEntryResponse struct {
	ID           string                 `json:"id"`
	EventType    string                 `json:"event_type"`
	EventMessage string                 `json:"event_message,omitempty"`
	EventMeta    map[string]interface{} `json:"event_metadata,omitempty"`
	CreatedAt    time.Time              `json:"created_at"`
}

func (h *PrivacyHandler) RequestExport(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid user id")
		return
	}

	req := exportRequest{Format: defaultExportFormat}
	if r.Body != nil {
		decErr := json.NewDecoder(r.Body).Decode(&req)
		if decErr != nil && decErr != io.EOF {
			writeError(w, http.StatusBadRequest, "invalid request body")
			return
		}
	}
	req.Format = strings.ToLower(strings.TrimSpace(req.Format))
	if req.Format == "" {
		req.Format = defaultExportFormat
	}
	if req.Format != defaultExportFormat {
		writeError(w, http.StatusBadRequest, "unsupported export format")
		return
	}

	tx, err := h.db.Begin(r.Context())
	if err != nil {
		h.logger.Error("failed to begin export request transaction", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to create export job")
		return
	}
	defer tx.Rollback(r.Context()) //nolint:errcheck

	var jobID uuid.UUID
	var status string
	var requestedAt time.Time
	var expiresAt *time.Time
	if err = tx.QueryRow(r.Context(), `
		INSERT INTO public.data_export_jobs (user_id, format, status, progress_percent, requested_at, expires_at)
		VALUES ($1, $2, 'queued', 0, NOW(), NOW() + INTERVAL '30 days')
		RETURNING id, status, requested_at, expires_at
	`, userUUID, req.Format).Scan(&jobID, &status, &requestedAt, &expiresAt); err != nil {
		h.logger.Error("failed to create data export job", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to create export job")
		return
	}

	var artifactID uuid.UUID
	retentionUntil := time.Now().UTC().Add(defaultExportRetentionDuration)
	if err = tx.QueryRow(r.Context(), `
		INSERT INTO public.data_export_artifacts (job_id, user_id, status, retention_until)
		VALUES ($1, $2, 'pending', $3)
		RETURNING id
	`, jobID, userUUID, retentionUntil).Scan(&artifactID); err != nil {
		h.logger.Error("failed to create data export artifact placeholder", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to create export job")
		return
	}

	if err = tx.Commit(r.Context()); err != nil {
		h.logger.Error("failed to commit export request transaction", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to create export job")
		return
	}

	writeJSON(w, http.StatusAccepted, map[string]interface{}{
		"job_id":         jobID.String(),
		"status":         status,
		"format":         req.Format,
		"requested_at":   requestedAt,
		"expires_at":     expiresAt,
		"artifact_id":    artifactID.String(),
		"retention_days": defaultExportRetentionDays,
	})
}

func (h *PrivacyHandler) GetExportStatus(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid user id")
		return
	}

	jobID := mux.Vars(r)["jobId"]
	jobUUID, err := uuid.Parse(jobID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid job id")
		return
	}

	var format string
	var status string
	var progress int
	var requestedAt time.Time
	var startedAt *time.Time
	var completedAt *time.Time
	var expiresAt *time.Time
	var errorMessage *string
	if err = h.db.QueryRow(r.Context(), `
		SELECT format, status, progress_percent, requested_at, started_at, completed_at, expires_at, error_message
		FROM public.data_export_jobs
		WHERE id = $1
		  AND user_id = $2
	`, jobUUID, userUUID).Scan(
		&format, &status, &progress, &requestedAt, &startedAt, &completedAt, &expiresAt, &errorMessage,
	); err != nil {
		writeError(w, http.StatusNotFound, "export job not found")
		return
	}

	rows, err := h.db.Query(r.Context(), `
		SELECT id, status, COALESCE(storage_path, ''), COALESCE(file_name, ''), COALESCE(content_type, ''),
		       file_size_bytes, COALESCE(checksum, ''), retention_until, created_at, updated_at
		FROM public.data_export_artifacts
		WHERE job_id = $1
		  AND user_id = $2
		ORDER BY created_at ASC
	`, jobUUID, userUUID)
	if err != nil {
		h.logger.Error("failed to list export artifacts", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to retrieve export job")
		return
	}
	defer rows.Close()

	artifacts := make([]exportArtifactResponse, 0)
	for rows.Next() {
		var item exportArtifactResponse
		if err = rows.Scan(
			&item.ID, &item.Status, &item.StoragePath, &item.FileName, &item.ContentType,
			&item.FileSizeBytes, &item.Checksum, &item.RetentionUntil, &item.CreatedAt, &item.UpdatedAt,
		); err != nil {
			h.logger.Error("failed to scan export artifact", zap.Error(err))
			writeError(w, http.StatusInternalServerError, "failed to retrieve export job")
			return
		}
		artifacts = append(artifacts, item)
	}
	if err = rows.Err(); err != nil {
		h.logger.Error("export artifact row iteration failed", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to retrieve export job")
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"job_id":        jobUUID.String(),
		"format":        format,
		"status":        status,
		"progress":      progress,
		"requested_at":  requestedAt,
		"started_at":    startedAt,
		"completed_at":  completedAt,
		"expires_at":    expiresAt,
		"error_message": errorMessage,
		"artifacts":     artifacts,
	})
}

func (h *PrivacyHandler) RequestAccountDeletion(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid user id")
		return
	}

	req := deleteAccountRequest{}
	if r.Body != nil {
		decErr := json.NewDecoder(r.Body).Decode(&req)
		if decErr != nil && decErr != io.EOF {
			writeError(w, http.StatusBadRequest, "invalid request body")
			return
		}
	}
	req.Reason = strings.TrimSpace(req.Reason)

	tx, err := h.db.Begin(r.Context())
	if err != nil {
		h.logger.Error("failed to begin deletion request transaction", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to create deletion job")
		return
	}
	defer tx.Rollback(r.Context()) //nolint:errcheck

	var existingJobID uuid.UUID
	var existingStatus string
	existingErr := tx.QueryRow(r.Context(), `
		SELECT id, status
		FROM public.account_deletion_jobs
		WHERE user_id = $1
		  AND status IN ('queued', 'processing')
		ORDER BY requested_at DESC
		LIMIT 1
		FOR UPDATE
	`, userUUID).Scan(&existingJobID, &existingStatus)
	if existingErr == nil {
		writeJSON(w, http.StatusConflict, map[string]interface{}{
			"error":  "active account deletion job already exists",
			"job_id": existingJobID.String(),
			"status": existingStatus,
		})
		return
	}
	if existingErr != nil && existingErr != pgx.ErrNoRows {
		h.logger.Error("failed to check existing deletion jobs", zap.Error(existingErr))
		writeError(w, http.StatusInternalServerError, "failed to create deletion job")
		return
	}

	var jobID uuid.UUID
	var status string
	var requestedAt time.Time
	var scheduledDeletionAt time.Time
	var retentionUntil time.Time
	if err = tx.QueryRow(r.Context(), `
		INSERT INTO public.account_deletion_jobs (
			user_id, status, reason, requested_at, scheduled_deletion_at, retention_until
		)
		VALUES ($1, 'queued', $2, NOW(), NOW() + INTERVAL '7 days', NOW() + INTERVAL '30 days')
		RETURNING id, status, requested_at, scheduled_deletion_at, retention_until
	`, userUUID, req.Reason).Scan(
		&jobID, &status, &requestedAt, &scheduledDeletionAt, &retentionUntil,
	); err != nil {
		h.logger.Error("failed to create account deletion job", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to create deletion job")
		return
	}

	if _, err = tx.Exec(r.Context(), `
		INSERT INTO public.deletion_audit_log (job_id, user_id, event_type, event_message, event_metadata)
		VALUES ($1, $2, 'requested', 'Account deletion requested', jsonb_build_object('reason', $3))
	`, jobID, userUUID, req.Reason); err != nil {
		h.logger.Error("failed to append deletion audit log", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to create deletion job")
		return
	}

	if err = tx.Commit(r.Context()); err != nil {
		h.logger.Error("failed to commit deletion request transaction", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to create deletion job")
		return
	}

	writeJSON(w, http.StatusAccepted, map[string]interface{}{
		"job_id":                jobID.String(),
		"status":                status,
		"requested_at":          requestedAt,
		"scheduled_deletion_at": scheduledDeletionAt,
		"retention_until":       retentionUntil,
		"grace_period_days":     defaultDeletionGraceDays,
		"audit_retention_days":  defaultDeletionRetentionDays,
	})
}

func (h *PrivacyHandler) GetAccountDeletionStatus(w http.ResponseWriter, r *http.Request) {
	userID := getUserID(r)
	if userID == "" {
		writeError(w, http.StatusUnauthorized, "unauthorized")
		return
	}
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid user id")
		return
	}

	jobID := mux.Vars(r)["jobId"]
	jobUUID, err := uuid.Parse(jobID)
	if err != nil {
		writeError(w, http.StatusBadRequest, "invalid job id")
		return
	}

	var status string
	var reason *string
	var requestedAt time.Time
	var scheduledDeletionAt time.Time
	var completedAt *time.Time
	var retentionUntil time.Time
	var errorMessage *string
	if err = h.db.QueryRow(r.Context(), `
		SELECT status, reason, requested_at, scheduled_deletion_at, completed_at, retention_until, error_message
		FROM public.account_deletion_jobs
		WHERE id = $1
		  AND user_id = $2
	`, jobUUID, userUUID).Scan(
		&status, &reason, &requestedAt, &scheduledDeletionAt, &completedAt, &retentionUntil, &errorMessage,
	); err != nil {
		writeError(w, http.StatusNotFound, "deletion job not found")
		return
	}

	rows, err := h.db.Query(r.Context(), `
		SELECT id, event_type, COALESCE(event_message, ''), event_metadata, created_at
		FROM public.deletion_audit_log
		WHERE job_id = $1
		  AND user_id = $2
		ORDER BY created_at DESC
		LIMIT 50
	`, jobUUID, userUUID)
	if err != nil {
		h.logger.Error("failed to list deletion audit entries", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to retrieve deletion job")
		return
	}
	defer rows.Close()

	auditEntries := make([]deletionAuditEntryResponse, 0)
	for rows.Next() {
		var entry deletionAuditEntryResponse
		var eventMetaRaw []byte
		if err = rows.Scan(&entry.ID, &entry.EventType, &entry.EventMessage, &eventMetaRaw, &entry.CreatedAt); err != nil {
			h.logger.Error("failed to scan deletion audit entry", zap.Error(err))
			writeError(w, http.StatusInternalServerError, "failed to retrieve deletion job")
			return
		}
		if len(eventMetaRaw) > 0 {
			entry.EventMeta = map[string]interface{}{}
			if unmarshalErr := json.Unmarshal(eventMetaRaw, &entry.EventMeta); unmarshalErr != nil {
				h.logger.Error("failed to decode deletion audit metadata", zap.Error(unmarshalErr))
				writeError(w, http.StatusInternalServerError, "failed to retrieve deletion job")
				return
			}
		}
		auditEntries = append(auditEntries, entry)
	}
	if err = rows.Err(); err != nil {
		h.logger.Error("deletion audit entry iteration failed", zap.Error(err))
		writeError(w, http.StatusInternalServerError, "failed to retrieve deletion job")
		return
	}

	writeJSON(w, http.StatusOK, map[string]interface{}{
		"job_id":                jobUUID.String(),
		"status":                status,
		"reason":                reason,
		"requested_at":          requestedAt,
		"scheduled_deletion_at": scheduledDeletionAt,
		"completed_at":          completedAt,
		"retention_until":       retentionUntil,
		"error_message":         errorMessage,
		"audit_log":             auditEntries,
	})
}
