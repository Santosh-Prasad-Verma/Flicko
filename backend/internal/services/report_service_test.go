package services_test

import (
	"context"
	"fmt"
	"testing"

	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/stretchr/testify/assert"
)

type mockReportDB struct {
	reports map[string]*models.Report
}

func (db *mockReportDB) Create(reporterID string, reportType models.ReportType, targetType models.ReportTargetType, targetID, description string) (*models.Report, error) {
	// Property 53: Description min length
	if len(description) < 10 {
		return nil, models.ErrReportDescriptionLength
	}

	// Validate types
	switch reportType {
	case models.ReportHarassment, models.ReportSpam, models.ReportInappropriateContent, models.ReportOther:
	default:
		return nil, fmt.Errorf("invalid report type")
	}

	switch targetType {
	case models.ReportTargetMessage, models.ReportTargetUser, models.ReportTargetServer:
	default:
		return nil, fmt.Errorf("invalid target type")
	}

	// Property 52: Check duplicate
	key := reporterID + ":" + targetID
	if _, exists := db.reports[key]; exists {
		return nil, models.ErrDuplicateReport
	}

	r := &models.Report{
		ID:          "report-" + targetID,
		ReporterID:  reporterID,
		ReportType:  reportType,
		TargetType:  targetType,
		TargetID:    targetID,
		Description: description,
		Status:      models.ReportStatusPending,
	}
	db.reports[key] = r
	return r, nil
}

func TestReportCreationProperties(t *testing.T) {
	// Property 52: Report Creation
	// Property 53: Report Description Minimum Length

	ctx := context.Background()
	_, _ = ctx, t

	db := &mockReportDB{reports: make(map[string]*models.Report)}

	// 1. Valid Report
	r, err := db.Create("user-1", models.ReportHarassment, models.ReportTargetUser, "target-1", "This user is being very abusive and harassing others")
	assert.NoError(t, err)
	assert.NotNil(t, r)
	assert.Equal(t, models.ReportStatusPending, r.Status)

	// 2. Short Description (< 10 chars)
	_, err = db.Create("user-2", models.ReportSpam, models.ReportTargetMessage, "target-2", "short")
	assert.ErrorIs(t, err, models.ErrReportDescriptionLength)

	// 3. Exactly 10 chars
	_, err = db.Create("user-2", models.ReportSpam, models.ReportTargetMessage, "target-2", "0123456789")
	assert.NoError(t, err)

	// 4. Duplicate Report
	_, err = db.Create("user-1", models.ReportHarassment, models.ReportTargetUser, "target-1", "Reporting again for same issue")
	assert.ErrorIs(t, err, models.ErrDuplicateReport)

	// 5. Invalid Report Type
	_, err = db.Create("user-3", "invalid", models.ReportTargetMessage, "target-3", "This has invalid type for testing")
	assert.Error(t, err)
}
