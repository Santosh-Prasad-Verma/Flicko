// Package e2ee — multi-device handoff coordinator.
//
// References:
//   design.md §5.3 (New device onboarding)
//   requirements.md R7.4, R7.5
package e2ee

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"
)

// HandoffRequest is created by a new device that wants to receive history
// from one of the user's existing devices.
type HandoffRequest struct {
	ID                 string    `json:"id"`
	UserID             string    `json:"user_id"`
	NewDeviceID        string    `json:"new_device_id"`
	NewDeviceIdentity  []byte    `json:"new_device_identity"` // X25519 pub
	SasFingerprint     string    `json:"sas_fingerprint"`     // 6-word phrase
	Status             string    `json:"status"`              // pending|approved|rejected|expired
	CreatedAt          time.Time `json:"created_at"`
	ExpiresAt          time.Time `json:"expires_at"`
}

// HandoffStore is the contract for handoff coordination.
type HandoffStore interface {
	CreateRequest(ctx context.Context, req HandoffRequest) error
	GetRequest(ctx context.Context, id string) (HandoffRequest, error)
	Approve(ctx context.Context, id, approvingDeviceID string) error
	Reject(ctx context.Context, id string) error
	ListPending(ctx context.Context, userID string) ([]HandoffRequest, error)
}

type handoffStore struct {
	db     *pgxpool.Pool
	logger *zap.Logger
}

func NewHandoffStore(db *pgxpool.Pool, logger *zap.Logger) HandoffStore {
	return &handoffStore{
		db:     db,
		logger: logger.Named("e2ee.handoff"),
	}
}

func (s *handoffStore) CreateRequest(ctx context.Context, req HandoffRequest) error {
	_, err := s.db.Exec(ctx, `
		INSERT INTO e2ee_handoff_requests (user_id, new_device_id, new_device_identity, sas_fingerprint, status)
		VALUES ($1, $2, $3, $4, 'pending')
	`, req.UserID, req.NewDeviceID, req.NewDeviceIdentity, req.SasFingerprint)
	return err
}

func (s *handoffStore) GetRequest(ctx context.Context, id string) (HandoffRequest, error) {
	var r HandoffRequest
	err := s.db.QueryRow(ctx, `
		SELECT id, user_id, new_device_id, new_device_identity, sas_fingerprint, status, created_at, expires_at
		FROM e2ee_handoff_requests
		WHERE id = $1
	`, id).Scan(
		&r.ID, &r.UserID, &r.NewDeviceID, &r.NewDeviceIdentity, &r.SasFingerprint,
		&r.Status, &r.CreatedAt, &r.ExpiresAt,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			return HandoffRequest{}, err // let caller handle
		}
		return HandoffRequest{}, err
	}
	return r, nil
}

func (s *handoffStore) Approve(ctx context.Context, id, approvingDeviceID string) error {
	_, err := s.db.Exec(ctx, `
		UPDATE e2ee_handoff_requests
		SET status = 'approved'
		WHERE id = $1 AND status = 'pending'
	`, id)
	return err
}

func (s *handoffStore) Reject(ctx context.Context, id string) error {
	_, err := s.db.Exec(ctx, `
		UPDATE e2ee_handoff_requests
		SET status = 'rejected'
		WHERE id = $1 AND status = 'pending'
	`, id)
	return err
}

func (s *handoffStore) ListPending(ctx context.Context, userID string) ([]HandoffRequest, error) {
	rows, err := s.db.Query(ctx, `
		SELECT id, user_id, new_device_id, new_device_identity, sas_fingerprint, status, created_at, expires_at
		FROM e2ee_handoff_requests
		WHERE user_id = $1 AND status = 'pending' AND expires_at > NOW()
	`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var reqs []HandoffRequest
	for rows.Next() {
		var r HandoffRequest
		if err := rows.Scan(
			&r.ID, &r.UserID, &r.NewDeviceID, &r.NewDeviceIdentity, &r.SasFingerprint,
			&r.Status, &r.CreatedAt, &r.ExpiresAt,
		); err != nil {
			return nil, err
		}
		reqs = append(reqs, r)
	}
	return reqs, rows.Err()
}
