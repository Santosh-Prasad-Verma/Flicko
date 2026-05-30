// Package e2ee implements the public-key directory and prekey pool for
// end-to-end encrypted direct messages.
//
// Server responsibilities (server NEVER sees plaintext or private keys):
//   1. Store and serve users' public identity keys
//   2. Store and serve signed prekeys (rotated periodically)
//   3. Maintain a pool of one-time prekeys per device, consumed on first read
//   4. Track per-conversation E2EE state (enabled / disabled)
//
// Cryptography responsibilities live entirely on the clients.
package e2ee

import (
	"context"
	"encoding/base64"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"
)

const (
	// MaxOneTimePrekeysPerUpload caps a single batch upload to prevent abuse.
	MaxOneTimePrekeysPerUpload = 100
	// MinOneTimePrekeysFloor is the threshold under which the server warns the
	// client to top up its prekey pool.
	MinOneTimePrekeysFloor = 5
	// SignedPrekeyValidity is how long a signed prekey is considered fresh.
	SignedPrekeyValidity = 7 * 24 * time.Hour
)

// IdentityKey represents a user's long-lived device identity.
type IdentityKey struct {
	UserID      string     `json:"user_id"`
	DeviceID    string     `json:"device_id"`
	IdentityPub string     `json:"identity_pub"` // base64 X25519
	SigningPub  string     `json:"signing_pub"`  // base64 Ed25519
	Fingerprint string     `json:"fingerprint"`
	CreatedAt   time.Time  `json:"created_at"`
	RotatedAt   *time.Time `json:"rotated_at,omitempty"`
}

// SignedPrekey is a medium-lived X25519 key signed by the identity signing key.
type SignedPrekey struct {
	KeyID      int       `json:"key_id"`
	PublicKey  string    `json:"public_key"`
	Signature  string    `json:"signature"`
	CreatedAt  time.Time `json:"created_at"`
	ExpiresAt  *time.Time `json:"expires_at,omitempty"`
}

// OneTimePrekey is a single-use X25519 prekey.
type OneTimePrekey struct {
	KeyID     int    `json:"key_id"`
	PublicKey string `json:"public_key"`
}

// PrekeyBundle is what a sender fetches before encrypting the first message.
type PrekeyBundle struct {
	UserID       string         `json:"user_id"`
	DeviceID     string         `json:"device_id"`
	Identity     IdentityKey    `json:"identity"`
	SignedPrekey SignedPrekey   `json:"signed_prekey"`
	OneTimePrekey *OneTimePrekey `json:"one_time_prekey,omitempty"` // optional
}

// ConversationState tracks whether E2EE has been enabled for a 1:1 DM thread.
type ConversationState struct {
	UserA     string     `json:"user_a"`
	UserB     string     `json:"user_b"`
	Enabled   bool       `json:"enabled"`
	EnabledAt *time.Time `json:"enabled_at,omitempty"`
}

// Errors returned by the keystore.
var (
	ErrIdentityNotFound  = errors.New("e2ee: identity key not found")
	ErrNoSignedPrekey    = errors.New("e2ee: no signed prekey available")
	ErrInvalidPublicKey  = errors.New("e2ee: invalid public key")
	ErrTooManyPrekeys    = errors.New("e2ee: too many prekeys in single upload")
)

// KeyStore is the persistence layer for E2EE public material.
//
// Time complexity for the hot path (FetchBundle):
//   O(1) primary-key lookups for identity + signed prekey + one-time prekey
type KeyStore struct {
	db     *pgxpool.Pool
	logger *zap.Logger
}

// NewKeyStore wires the keystore to its dependencies.
func NewKeyStore(db *pgxpool.Pool, logger *zap.Logger) *KeyStore {
	return &KeyStore{db: db, logger: logger.Named("e2ee.keystore")}
}

// validatePublicKey ensures a base64-encoded key matches expectedLen bytes.
// Cheap defence against malformed uploads. Time: O(1).
func validatePublicKey(b64 string, expectedLen int) error {
	if b64 == "" {
		return ErrInvalidPublicKey
	}
	raw, err := base64.StdEncoding.DecodeString(b64)
	if err != nil {
		return fmt.Errorf("%w: %v", ErrInvalidPublicKey, err)
	}
	if len(raw) != expectedLen {
		return fmt.Errorf("%w: expected %d bytes, got %d", ErrInvalidPublicKey, expectedLen, len(raw))
	}
	return nil
}

// ── Identity ────────────────────────────────────────────────────────────────

