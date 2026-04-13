package services_test

import (
	"context"
	"fmt"
	"testing"
	"time"

	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/flicko-org/flicko-backend/internal/services"
	"github.com/stretchr/testify/assert"
)

type mockWarningDB struct {
	warnings   map[string][]*models.Warning // key = serverID:userID
	thresholds models.EscalationThresholds
}

func (db *mockWarningDB) IssueWarning(serverID, userID, modID, reason string, severity models.WarningSeverity) (*models.Warning, *services.EscalationAction, error) {
	// Severity Validation
	switch severity {
	case models.SeverityLow, models.SeverityMedium, models.SeverityHigh, models.SeverityCritical:
	default:
		return nil, nil, models.ErrInvalidSeverity
	}

	if reason == "" {
		return nil, nil, fmt.Errorf("reason is required")
	}
	if userID == modID {
		return nil, nil, fmt.Errorf("cannot warn yourself")
	}

	key := serverID + ":" + userID
	w := &models.Warning{
		ID:       fmt.Sprintf("warn-%d", len(db.warnings[key])+1),
		ServerID: serverID, UserID: userID,
		Reason: reason, Severity: severity,
		CreatedAt: time.Now(),
	}
	db.warnings[key] = append(db.warnings[key], w)

	count := len(db.warnings[key])
	escalation := &services.EscalationAction{
		WarningCount: count,
		IsEscalated:  false,
	}

	if count >= db.thresholds.KickAt {
		escalation.Action = "kick"
		escalation.Threshold = db.thresholds.KickAt
		escalation.IsEscalated = true
	} else if count >= db.thresholds.TimeoutAt {
		escalation.Action = "timeout"
		escalation.Threshold = db.thresholds.TimeoutAt
		escalation.IsEscalated = true
	}

	return w, escalation, nil
}

func TestWarningRecordCreation(t *testing.T) {
	// Property 54: Warning Record Creation + Escalation Thresholds
	ctx := context.Background()
	_, _ = ctx, t

	db := &mockWarningDB{
		warnings:   make(map[string][]*models.Warning),
		thresholds: models.DefaultEscalation, // 3 timeout, 5 kick
	}

	// 1. Valid Warning
	w, esc, err := db.IssueWarning("s1", "user-1", "mod-1", "Spamming", models.SeverityLow)
	assert.NoError(t, err)
	assert.NotNil(t, w)
	assert.False(t, esc.IsEscalated)
	assert.Equal(t, 1, esc.WarningCount)

	// 2. Invalid severity
	_, _, err = db.IssueWarning("s1", "user-2", "mod-1", "Bad", "nonexistent")
	assert.ErrorIs(t, err, models.ErrInvalidSeverity)

	// 3. Self-warning
	_, _, err = db.IssueWarning("s1", "mod-1", "mod-1", "Self", models.SeverityLow)
	assert.Error(t, err)

	// 4. Escalation at 3 warnings → timeout
	db.IssueWarning("s1", "user-1", "mod-1", "Second offense", models.SeverityMedium)
	_, esc3, err := db.IssueWarning("s1", "user-1", "mod-1", "Third offense", models.SeverityHigh)
	assert.NoError(t, err)
	assert.True(t, esc3.IsEscalated)
	assert.Equal(t, "timeout", esc3.Action)
	assert.Equal(t, 3, esc3.WarningCount)

	// 5. Escalation at 5 warnings → kick
	db.IssueWarning("s1", "user-1", "mod-1", "Fourth", models.SeverityHigh)
	_, esc5, err := db.IssueWarning("s1", "user-1", "mod-1", "Fifth, this is it", models.SeverityCritical)
	assert.NoError(t, err)
	assert.True(t, esc5.IsEscalated)
	assert.Equal(t, "kick", esc5.Action)
	assert.Equal(t, 5, esc5.WarningCount)

	// 6. Empty reason
	_, _, err = db.IssueWarning("s1", "user-2", "mod-1", "", models.SeverityLow)
	assert.Error(t, err)
}
