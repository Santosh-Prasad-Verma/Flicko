# Integration Testing

> **Reading time:** ~6 minutes · **Audience:** Backend Developers · **Last Updated:** 2026-04-11

While Mock-heavy Unit Tests are fast, they possess a fatal flaw: they cannot verify if your SQL syntax is valid or if your database queries actually join correctly. 
Integration Tests in Flicko evaluate the real `backend/internal/database` repository layer against a live PostgreSQL instance.

---

## 1. TestContainers

To avoid developers needing to run separate local database scripts, Flicko uses **TestContainers** for Go.

When `go test -tags=integration` is executed:
1. The Go test suite programmatically reaches out to the host Docker daemon.
2. It pulls and spins up a brand new, empty `postgres:15-alpine` container.
3. It natively executes our `supabase/migrations/` SQL files against this ephemeral container to construct the schema precisely as it exists in production.
4. The test logic runs.
5. Upon test completion, Docker instantly destroys the ephemeral container, leaving no messy state behind.

---

## 2. Writing Integration Tests

Integration tests live in specific files tagged with the standard Go build constraint: `//go:build integration`.
This prevents CI from accidentally attempting to run them during the fast "Unit Test" step if Docker isn't available on the runner.

```go
//go:build integration
package database_test

import (
    "testing"
    "github.com/stretchr/testify/require"
    "flicko/backend/internal/database"
)

func TestMessageInsertAndFetch(t *testing.T) {
    // 1. db is pointing to the TestContainer instanced during TestMain setup
    repo := database.NewMessageRepository(testDB)
    
    // 2. Insert test data
    msgID := repo.InsertArbitraryMessage(ctx, "Hello Postgres!")
    
    // 3. Act
    fetched, err := repo.GetByID(ctx, msgID)
    
    // 4. Assert
    require.NoError(t, err)
    require.Equal(t, "Hello Postgres!", fetched.Content)
}
```

---

## 3. Real Constraints

Because the TestContainer evaluates real PostgreSQL code, these tests catch critical bugs that mocks miss:
- `user_id` foreign key violations.
- Unique constraints (e.g. adding the same React emoji twice).
- Triggers crashing.
- `JSONB` array structures failing to Unmarshal correctly into Go structs due to database drift.

We require at least one Integration Test for every distinct SQL query defined in the Repositories.