// UpsertIdentity registers or rotates the identity bundle for (userID, deviceID).
// Rotating the identity key invalidates all previous signed/one-time prekeys for
// the device — clients should re-upload after rotation.
func (s *KeyStore) UpsertIdentity(ctx context.Context, key IdentityKey) error {
	if err := validatePublicKey(key.IdentityPub, 32); err != nil {
		return err
	}
	if err := validatePublicKey(key.SigningPub, 32); err != nil {
		return err
	}

	_, err := s.db.Exec(ctx, `
		INSERT INTO e2ee_identity_keys (user_id, device_id, identity_pub, signing_pub, fingerprint)
		VALUES ($1, $2, $3, $4, $5)
		ON CONFLICT (user_id, device_id) DO UPDATE SET
			identity_pub = EXCLUDED.identity_pub,
			signing_pub  = EXCLUDED.signing_pub,
			fingerprint  = EXCLUDED.fingerprint,
			rotated_at   = NOW()
	`, key.UserID, key.DeviceID, key.IdentityPub, key.SigningPub, key.Fingerprint)
	return err
}

// GetIdentity returns the most recently uploaded device identity for a user.
// If a user has multiple devices, the caller can specify deviceID="" to get any.
func (s *KeyStore) GetIdentity(ctx context.Context, userID, deviceID string) (*IdentityKey, error) {
	var (
		out IdentityKey
		row pgx.Row
	)
	if deviceID == "" {
		row = s.db.QueryRow(ctx, `
			SELECT user_id, device_id, identity_pub, signing_pub, fingerprint, created_at, rotated_at
			FROM e2ee_identity_keys
			WHERE user_id = $1
			ORDER BY COALESCE(rotated_at, created_at) DESC
			LIMIT 1
		`, userID)
	} else {
		row = s.db.QueryRow(ctx, `
			SELECT user_id, device_id, identity_pub, signing_pub, fingerprint, created_at, rotated_at
			FROM e2ee_identity_keys
			WHERE user_id = $1 AND device_id = $2
		`, userID, deviceID)
	}
	if err := row.Scan(&out.UserID, &out.DeviceID, &out.IdentityPub, &out.SigningPub,
		&out.Fingerprint, &out.CreatedAt, &out.RotatedAt); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrIdentityNotFound
		}
		return nil, err
	}
	return &out, nil
}

