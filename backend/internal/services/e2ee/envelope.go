// Package e2ee — sealed-sender envelope relay.
//
// References:
//   design.md §8 (Sealed Sender)
//   requirements.md R10
package e2ee

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"
)

// Envelope is the on-wire encrypted payload the server relays without
// being able to decrypt. Either `SenderUserID` or `IsSealed` is set.
type Envelope struct {
	ID                int64     `json:"id"`
	SenderUserID      string    `json:"sender_user_id,omitempty"` // empty for sealed-sender
	SenderDeviceID    string    `json:"sender_device_id,omitempty"`
	RecipientUserID   string    `json:"recipient_user_id"`
	RecipientDeviceID string    `json:"recipient_device_id"`
	IsSealed          bool      `json:"is_sealed"`
	Header            []byte    `json:"header"`     // DR header (DHr, PN, Ns)
	Ciphertext        []byte    `json:"ciphertext"` // includes AEAD tag
	DeliveryToken     []byte    `json:"delivery_token,omitempty"`
	CreatedAt         time.Time `json:"created_at"`
}

// EnvelopeStore is the contract the relay handler uses.
type EnvelopeStore interface {
	// Push uploads a new envelope to the recipient device's inbox.
	Push(ctx context.Context, env Envelope) error

	// Pull returns up to `limit` envelopes for `(recipientUserID, recipientDeviceID)`
	// where `id > afterCursor`. Pulled envelopes are deleted server-side.
	Pull(ctx context.Context, recipientUserID, recipientDeviceID string, afterCursor int64, limit int) ([]Envelope, error)
}

type envelopeStore struct {
	db     *pgxpool.Pool
	logger *zap.Logger
}

func NewEnvelopeStore(db *pgxpool.Pool, logger *zap.Logger) EnvelopeStore {
	return &envelopeStore{
		db:     db,
		logger: logger.Named("e2ee.envelope"),
	}
}

func (s *envelopeStore) Push(ctx context.Context, env Envelope) error {
	var senderUserID *string
	if !env.IsSealed && env.SenderUserID != "" {
		senderUserID = &env.SenderUserID
	}

	_, err := s.db.Exec(ctx, `
		INSERT INTO e2ee_message_envelopes (
			sender_user_id, sender_device_id, recipient_user_id, recipient_device_id,
			is_sealed, header, ciphertext, delivery_token
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
	`, senderUserID, env.SenderDeviceID, env.RecipientUserID, env.RecipientDeviceID,
		env.IsSealed, env.Header, env.Ciphertext, env.DeliveryToken)
	return err
}

func (s *envelopeStore) Pull(ctx context.Context, recipientUserID, recipientDeviceID string, afterCursor int64, limit int) ([]Envelope, error) {
	// We need to return the envelopes and then delete them.
	// We can use a CTE to do this in a single query.
	rows, err := s.db.Query(ctx, `
		WITH pulled AS (
			SELECT id
			FROM e2ee_message_envelopes
			WHERE recipient_user_id = $1 AND recipient_device_id = $2 AND id > $3
			ORDER BY id ASC
			LIMIT $4
			FOR UPDATE SKIP LOCKED
		)
		DELETE FROM e2ee_message_envelopes e
		USING pulled p
		WHERE e.id = p.id
		RETURNING e.id, e.sender_user_id, e.sender_device_id, e.recipient_user_id, e.recipient_device_id,
		          e.is_sealed, e.header, e.ciphertext, e.delivery_token, e.created_at
	`, recipientUserID, recipientDeviceID, afterCursor, limit)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var envs []Envelope
	for rows.Next() {
		var env Envelope
		var senderUserID *string
		if err := rows.Scan(
			&env.ID, &senderUserID, &env.SenderDeviceID, &env.RecipientUserID, &env.RecipientDeviceID,
			&env.IsSealed, &env.Header, &env.Ciphertext, &env.DeliveryToken, &env.CreatedAt,
		); err != nil {
			return nil, err
		}
		if senderUserID != nil {
			env.SenderUserID = *senderUserID
		}
		envs = append(envs, env)
	}
	return envs, rows.Err()
}
