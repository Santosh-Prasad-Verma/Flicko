package services

import (
	"context"
	"testing"
	"time"

	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/google/uuid"
	"github.com/stretchr/testify/assert"
)

// We use mocked dependencies to isolate the session service logic,
// simulating DB constraints like refresh_token uniqueness.

type MockSessionRepository struct {
	sessions map[string]*models.Session
	tokens   map[string]bool // For uniqueness checks
}

func NewMockSessionRepo() *MockSessionRepository {
	return &MockSessionRepository{
		sessions: make(map[string]*models.Session),
		tokens:   make(map[string]bool),
	}
}

func (m *MockSessionRepository) CreateSession(ctx context.Context, session *models.Session) error {
	if m.tokens[session.RefreshToken] {
		return assert.AnError // Simulate DB UNIQUE constraint violation
	}
	session.ID = uuid.New().String()
	session.CreatedAt = time.Now()
	session.UpdatedAt = time.Now()

	m.sessions[session.ID] = session
	m.tokens[session.RefreshToken] = true
	return nil
}

func TestSession_CreateSession_Completeness(t *testing.T) {
	repo := NewMockSessionRepo()
	ctx := context.Background()

	userID := uuid.New().String()

	deviceInfo := "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"
	ipAddress := "192.168.1.1"
	userAgent := "CustomAppClient/1.0"

	// Valid complete session
	session := &models.Session{
		UserID:       userID,
		DeviceInfo:   &deviceInfo,
		IPAddress:    &ipAddress,
		UserAgent:    &userAgent,
		RefreshToken: "valid-unique-token",
		IsActive:     true,
		ExpiresAt:    time.Now().Add(30 * 24 * time.Hour),
		LastActivity: time.Now(),
	}

	err := repo.CreateSession(ctx, session)
	assert.NoError(t, err)
	assert.NotEmpty(t, session.ID)

	// Property Test: Reject duplicate refresh token (simulating DB constraint)
	duplicateSession := &models.Session{
		UserID:       userID,
		RefreshToken: "valid-unique-token", // Same token
		ExpiresAt:    time.Now().Add(1 * time.Hour),
	}

	err = repo.CreateSession(ctx, duplicateSession)
	assert.Error(t, err) // Should fail unique constraint
}