// ListIdentities returns ALL device identities for a user, ordered by
// most-recently-rotated first. Used by senders to fan-out a message to
// every device the recipient owns.
//
// Returns an empty slice (not error) when the user has no devices.
// Time: O(devices) — typically 1-3 rows.
func (s *KeyStore) ListIdentities(ctx context.Context, userID string) ([]IdentityKey, error) {
	rows, err := s.db.Query(ctx, `
		SELECT user_id, device_id, identity_pub, signing_pub, fingerprint, created_at, rotated_at
		FROM e2ee_identity_keys
		WHERE user_id = $1
		ORDER BY COALESCE(rotated_at, created_at) DESC
	`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var out []IdentityKey
	for rows.Next() {
		var k IdentityKey
		if err := rows.Scan(&k.UserID, &k.DeviceID, &k.IdentityPub, &k.SigningPub,
			&k.Fingerprint, &k.CreatedAt, &k.RotatedAt); err != nil {
			return nil, err
		}
		out = append(out, k)
	}
	return out, rows.Err()
}

// ── Signed Prekey ───────────────────────────────────────────────────────────

// UpsertSignedPrekey replaces the active signed prekey for the device.
func (s *KeyStore) UpsertSignedPrekey(ctx context.Context, userID, deviceID string, p SignedPrekey) error {
	if err := validatePublicKey(p.PublicKey, 32); err != nil {
		return err
	}
	if _, err := base64.StdEncoding.DecodeString(p.Signature); err != nil {
		return fmt.Errorf("%w: bad signature: %v", ErrInvalidPublicKey, err)
	}
	expires := time.Now().Add(SignedPrekeyValidity)
	_, err := s.db.Exec(ctx, `
		INSERT INTO e2ee_signed_prekeys (user_id, device_id, key_id, public_key, signature, expires_at)
		VALUES ($1, $2, $3, $4, $5, $6)
		ON CONFLICT (user_id, device_id, key_id) DO UPDATE SET
			public_key = EXCLUDED.public_key,
			signature  = EXCLUDED.signature,
			expires_at = EXCLUDED.expires_at,
			created_at = NOW()
	`, userID, deviceID, p.KeyID, p.PublicKey, p.Signature, expires)
	return err
}

// ── One-Time Prekeys ────────────────────────────────────────────────────────

// PutOneTimePrekeys uploads a batch of one-time prekeys for the device.
// Consumes a single transaction. O(n) on batch size.
func (s *KeyStore) PutOneTimePrekeys(ctx context.Context, userID, deviceID string, keys []OneTimePrekey) error {
	if len(keys) == 0 {
		return nil
	}
	if len(keys) > MaxOneTimePrekeysPerUpload {
		return ErrTooManyPrekeys
	}
	for _, k := range keys {
		if err := validatePublicKey(k.PublicKey, 32); err != nil {
			return err
		}
	}

	tx, err := s.db.Begin(ctx)
	if err != nil {
		return err
	}
	defer func() { _ = tx.Rollback(ctx) }()

	batch := &pgx.Batch{}
	for _, k := range keys {
		batch.Queue(`
			INSERT INTO e2ee_one_time_prekeys (user_id, device_id, key_id, public_key)
			VALUES ($1, $2, $3, $4)
			ON CONFLICT (user_id, device_id, key_id) DO NOTHING
		`, userID, deviceID, k.KeyID, k.PublicKey)
	}
	br := tx.SendBatch(ctx, batch)
	for range keys {
		if _, err := br.Exec(); err != nil {
			_ = br.Close()
			return err
		}
	}
	if err := br.Close(); err != nil {
		return err
	}
	return tx.Commit(ctx)
}

// CountOneTimePrekeys returns how many unused OTKs the device has remaining.
// Used by clients to decide when to top up.
func (s *KeyStore) CountOneTimePrekeys(ctx context.Context, userID, deviceID string) (int, error) {
	var n int
	err := s.db.QueryRow(ctx, `
		SELECT COUNT(*) FROM e2ee_one_time_prekeys
		WHERE user_id = $1 AND device_id = $2
	`, userID, deviceID).Scan(&n)
	return n, err
}

// ── Bundle Fetch (atomic OTK consumption) ───────────────────────────────────

// FetchBundle returns everything a sender needs to encrypt to (recipientID, deviceID).
// If a one-time prekey is available it is atomically consumed (deleted).
//
// Atomic OTK consumption uses a CTE with DELETE...RETURNING so two concurrent
// senders cannot grab the same OTK. Time: O(1).
func (s *KeyStore) FetchBundle(ctx context.Context, recipientID, deviceID string) (*PrekeyBundle, error) {
	identity, err := s.GetIdentity(ctx, recipientID, deviceID)
	if err != nil {
		return nil, err
	}

	// Resolve effective device id (when caller passes "")
	if deviceID == "" {
		deviceID = identity.DeviceID
	}

	bundle := &PrekeyBundle{
		UserID:   recipientID,
		DeviceID: deviceID,
		Identity: *identity,
	}

	// Fetch latest signed prekey
	if err := s.db.QueryRow(ctx, `
		SELECT key_id, public_key, signature, created_at, expires_at
		FROM e2ee_signed_prekeys
		WHERE user_id = $1 AND device_id = $2
		  AND (expires_at IS NULL OR expires_at > NOW())
		ORDER BY created_at DESC
		LIMIT 1
	`, recipientID, deviceID).Scan(
		&bundle.SignedPrekey.KeyID,
		&bundle.SignedPrekey.PublicKey,
		&bundle.SignedPrekey.Signature,
		&bundle.SignedPrekey.CreatedAt,
		&bundle.SignedPrekey.ExpiresAt,
	); err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, ErrNoSignedPrekey
		}
		return nil, err
	}

	// Atomically consume one OTK (best-effort — bundle is still usable without it)
	var otk OneTimePrekey
	err = s.db.QueryRow(ctx, `
		WITH picked AS (
			SELECT id, key_id, public_key
			FROM e2ee_one_time_prekeys
			WHERE user_id = $1 AND device_id = $2
			ORDER BY id ASC
			LIMIT 1
			FOR UPDATE SKIP LOCKED
		)
		DELETE FROM e2ee_one_time_prekeys o
		USING picked p
		WHERE o.id = p.id
		RETURNING p.key_id, p.public_key
	`, recipientID, deviceID).Scan(&otk.KeyID, &otk.PublicKey)
	if err == nil {
		bundle.OneTimePrekey = &otk
	} else if !errors.Is(err, pgx.ErrNoRows) {
		s.logger.Warn("otk fetch failed", zap.Error(err))
	}

	return bundle, nil
}

// ── Conversation state ──────────────────────────────────────────────────────

// canonical orders (a, b) so we always store a < b.
func canonical(a, b string) (string, string) {
	if a < b {
		return a, b
	}
	return b, a
}

// EnableConversation marks 1:1 E2EE as on for the (a, b) pair. One-way switch.
func (s *KeyStore) EnableConversation(ctx context.Context, a, b string) error {
	ua, ub := canonical(a, b)
	_, err := s.db.Exec(ctx, `
		INSERT INTO e2ee_conversation_state (user_a, user_b, enabled, enabled_at)
		VALUES ($1, $2, TRUE, NOW())
		ON CONFLICT (user_a, user_b) DO UPDATE SET
			enabled    = TRUE,
			enabled_at = COALESCE(e2ee_conversation_state.enabled_at, NOW())
	`, ua, ub)
	return err
}

// IsConversationEnabled returns whether E2EE is enforced for the given pair.
func (s *KeyStore) IsConversationEnabled(ctx context.Context, a, b string) (bool, error) {
	ua, ub := canonical(a, b)
	var enabled bool
	err := s.db.QueryRow(ctx, `
		SELECT COALESCE(enabled, FALSE) FROM e2ee_conversation_state
		WHERE user_a = $1 AND user_b = $2
	`, ua, ub).Scan(&enabled)
	if errors.Is(err, pgx.ErrNoRows) {
		return false, nil
	}
	return enabled, err
}
