// Package e2ee — sealed-sender envelope relay.
//
// References:
//   design.md §8 (Sealed Sender)
//   requirements.md R10
package e2ee

import (
	"context"
	"crypto/sha256"
	"errors"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"
)

// EnvelopeDedupWindow is how long a message hash stays in the dedup table.
// Matches SignedPrekeyValidity so stale envelopes cannot replay against a
// rotated signed prekey.
const EnvelopeDedupWindow = 7 * 24 * time.Hour

// ErrEnvelopeReplay is returned by Push when an identical envelope (same
// hash, same recipient device) was already seen inside the dedup window.
var ErrEnvelopeReplay = errors.New("e2ee: envelope replay rejected by dedup window")

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
	// Returns ErrEnvelopeReplay if the same (header, ciphertext) was already
	// pushed to this recipient device inside EnvelopeDedupWindow.
	Push(ctx context.Context, env Envelope) error

	// Pull returns up to `limit` envelopes for `(recipientUserID, recipientDeviceID)`
	// where `id > afterCursor`. Pulled envelopes are deleted server-side.
	Pull(ctx context.Context, recipientUserID, recipientDeviceID string, afterCursor int64, limit int) ([]Envelope, error)

	// GCDedup deletes dedup rows older than EnvelopeDedupWindow. Intended to
	// be called from a periodic job; returns the row count purged.
	GCDedup(ctx context.Context) (int64, error)
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

// envelopeHash returns sha256(header || ciphertext). Unique per ratchet
// message because the message key rotates per send; equal only on replay.
//
// Exported for tests — the dedup window's correctness rides entirely on
// this function being deterministic and on changing either field producing
// a different digest. A regression here would silently break replay
// rejection.
func EnvelopeHash(header, ciphertext []byte) []byte {
	h := sha256.New()
	h.Write(header)
	h.Write(ciphertext)
	sum := h.Sum(nil)
	return sum[:]
}

// envelopeHash is the unexported call-site name retained for backward
// compatibility within this package.
func envelopeHash(header, ciphertext []byte) []byte {
	return EnvelopeHash(header, ciphertext)
}

func (s *envelopeStore) Push(ctx context.Context, env Envelope) error {
	hash := envelopeHash(env.Header, env.Ciphertext)

	tx, err := s.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	// Reserve the dedup slot first. ON CONFLICT DO NOTHING + RowsAffected==0
	// signals a replay inside the window.
	tag, err := tx.Exec(ctx, `
		INSERT INTO e2ee_envelope_dedup (recipient_user_id, recipient_device_id, message_hash)
		VALUES ($1, $2, $3)
		ON CONFLICT (recipient_user_id, recipient_device_id, message_hash) DO NOTHING
	`, env.RecipientUserID, env.RecipientDeviceID, hash)
	if err != nil {
		return err
	}
	if tag.RowsAffected() == 0 {
		s.logger.Warn("envelope replay rejected",
			zap.String("recipient", env.RecipientUserID),
			zap.String("device", env.RecipientDeviceID),
		)
		return ErrEnvelopeReplay
	}

	var senderUserID *string
	if !env.IsSealed && env.SenderUserID != "" {
		senderUserID = &env.SenderUserID
	}

	if _, err := tx.Exec(ctx, `
		INSERT INTO e2ee_message_envelopes (
			sender_user_id, sender_device_id, recipient_user_id, recipient_device_id,
			is_sealed, header, ciphertext, delivery_token
		) VALUES ($1, $2, $3, $4, $5, $6, $7, $8)
	`, senderUserID, env.SenderDeviceID, env.RecipientUserID, env.RecipientDeviceID,
		env.IsSealed, env.Header, env.Ciphertext, env.DeliveryToken); err != nil {
		return err
	}

	return tx.Commit(ctx)
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

// GCDedup removes dedup entries older than EnvelopeDedupWindow.
func (s *envelopeStore) GCDedup(ctx context.Context) (int64, error) {
	tag, err := s.db.Exec(ctx, `
		DELETE FROM e2ee_envelope_dedup
		WHERE seen_at < NOW() - $1::interval
	`, EnvelopeDedupWindow.String())
	if err != nil {
		return 0, err
	}
	return tag.RowsAffected(), nil
}

// Compile-time assertion that pgx.ErrNoRows is wired (silences unused import
// when the file is later expanded). Keeps the import close to the code.
var _ = pgx.ErrNoRows
