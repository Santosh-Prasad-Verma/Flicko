package services

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"fmt"
	"time"

	"github.com/flicko-org/flicko-backend/internal/cache"
	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type SessionService interface {
	CreateSession(ctx context.Context, req models.SessionCreateRequest) (*models.Session, error)
	GetActiveSessions(ctx context.Context, userID string) ([]*models.Session, error)
	TerminateSession(ctx context.Context, userID, sessionID string) error
	RefreshSession(ctx context.Context, refreshToken string) (*models.Session, error)
	UpdateActivity(ctx context.Context, sessionID string) error
}

type sessionService struct {
	db    *pgxpool.Pool
	redis cache.CacheLayer
}

func NewSessionService(db *pgxpool.Pool, redis cache.CacheLayer) SessionService {
	return &sessionService{
		db:    db,
		redis: redis,
	}
}

// GenerateRefreshToken creates a secure 256-bit base64 random string
func generateRefreshToken() (string, error) {
	b := make([]byte, 32)
	if _, err := rand.Read(b); err != nil {
		return "", err
	}
	return base64.URLEncoding.EncodeToString(b), nil
}

func (s *sessionService) CreateSession(ctx context.Context, req models.SessionCreateRequest) (*models.Session, error) {
	userUUID, err := uuid.Parse(req.UserID)
	if err != nil {
		return nil, fmt.Errorf("invalid user id")
	}

	refreshToken, err := generateRefreshToken()
	if err != nil {
		return nil, fmt.Errorf("failed to generate token: %w", err)
	}

	sessionID := uuid.New()
	expiresAt := time.Now().Add(30 * 24 * time.Hour) // 30 days

	query := `
		INSERT INTO public.sessions (id, user_id, device_info, ip_address, user_agent, refresh_token, expires_at)
		VALUES ($1, $2, $3, $4, $5, $6, $7)
		RETURNING id, user_id, device_info, ip_address, user_agent, is_active, last_activity, expires_at, created_at, updated_at
	`

	var sess models.Session
	err = s.db.QueryRow(ctx, query, sessionID, userUUID, req.DeviceInfo, req.IPAddress, req.UserAgent, refreshToken, expiresAt).
		Scan(
			&sess.ID,
			&sess.UserID,
			&sess.DeviceInfo,
			&sess.IPAddress,
			&sess.UserAgent,
			&sess.IsActive,
			&sess.LastActivity,
			&sess.ExpiresAt,
			&sess.CreatedAt,
			&sess.UpdatedAt,
		)

	if err != nil {
		return nil, fmt.Errorf("failed to create session: %w", err)
	}

	// Add refresh token into the response object so caller can send it to client (e.g. via HttpOnly cookie)
	sess.RefreshToken = refreshToken

	return &sess, nil
}

func (s *sessionService) GetActiveSessions(ctx context.Context, userID string) ([]*models.Session, error) {
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		return nil, fmt.Errorf("invalid user id format")
	}

	query := `
		SELECT id, user_id, device_info, ip_address, user_agent, is_active, last_activity, expires_at, created_at, updated_at
		FROM public.sessions
		WHERE user_id = $1 AND is_active = true AND expires_at > NOW()
		ORDER BY last_activity DESC
	`

	rows, err := s.db.Query(ctx, query, userUUID)
	if err != nil {
		return nil, fmt.Errorf("query failed: %w", err)
	}
	defer rows.Close()

	var sessions []*models.Session
	for rows.Next() {
		sess := &models.Session{}
		if err := rows.Scan(
			&sess.ID,
			&sess.UserID,
			&sess.DeviceInfo,
			&sess.IPAddress,
			&sess.UserAgent,
			&sess.IsActive,
			&sess.LastActivity,
			&sess.ExpiresAt,
			&sess.CreatedAt,
			&sess.UpdatedAt,
		); err != nil {
			return nil, fmt.Errorf("scan failed: %w", err)
		}
		sessions = append(sessions, sess)
	}

	return sessions, nil
}

