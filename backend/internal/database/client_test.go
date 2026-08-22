package database

import (
	"context"
	"os"
	"testing"
	"time"

	"github.com/stretchr/testify/assert"
)

func TestCircuitBreaker_StateTransitions(t *testing.T) {
	cb := NewCircuitBreaker(3, 50*time.Millisecond)

	// Initially Closed
	assert.Equal(t, StateClosed, cb.State())
	assert.True(t, cb.AllowRequest())

	// 1 Failure -> Still Closed
	cb.RecordFailure()
	assert.Equal(t, StateClosed, cb.State())

	// 2 Failures -> Still Closed
	cb.RecordFailure()
	assert.Equal(t, StateClosed, cb.State())

	// 3 Failures -> Trips to Open
	cb.RecordFailure()
	assert.Equal(t, StateOpen, cb.State())

	// Open -> Reject request
	assert.False(t, cb.AllowRequest())

	// Wait for cooldown
	time.Sleep(60 * time.Millisecond)

	// Allow request shifts state to Half-Open
	assert.True(t, cb.AllowRequest())
	assert.Equal(t, StateHalfOpen, cb.State())

	// Half-Open failure -> Shifts back to Open immediately
	cb.RecordFailure()
	assert.Equal(t, StateOpen, cb.State())

	// Cooldown again
	time.Sleep(60 * time.Millisecond)
	assert.True(t, cb.AllowRequest())
	assert.Equal(t, StateHalfOpen, cb.State())

	// 1 Success -> Still Half-Open
	cb.RecordSuccess()
	assert.Equal(t, StateHalfOpen, cb.State())

	// 2 Successes -> Shifts back to Closed
	cb.RecordSuccess()
	assert.Equal(t, StateClosed, cb.State())
}

func TestPgxClient_FallbackReplica(t *testing.T) {
	// Set dummy replica URL but we won't connect (or connect to primary URL if we want it to work)
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		// Try using a standard fallback or skip if DB not configured locally
		dbURL = "postgres://postgres:postgres@localhost:5432/flicko?sslmode=disable"
	}

	// Set replica environment variable to the same database URL for testing
	os.Setenv("DATABASE_REPLICA_URL", dbURL)
	defer os.Unsetenv("DATABASE_REPLICA_URL")

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	client, err := NewDatabaseClient(ctx, dbURL)
	if err != nil {
		t.Skip("Skipping test: database connection not available")
		return
	}
	defer client.Close()

	assert.NotNil(t, client.ReplicaPool())

	// Query should route to replica
	rows, err := client.Query(ctx, "SELECT 1")
	if err == nil {
		rows.Close()
	}

	// Exec should route to primary
	_, _ = client.Exec(ctx, "SELECT 1")
}

func TestPgxClient_CircuitBreakerFailureFast(t *testing.T) {
	dbURL := os.Getenv("DATABASE_URL")
	if dbURL == "" {
		dbURL = "postgres://postgres:postgres@localhost:5432/flicko?sslmode=disable"
	}

	ctx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
	defer cancel()

	client, err := NewDatabaseClient(ctx, dbURL)
	if err != nil {
		t.Skip("Skipping test: database connection not available")
		return
	}
	defer client.Close()

	// Cause 5 consecutive failures
	for i := 0; i < 5; i++ {
		_, _ = client.Exec(ctx, "SELECT * FROM non_existent_table_abc_123")
	}

	assert.Equal(t, StateOpen, client.CBState())

	// Next call should fail fast with circuit breaker error
	_, err = client.Exec(ctx, "SELECT 1")
	assert.Error(t, err)
	assert.Contains(t, err.Error(), "circuit breaker is open")

	// QueryRow should return wrappedRow which fails fast on Scan
	row := client.QueryRow(ctx, "SELECT 1")
	var val int
	err = row.Scan(&val)
	assert.Error(t, err)
}

func TestIsReadOnlySQL_CommentsWithLockingClauses(t *testing.T) {
	tests := []struct {
		name     string
		sql      string
		expected bool
	}{
		{
			name:     "plain SELECT is read-only",
			sql:      "SELECT * FROM users",
			expected: true,
		},
		{
			name:     "SELECT with FOR UPDATE is not read-only",
			sql:      "SELECT * FROM users FOR UPDATE",
			expected: false,
		},
		{
			name:     "SELECT with block comment between FOR and UPDATE",
			sql:      "SELECT * FROM users FOR/* comment */UPDATE",
			expected: false,
		},
		{
			name:     "SELECT with block comment with spaces between FOR and UPDATE",
			sql:      "SELECT * FROM users FOR /* comment */ UPDATE",
			expected: false,
		},
		{
			name:     "SELECT with nested block comment obscuring locking clause",
			sql:      "SELECT * FROM users FOR/**/UPDATE",
			expected: false,
		},
		{
			name:     "SELECT with line comment between SELECT and FOR UPDATE",
			sql:      "SELECT * FROM users -- comment\nFOR UPDATE",
			expected: false,
		},
		{
			name:     "SELECT with line comment after FOR, UPDATE on next line",
			sql:      "SELECT * FROM users FOR-- comment\nUPDATE",
			expected: false,
		},
		{
			name:     "SELECT FOR SHARE with block comment",
			sql:      "SELECT * FROM users FOR/*test*/SHARE",
			expected: false,
		},
		{
			name:     "SELECT FOR KEY SHARE with line comment",
			sql:      "SELECT * FROM users FOR--\nKEY SHARE",
			expected: false,
		},
		{
			name:     "SELECT FOR NO KEY UPDATE with block comment",
			sql:      "SELECT * FROM users FOR /* x */ NO KEY UPDATE",
			expected: false,
		},
		{
			name:     "plain SELECT with harmless comment",
			sql:      "SELECT /* get all */ * FROM users",
			expected: true,
		},
		{
			name:     "plain SELECT with line comment",
			sql:      "SELECT * FROM users -- get all",
			expected: true,
		},
		{
			name:     "multiple block comments in safe SELECT",
			sql:      "SELECT /* a */ * /* b */ FROM /* c */ users",
			expected: true,
		},
	}

	for _, tt := range tests {
		t.Run(tt.name, func(t *testing.T) {
			result := isReadOnlySQL(tt.sql)
			assert.Equal(t, tt.expected, result, "SQL: %s", tt.sql)
		})
	}
}
