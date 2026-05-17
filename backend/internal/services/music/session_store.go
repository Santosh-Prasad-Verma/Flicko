package music

import (
	"context"
	"errors"
	"fmt"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/redis/go-redis/v9"
	"go.uber.org/zap"
)

const (
	sessionTTL    = 24 * time.Hour
	sessionPrefix = "spotify:session:"
)

// SessionCookies holds the raw Spotify session cookies.
// We store ONLY cookies — never passwords.
type SessionCookies map[string]string

// SessionStore persists encrypted Spotify session cookies in Redis (hot) + PostgreSQL (durable).
type SessionStore struct {
	db     *pgxpool.Pool
	redis  redis.Cmdable
	enc    *EncryptionService
	logger *zap.Logger
}

// NewSessionStore creates a SessionStore.
func NewSessionStore(db *pgxpool.Pool, rdb redis.Cmdable, enc *EncryptionService, logger *zap.Logger) *SessionStore {
	return &SessionStore{
		db:     db,
		redis:  rdb,
		enc:    enc,
		logger: logger.Named("music.session_store"),
	}
}

// Save encrypts and stores session cookies for a user.
func (s *SessionStore) Save(ctx context.Context, userID string, cookies SessionCookies, displayName, product string) error {
	encrypted, err := s.enc.Encrypt(cookies)
	if err != nil {
		return fmt.Errorf("encrypt session: %w", err)
	}

	// Redis — hot cache
	key := sessionPrefix + userID
	if err := s.redis.Set(ctx, key, encrypted, sessionTTL).Err(); err != nil {
		s.logger.Warn("redis session write failed", zap.String("user_id", userID), zap.Error(err))
		// Non-fatal — fall through to PostgreSQL
	}

	// PostgreSQL — durable storage
	_, err = s.db.Exec(ctx, `
		INSERT INTO spotify_sessions (user_id, encrypted_session, display_name, product, status, expires_at)
		VALUES ($1, $2, $3, $4, 'active', NOW() + INTERVAL '24 hours')
		ON CONFLICT (user_id) DO UPDATE SET
			encrypted_session = EXCLUDED.encrypted_session,
			display_name      = EXCLUDED.display_name,
			product           = EXCLUDED.product,
			status            = 'active',
			updated_at        = NOW(),
			expires_at        = NOW() + INTERVAL '24 hours'
	`, userID, encrypted, displayName, product)
	if err != nil {
		return fmt.Errorf("persist session: %w", err)
	}

	return nil
}

// Load retrieves and decrypts session cookies for a user.
func (s *SessionStore) Load(ctx context.Context, userID string) (SessionCookies, error) {
	key := sessionPrefix + userID

	// Try Redis first
	raw, err := s.redis.Get(ctx, key).Bytes()
	if err == nil {
		var cookies SessionCookies
		if decErr := s.enc.Decrypt(raw, &cookies); decErr == nil {
			return cookies, nil
		}
	}

	// Fall back to PostgreSQL
	var encrypted []byte
	err = s.db.QueryRow(ctx, `
		SELECT encrypted_session FROM spotify_sessions
		WHERE user_id = $1 AND status = 'active' AND (expires_at IS NULL OR expires_at > NOW())
	`, userID).Scan(&encrypted)
	if err != nil {
		return nil, errors.New("session not found or expired")
	}

	var cookies SessionCookies
	if err := s.enc.Decrypt(encrypted, &cookies); err != nil {
		return nil, fmt.Errorf("decrypt session: %w", err)
	}

	// Re-warm Redis cache
	s.redis.Set(ctx, key, encrypted, sessionTTL)

	return cookies, nil
}

// MarkExpired marks a session as expired and removes it from Redis.
func (s *SessionStore) MarkExpired(ctx context.Context, userID string) {
	s.redis.Del(ctx, sessionPrefix+userID)
	s.db.Exec(ctx, `UPDATE spotify_sessions SET status = 'expired', updated_at = NOW() WHERE user_id = $1`, userID)
}

// Delete removes a session entirely (disconnect).
func (s *SessionStore) Delete(ctx context.Context, userID string) {
	s.redis.Del(ctx, sessionPrefix+userID)
	s.db.Exec(ctx, `UPDATE spotify_sessions SET status = 'revoked', updated_at = NOW() WHERE user_id = $1`, userID)
}

// GetInfo returns display metadata for a user's session (no cookies).
func (s *SessionStore) GetInfo(ctx context.Context, userID string) (displayName, product, status string, err error) {
	err = s.db.QueryRow(ctx, `
		SELECT COALESCE(display_name, ''), COALESCE(product, 'free'), status
		FROM spotify_sessions WHERE user_id = $1
	`, userID).Scan(&displayName, &product, &status)
	return
}
