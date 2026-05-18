// Package e2ee — optional org-tenant escrow.
//
// CRITICAL: escrow is OFF by default. Personal accounts MUST NEVER attach
// an escrow recipient. (R11.1, R17.5)
//
// References:
//   design.md §9 (Compliance & Legal Hold)
//   requirements.md R11
package e2ee

import (
	"context"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"
)

// EscrowPolicy describes how an org tenant has configured key escrow.
// Flicko infra never holds the escrow private key — it lives in the
// tenant's KMS/HSM, accessed only through the configured custodians.
type EscrowPolicy struct {
	OrgID      string   `json:"org_id"`
	PublicKey  []byte   `json:"public_key"` // X25519 pub of the escrow KMS key
	Custodians []string `json:"custodians"` // user ids approved to release
	Threshold  int      `json:"threshold"`  // k-of-n approvals required
	Enabled    bool     `json:"enabled"`
}

// EscrowStore is the contract for escrow configuration storage.
type EscrowStore interface {
	GetPolicy(ctx context.Context, orgID string) (EscrowPolicy, error)
	SetPolicy(ctx context.Context, p EscrowPolicy) error
	IsEscrowed(ctx context.Context, orgID string) (bool, error)
}

type escrowStore struct {
	db     *pgxpool.Pool
	logger *zap.Logger
}

func NewEscrowStore(db *pgxpool.Pool, logger *zap.Logger) EscrowStore {
	return &escrowStore{
		db:     db,
		logger: logger.Named("e2ee.escrow"),
	}
}

func (s *escrowStore) GetPolicy(ctx context.Context, orgID string) (EscrowPolicy, error) {
	var p EscrowPolicy
	err := s.db.QueryRow(ctx, `
		SELECT org_id, public_key, custodians, threshold, enabled
		FROM e2ee_escrow_keys
		WHERE org_id = $1
	`, orgID).Scan(&p.OrgID, &p.PublicKey, &p.Custodians, &p.Threshold, &p.Enabled)
	if err != nil {
		if err == pgx.ErrNoRows {
			return EscrowPolicy{}, err // Let caller handle not found
		}
		return EscrowPolicy{}, err
	}
	return p, nil
}

func (s *escrowStore) SetPolicy(ctx context.Context, p EscrowPolicy) error {
	_, err := s.db.Exec(ctx, `
		INSERT INTO e2ee_escrow_keys (org_id, public_key, custodians, threshold, enabled, updated_at)
		VALUES ($1, $2, $3, $4, $5, NOW())
		ON CONFLICT (org_id) DO UPDATE SET
			public_key = EXCLUDED.public_key,
			custodians = EXCLUDED.custodians,
			threshold = EXCLUDED.threshold,
			enabled = EXCLUDED.enabled,
			updated_at = NOW()
	`, p.OrgID, p.PublicKey, p.Custodians, p.Threshold, p.Enabled)
	return err
}

func (s *escrowStore) IsEscrowed(ctx context.Context, orgID string) (bool, error) {
	var enabled bool
	err := s.db.QueryRow(ctx, `
		SELECT enabled FROM e2ee_escrow_keys WHERE org_id = $1
	`, orgID).Scan(&enabled)
	if err != nil {
		if err == pgx.ErrNoRows {
			return false, nil // Not found means not escrowed
		}
		return false, err
	}
	return enabled, nil
}
