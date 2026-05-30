// Package e2ee — identity rotation attestation store.
//
// Each row is an Ed25519 signature, made by a user's OLD signing key,
// over the message
//
//	"rotate:<base64(old_identity_pub)>:<base64(new_identity_pub)>"
//
// Peers fetch the attestation alongside the new identity and verify
// it under the OLD signing key they already trust. A valid attestation
// means the rotation is authenticated; absence (or a bad signature) is
// not necessarily an attack — could be a legitimate device-loss reset —
// but the UI surfaces it as a louder warning.
package e2ee

import (
	"context"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"
)

// IdentityAttestation is the wire/store record.
type IdentityAttestation struct {
	UserID         string    `json:"user_id"`
	OldIdentityPub string    `json:"old_identity_pub"`
	NewIdentityPub string    `json:"new_identity_pub"`
	Signature      string    `json:"signature"`
	AttestedAt     time.Time `json:"attested_at"`
}

// ErrNoAttestation is returned by GetForNewKey when no row matches.
var ErrNoAttestation = errors.New("e2ee: no attestation for this identity")

type AttestationStore interface {
	Put(ctx context.Context, att IdentityAttestation) error
	GetForNewKey(ctx context.Context, userID, newIdentityPub string) (*IdentityAttestation, error)
}

type attestationStore struct {
	db     *pgxpool.Pool
	logger *zap.Logger
}

func NewAttestationStore(db *pgxpool.Pool, logger *zap.Logger) AttestationStore {
	return &attestationStore{
		db:     db,
		logger: logger.Named("e2ee.attestation"),
	}
}

func (s *attestationStore) Put(ctx context.Context, att IdentityAttestation) error {
	if err := validatePublicKey(att.OldIdentityPub, 32); err != nil {
		return err
	}
	if err := validatePublicKey(att.NewIdentityPub, 32); err != nil {
		return err
	}
	_, err := s.db.Exec(ctx, `
		INSERT INTO e2ee_identity_attestations (user_id, old_identity_pub, new_identity_pub, signature)
		VALUES ($1, $2, $3, $4)
	`, att.UserID, att.OldIdentityPub, att.NewIdentityPub, att.Signature)
	return err
}

// GetForNewKey returns the most recently published attestation whose
// `new_identity_pub` matches. The caller verifies the signature against
// the OLD signing key they already trusted — server-side verification
// would not add value because the server cannot prove possession of the
// old key either.
func (s *attestationStore) GetForNewKey(ctx context.Context, userID, newIdentityPub string) (*IdentityAttestation, error) {
	row := s.db.QueryRow(ctx, `
		SELECT user_id, old_identity_pub, new_identity_pub, signature, attested_at
		FROM e2ee_identity_attestations
		WHERE user_id = $1 AND new_identity_pub = $2
		ORDER BY attested_at DESC
		LIMIT 1
	`, userID, newIdentityPub)

	var att IdentityAttestation
	if err := row.Scan(&att.UserID, &att.OldIdentityPub, &att.NewIdentityPub,
		&att.Signature, &att.AttestedAt); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNoAttestation
		}
		return nil, err
	}
	return &att, nil
}
