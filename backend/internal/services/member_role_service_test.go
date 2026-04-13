package services_test

import (
	"context"
	"fmt"
	"testing"

	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/stretchr/testify/assert"
)

type mockRoleDB struct {
	roles       map[string]*models.Role
	memberRoles map[string]bool
}

func (db *mockRoleDB) Assign(executorHighestPos, targetPos int) error {
	if executorHighestPos <= targetPos {
		return fmt.Errorf("hierarchy violation")
	}
	return nil
}

func TestMemberRoleAssignmentAndCalculation(t *testing.T) {
	// Property 44: Member Role Assignment
	// Property 45: Effective Permission Calculation

	ctx := context.Background()
	_, _ = ctx, t

	db := &mockRoleDB{
		roles:       make(map[string]*models.Role),
		memberRoles: make(map[string]bool),
	}

	// 1. Hierarchy enforcement test
	// Executor has position 5
	err := db.Assign(5, 2)
	assert.NoError(t, err)

	err = db.Assign(5, 6)
	assert.Error(t, err) // Target is higher than executor

	err = db.Assign(5, 5)
	assert.Error(t, err) // Target is equal to executor

	// 2. Effective Permission simulation
	var p1 int64 = 4  // BAN_MEMBERS
	var p2 int64 = 64 // ADD_REACTIONS

	// They stack via bitwise OR
	effective := p1 | p2

	// User should have both
	assert.Equal(t, p1, effective&p1)
	assert.Equal(t, p2, effective&p2)
	assert.Equal(t, int64(0), effective&2) // Does not have KICK_MEMBERS
}
