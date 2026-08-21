package repository_test

// ============================================================
//  Integration test example using testcontainers-go.
//
//  These tests require Docker and are skipped in CI by default
//  unless the "integration" build tag is set:
//
//      go test -tags integration -v ./internal/repository/...
//
//  The tests spin up a real PostgreSQL 16 container, apply the
//  Flicko schema migrations, and run queries against it.
// ============================================================

// NOTE: This file is a TEMPLATE for integration tests.
// It demonstrates the testcontainers-go pattern but does NOT
// run automatically (requires build tag + Docker).
//
// To enable, rename to integration_test.go and add:
//   //go:build integration

/*

import (
	"context"
	"fmt"
	"os"
	"path/filepath"
	"sort"
	"testing"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"github.com/testcontainers/testcontainers-go"
	"github.com/testcontainers/testcontainers-go/wait"
	"go.uber.org/zap"

	"github.com/flicko-org/flicko/services/msg-service/internal/repository"
)

// testPool holds the connection pool for the integration test suite.
var testPool *pgxpool.Pool

// TestMain sets up the PostgreSQL container and applies migrations.
func TestMain(m *testing.M) {
	ctx := context.Background()

	// Start PostgreSQL container.
	req := testcontainers.ContainerRequest{
		Image:        "postgres:16-alpine",
		ExposedPorts: []string{"5432/tcp"},
		Env: map[string]string{
			"POSTGRES_DB":       "flicko_test",
			"POSTGRES_USER":     "flicko",
			"POSTGRES_PASSWORD": "flicko",
		},
		WaitingFor: wait.ForLog("database system is ready to accept connections").
			WithOccurrence(2).
			WithStartupTimeout(60 * time.Second),
	}

	pg, err := testcontainers.GenericContainer(ctx, testcontainers.GenericContainerRequest{
		ContainerRequest: req,
		Started:          true,
	})
	if err != nil {
		fmt.Fprintf(os.Stderr, "failed to start postgres container: %v\n", err)
		os.Exit(1)
	}
	defer pg.Terminate(ctx) //nolint:errcheck

	host, _ := pg.Host(ctx)
	port, _ := pg.MappedPort(ctx, "5432")
	dsn := fmt.Sprintf("postgres://flicko:flicko@%s:%s/flicko_test?sslmode=disable", host, port.Port())

	// Create pool.
	testPool, err = pgxpool.New(ctx, dsn)
	if err != nil {
		fmt.Fprintf(os.Stderr, "failed to create pool: %v\n", err)
		os.Exit(1)
	}
	defer testPool.Close()

	// Apply migrations.
	if err := applyMigrations(ctx, testPool); err != nil {
		fmt.Fprintf(os.Stderr, "failed to apply migrations: %v\n", err)
		os.Exit(1)
	}

	os.Exit(m.Run())
}

// applyMigrations reads SQL files from supabase/migrations/ and executes them in order.
func applyMigrations(ctx context.Context, pool *pgxpool.Pool) error {
	migrationsDir := filepath.Join("..", "..", "..", "..", "azure-migrations", "supabase-migrations", "migrations")
	entries, err := os.ReadDir(migrationsDir)
	if err != nil {
		return fmt.Errorf("read migrations dir: %w", err)
	}

	sort.Slice(entries, func(i, j int) bool {
		return entries[i].Name() < entries[j].Name()
	})

	for _, entry := range entries {
		if entry.IsDir() || filepath.Ext(entry.Name()) != ".sql" {
			continue
		}
		data, err := os.ReadFile(filepath.Join(migrationsDir, entry.Name()))
		if err != nil {
			return fmt.Errorf("read %s: %w", entry.Name(), err)
		}
		if _, err := pool.Exec(ctx, string(data)); err != nil {
			// Skip schema references if not present in local test container.
			fmt.Fprintf(os.Stderr, "WARN: migration %s failed (may be expected): %v\n", entry.Name(), err)
		}
	}
	return nil
}

// ---------- Example integration test ----------

func TestIntegration_MessageCreateAndGet(t *testing.T) {
	log := zap.NewNop()
	repo := repository.NewMessageRepository(testPool, log)
	ctx := context.Background()

	// Seed a server + channel first (FK constraints).
	_, _ = testPool.Exec(ctx, `
		INSERT INTO profiles (id, username, discriminator, email)
		VALUES ('11111111-1111-1111-1111-111111111111', 'testuser', '0001', 'test@flicko.dev')
		ON CONFLICT DO NOTHING`)
	_, _ = testPool.Exec(ctx, `
		INSERT INTO servers (id, name, owner_id)
		VALUES ('22222222-2222-2222-2222-222222222222', 'Test Server', '11111111-1111-1111-1111-111111111111')
		ON CONFLICT DO NOTHING`)
	_, _ = testPool.Exec(ctx, `
		INSERT INTO channels (id, server_id, name, type)
		VALUES ('33333333-3333-3333-3333-333333333333', '22222222-2222-2222-2222-222222222222', 'general', 'text')
		ON CONFLICT DO NOTHING`)

	msg := &repository.Message{
		ID:        "44444444-4444-4444-4444-444444444444",
		ChannelID: "33333333-3333-3333-3333-333333333333",
		AuthorID:  "11111111-1111-1111-1111-111111111111",
		Content:   "Integration test message",
		Type:      "default",
		CreatedAt: time.Now(),
	}

	if err := repo.Create(ctx, msg); err != nil {
		t.Fatalf("Create() error = %v", err)
	}

	got, err := repo.GetByID(ctx, msg.ChannelID, msg.ID)
	if err != nil {
		t.Fatalf("GetByID() error = %v", err)
	}
	if got.Content != "Integration test message" {
		t.Errorf("Content = %q", got.Content)
	}
}

*/
