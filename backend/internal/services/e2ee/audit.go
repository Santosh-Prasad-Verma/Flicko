// Package e2ee — verification audit log.
//
// References:
//   design.md §7.4 (Identity verification)
//   requirements.md R9.6, R12.1
package e2ee

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"
)

// VerificationMethod enumerates the user-driven verification mechanisms.
type VerificationMethod string

const (
	VerificationSafetyNumber       VerificationMethod = "safety_number"
	VerificationQR                 VerificationMethod = "qr"
	VerificationSAS                VerificationMethod = "sas"
	VerificationIdentityChangeAck  VerificationMethod = "identity_change_ack"
)

// VerificationEvent is an append-only audit record of an identity check.
type VerificationEvent struct {
	ID          int64              `json:"id"`
	UserID      string             `json:"user_id"`
	PeerUserID  string             `json:"peer_user_id"`
	Method      VerificationMethod `json:"method"`
	Fingerprint string             `json:"fingerprint"` // hex-encoded SHA-256 of peer's IK pub
	OccurredAt  time.Time          `json:"occurred_at"`
}

// AuditStore is the contract for the verification audit log.
type AuditStore interface {
	Append(ctx context.Context, event VerificationEvent) error
	List(ctx context.Context, userID string, limit int) ([]VerificationEvent, error)
}

type auditStore struct {
	db     *pgxpool.Pool
	logger *zap.Logger
}

func NewAuditStore(db *pgxpool.Pool, logger *zap.Logger) AuditStore {
	return &auditStore{
		db:     db,
		logger: logger.Named("e2ee.audit"),
	}
}

func (s *auditStore) Append(ctx context.Context, event VerificationEvent) error {
	_, err := s.db.Exec(ctx, `
		INSERT INTO e2ee_verification_events (user_id, peer_user_id, method, fingerprint)
		VALUES ($1, $2, $3, $4)
	`, event.UserID, event.PeerUserID, event.Method, event.Fingerprint)
	return err
}

func (s *auditStore) List(ctx context.Context, userID string, limit int) ([]VerificationEvent, error) {
	rows, err := s.db.Query(ctx, `
		SELECT id, user_id, peer_user_id, method, fingerprint, occurred_at
		FROM e2ee_verification_events
		WHERE user_id = $1
		ORDER BY occurred_at DESC
		LIMIT $2
	`, userID, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var events []VerificationEvent
	for rows.Next() {
		var e VerificationEvent
		if err := rows.Scan(&e.ID, &e.UserID, &e.PeerUserID, &e.Method, &e.Fingerprint, &e.OccurredAt); err != nil {
			return nil, err
		}
		events = append(events, e)
	}
	return events, rows.Err()
}
