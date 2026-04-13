package services

import (
	"context"
	"fmt"
	"time"

	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type MessageEditService interface {
	EditMessage(ctx context.Context, userID, messageID, newContent string) error
	GetEditHistory(ctx context.Context, messageID string) ([]MessageEditHistory, error)
}

type MessageEditHistory struct {
	ID              string    `json:"id" db:"id"`
	MessageID       string    `json:"message_id" db:"message_id"`
	PreviousContent string    `json:"previous_content" db:"previous_content"`
	EditedAt        time.Time `json:"edited_at" db:"edited_at"`
}

type messageEditService struct {
	db *pgxpool.Pool
}

func NewMessageEditService(db *pgxpool.Pool) MessageEditService {
	return &messageEditService{
		db: db,
	}
}

func (s *messageEditService) EditMessage(ctx context.Context, userID, messageID, newContent string) error {
	userUUID, err1 := uuid.Parse(userID)
	msgUUID, err2 := uuid.Parse(messageID)
	if err1 != nil || err2 != nil {
		return fmt.Errorf("invalid uuid format")
	}

	tx, err := s.db.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return fmt.Errorf("failed to begin transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	// Fetch current message to verify ownership and get previous content
	var authorID uuid.UUID
	var previousContent string
	err = tx.QueryRow(ctx, "SELECT author_id, content FROM public.messages WHERE id = $1 AND deleted_at IS NULL", msgUUID).
		Scan(&authorID, &previousContent)
	if err != nil {
		if err == pgx.ErrNoRows {
			return fmt.Errorf("message not found")
		}
		return fmt.Errorf("failed to fetch message: %w", err)
	}

	if authorID != userUUID {
		return fmt.Errorf("user is not the author of this message")
	}

	if previousContent == newContent {
		return fmt.Errorf("new content is identical to current content")
	}

	// Insert into edit history
	historyID := uuid.New()
	_, err = tx.Exec(ctx, "INSERT INTO public.message_edit_history (id, message_id, previous_content) VALUES ($1, $2, $3)",
		historyID, msgUUID, previousContent)
	if err != nil {
		return fmt.Errorf("failed to insert edit history: %w", err)
	}

	// Maintain limit of 10 edit history entries per message
	// Delete any oldest entries exceeding the 10 most recent
	cleanupQuery := `
		DELETE FROM public.message_edit_history 
		WHERE id IN (
			SELECT id FROM public.message_edit_history 
			WHERE message_id = $1 
			ORDER BY edited_at DESC 
			OFFSET 10
		)
	`
	_, err = tx.Exec(ctx, cleanupQuery, msgUUID)
	if err != nil {
		return fmt.Errorf("failed to prune old edit history: %w", err)
	}

	// Update original message
	_, err = tx.Exec(ctx, "UPDATE public.messages SET content = $1, edited_at = NOW() WHERE id = $2", newContent, msgUUID)
	if err != nil {
		return fmt.Errorf("failed to update message content: %w", err)
	}

	return tx.Commit(ctx)
}

func (s *messageEditService) GetEditHistory(ctx context.Context, messageID string) ([]MessageEditHistory, error) {
	msgUUID, err := uuid.Parse(messageID)
	if err != nil {
		return nil, fmt.Errorf("invalid message ID format")
	}

	rows, err := s.db.Query(ctx, "SELECT id, message_id, previous_content, edited_at FROM public.message_edit_history WHERE message_id = $1 ORDER BY edited_at DESC", msgUUID)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch edit history: %w", err)
	}
	defer rows.Close()

	var history []MessageEditHistory
	for rows.Next() {
		var h MessageEditHistory
		if err := rows.Scan(&h.ID, &h.MessageID, &h.PreviousContent, &h.EditedAt); err != nil {
			return nil, fmt.Errorf("failed to scan history row: %w", err)
		}
		history = append(history, h)
	}

	return history, nil
}