func (s *sessionService) TerminateSession(ctx context.Context, userID, sessionID string) error {
	userUUID, err1 := uuid.Parse(userID)
	sessUUID, err2 := uuid.Parse(sessionID)
	if err1 != nil || err2 != nil {
		return fmt.Errorf("invalid uuid format")
	}

	// Terminate by setting is_active = false
	// We need to fetch it first to get the refresh token so we can blacklist it in redis
	var refreshToken string
	err := s.db.QueryRow(ctx, "UPDATE public.sessions SET is_active = false, updated_at = NOW() WHERE id = $1 AND user_id = $2 AND is_active = true RETURNING refresh_token", sessUUID, userUUID).Scan(&refreshToken)
	if err != nil {
		if err == pgx.ErrNoRows {
			return fmt.Errorf("session not found or already inactive")
		}
		return fmt.Errorf("failed to terminate session: %w", err)
	}

	// Blacklist the refresh token
	blacklistKey := fmt.Sprintf("blacklist:rt:%s", refreshToken)
	// We keep it in blacklist for 30 days max (until it would naturally expire)
	_ = s.redis.Set(ctx, blacklistKey, "true", 30*24*time.Hour)

	return nil
}

func (s *sessionService) RefreshSession(ctx context.Context, refreshToken string) (*models.Session, error) {
	// First, check blacklist
	blacklistKey := fmt.Sprintf("blacklist:rt:%s", refreshToken)
	blacklisted, _ := s.redis.Exists(ctx, blacklistKey)
	if blacklisted {
		return nil, fmt.Errorf("refresh token is revoked")
	}

	// Verify and rotation
	// We do token rotation: invalidate old one, create new one.
	tx, err := s.db.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return nil, fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	var sess models.Session
	query := `
		SELECT id, user_id, device_info, ip_address, user_agent, is_active, expires_at
		FROM public.sessions
		WHERE refresh_token = $1 AND is_active = true AND expires_at > NOW()
		FOR UPDATE
	`
	err = tx.QueryRow(ctx, query, refreshToken).Scan(
		&sess.ID,
		&sess.UserID,
		&sess.DeviceInfo,
		&sess.IPAddress,
		&sess.UserAgent,
		&sess.IsActive,
		&sess.ExpiresAt,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, fmt.Errorf("invalid or expired refresh token")
		}
		return nil, fmt.Errorf("failed to fetch session: %w", err)
	}

	// Create new token
	newRefreshToken, err := generateRefreshToken()
	if err != nil {
		return nil, fmt.Errorf("failed to generate new token: %w", err)
	}

	newExpiresAt := time.Now().Add(30 * 24 * time.Hour)

	// Invalidate the old session implicitly by creating a new one and terminating old,
	// OR we can just update the existing row with the new token and reset expiration.
	// Standard practice varies. Resetting the token on the same row preserves session history (device info etc).
	// We'll update inline for simpler tracking.

	updateQuery := `
		UPDATE public.sessions
		SET refresh_token = $1, expires_at = $2, last_activity = NOW(), updated_at = NOW()
		WHERE id = $3
		RETURNING last_activity, created_at, updated_at
	`
	err = tx.QueryRow(ctx, updateQuery, newRefreshToken, newExpiresAt, sess.ID).Scan(
		&sess.LastActivity,
		&sess.CreatedAt,
		&sess.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("failed to rotate refresh token: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("transaction commit failed: %w", err)
	}

	// Blacklist the old one
	_ = s.redis.Set(ctx, blacklistKey, "true", time.Until(sess.ExpiresAt))

	sess.RefreshToken = newRefreshToken
	sess.ExpiresAt = newExpiresAt

	return &sess, nil
}

func (s *sessionService) UpdateActivity(ctx context.Context, sessionID string) error {
	sessUUID, err := uuid.Parse(sessionID)
	if err != nil {
		return fmt.Errorf("invalid session id")
	}

	_, err = s.db.Exec(ctx, "UPDATE public.sessions SET last_activity = NOW() WHERE id = $1 AND is_active = true", sessUUID)
	return err
}
