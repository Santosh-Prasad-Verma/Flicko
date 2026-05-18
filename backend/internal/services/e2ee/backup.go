// Package e2ee — encrypted backup chunks.
//
// References:
//   design.md §6 (Encrypted Backup & Recovery)
//   requirements.md R8
package e2ee

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"
)

// BackupChunk is an opaque encrypted chunk of a user's conversation history.
// The server stores chunks as bytes only; it cannot derive the master key.
type BackupChunk struct {
	UserID     string    `json:"user_id"`
	Salt       []byte    `json:"salt"`        // Argon2id salt for the master key
	ChunkIndex int       `json:"chunk_index"` // monotonic per backup
	ChunkHash  []byte    `json:"chunk_hash"`  // SHA-256 of ciphertext (dedup key)
	Ciphertext []byte    `json:"ciphertext"`
	CreatedAt  time.Time `json:"created_at"`
}

// BackupStore is the contract for chunk persistence.
type BackupStore interface {
	Put(ctx context.Context, chunk BackupChunk) error
	Manifest(ctx context.Context, userID string) ([]BackupChunk, error) // chunks without ciphertext
	Fetch(ctx context.Context, userID string, chunkIndex int) (BackupChunk, error)
	DeleteAll(ctx context.Context, userID string) error
}

type backupStore struct {
	db     *pgxpool.Pool
	logger *zap.Logger
}

func NewBackupStore(db *pgxpool.Pool, logger *zap.Logger) BackupStore {
	return &backupStore{
		db:     db,
		logger: logger.Named("e2ee.backup"),
	}
}

func (s *backupStore) Put(ctx context.Context, chunk BackupChunk) error {
	_, err := s.db.Exec(ctx, `
		INSERT INTO e2ee_backups (user_id, salt, chunk_index, chunk_hash, ciphertext)
		VALUES ($1, $2, $3, $4, $5)
		ON CONFLICT (user_id, chunk_hash) DO NOTHING
	`, chunk.UserID, chunk.Salt, chunk.ChunkIndex, chunk.ChunkHash, chunk.Ciphertext)
	return err
}

func (s *backupStore) Manifest(ctx context.Context, userID string) ([]BackupChunk, error) {
	rows, err := s.db.Query(ctx, `
		SELECT user_id, salt, chunk_index, chunk_hash, created_at
		FROM e2ee_backups
		WHERE user_id = $1
		ORDER BY chunk_index ASC
	`, userID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var chunks []BackupChunk
	for rows.Next() {
		var c BackupChunk
		if err := rows.Scan(&c.UserID, &c.Salt, &c.ChunkIndex, &c.ChunkHash, &c.CreatedAt); err != nil {
			return nil, err
		}
		chunks = append(chunks, c)
	}
	return chunks, rows.Err()
}

func (s *backupStore) Fetch(ctx context.Context, userID string, chunkIndex int) (BackupChunk, error) {
	var c BackupChunk
	err := s.db.QueryRow(ctx, `
		SELECT user_id, salt, chunk_index, chunk_hash, ciphertext, created_at
		FROM e2ee_backups
		WHERE user_id = $1 AND chunk_index = $2
	`, userID, chunkIndex).Scan(
		&c.UserID, &c.Salt, &c.ChunkIndex, &c.ChunkHash, &c.Ciphertext, &c.CreatedAt,
	)
	if err != nil {
		if err == pgx.ErrNoRows {
			return BackupChunk{}, err // Let caller handle not found
		}
		return BackupChunk{}, err
	}
	return c, nil
}

func (s *backupStore) DeleteAll(ctx context.Context, userID string) error {
	_, err := s.db.Exec(ctx, `
		DELETE FROM e2ee_backups WHERE user_id = $1
	`, userID)
	return err
}
