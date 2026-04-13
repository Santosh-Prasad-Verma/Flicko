package services

import (
	"context"
	"fmt"

	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5/pgxpool"
)

type DMMessageService interface {
	SendMessage(ctx context.Context, conversationID, authorID string, content string, msgType models.DMMessageType, replyToID *string) (*models.DMMessage, error)
	MarkAsRead(ctx context.Context, conversationID, userID, messageID string) (*models.DMReadState, error)
	GetReadStates(ctx context.Context, userID string) ([]*models.DMReadState, error)
}

type dmMessageService struct {
	db *pgxpool.Pool
}

func NewDMMessageService(db *pgxpool.Pool) DMMessageService {
	return &dmMessageService{
		db: db,
	}
}

func (s *dmMessageService) isParticipant(ctx context.Context, conversationUUID, userUUID uuid.UUID) (bool, error) {
	var exists bool
	err := s.db.QueryRow(ctx, "SELECT EXISTS(SELECT 1 FROM public.group_dm_participants WHERE group_dm_id = $1 AND user_id = $2)", conversationUUID, userUUID).Scan(&exists)
	if err != nil {
		return false, err
	}
	return exists, nil
}

func (s *dmMessageService) hasBlocked(ctx context.Context, senderUUID, conversationUUID uuid.UUID) (bool, error) {
	// Let's get all participants
	rows, err := s.db.Query(ctx, "SELECT user_id FROM public.group_dm_participants WHERE group_dm_id = $1 AND user_id != $2", conversationUUID, senderUUID)
	if err != nil {
		return false, err
	}
	defer rows.Close()

	var recipientUUIDs []uuid.UUID
	for rows.Next() {
		var uid uuid.UUID
		if err := rows.Scan(&uid); err != nil {
			return false, err
		}
		recipientUUIDs = append(recipientUUIDs, uid)
	}

	if len(recipientUUIDs) == 0 {
		return false, nil // Self messaging or empty group
	}

	// Now check if ANY of these recipients has blocked the sender
	// public.blocks (blocker_id, blocked_id) means blocker_id blocked blocked_id
	// So we check if blocked_id = senderUUID and blocker_id = ANY(recipientUUIDs)

	query := `
		SELECT EXISTS(
			SELECT 1 FROM public.blocks 
			WHERE blocked_id = $1 AND blocker_id = ANY($2)
		)
	`
	var hasBlocked bool
	err = s.db.QueryRow(ctx, query, senderUUID, recipientUUIDs).Scan(&hasBlocked)
	if err != nil {
		return false, err
	}

	return hasBlocked, nil
}

func (s *dmMessageService) SendMessage(ctx context.Context, conversationID, authorID string, content string, msgType models.DMMessageType, replyToID *string) (*models.DMMessage, error) {
	authorUUID, err1 := uuid.Parse(authorID)
	convUUID, err2 := uuid.Parse(conversationID)

	if err1 != nil || err2 != nil {
		return nil, fmt.Errorf("invalid uuid format")
	}

	if len(content) == 0 || len(content) > 2000 {
		return nil, fmt.Errorf("message content must be between 1 and 2000 characters")
	}

	// 1. Validate participation
	isPart, err := s.isParticipant(ctx, convUUID, authorUUID)
	if err != nil {
		return nil, fmt.Errorf("failed to check participation: %w", err)
	}
	if !isPart {
		return nil, fmt.Errorf("user is not a participant in this conversation")
	}

	// 2. Validate Blocklist limitations
	blocked, err := s.hasBlocked(ctx, authorUUID, convUUID)
	if err != nil {
		return nil, fmt.Errorf("failed to check blocklist: %w", err)
	}
	if blocked {
		return nil, fmt.Errorf("cannot send to this conversation because a member has blocked you")
	}

	var replyUUID *uuid.UUID
	if replyToID != nil {
		r, err := uuid.Parse(*replyToID)
		if err == nil {
			replyUUID = &r
		}
	}

	msgID := uuid.New()
	queryMsg := `
		INSERT INTO public.dm_messages (id, conversation_id, author_id, content, type, reply_to_id)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING id, conversation_id, author_id, content, type, reply_to_id, edited_at, created_at, updated_at
	`

	var msg models.DMMessage
	err = s.db.QueryRow(ctx, queryMsg, msgID, convUUID, authorUUID, content, msgType, replyUUID).
		Scan(&msg.ID, &msg.ConversationID, &msg.AuthorID, &msg.Content, &msg.Type, &msg.ReplyToID, &msg.EditedAt, &msg.CreatedAt, &msg.UpdatedAt)

	if err != nil {
		return nil, fmt.Errorf("failed to insert dm message: %w", err)
	}

	// Would trigger notification / Supabase Realtime broadcast to participants here

	return &msg, nil
}

func (s *dmMessageService) MarkAsRead(ctx context.Context, conversationID, userID, messageID string) (*models.DMReadState, error) {
	convUUID, err1 := uuid.Parse(conversationID)
	userUUID, err2 := uuid.Parse(userID)
	msgUUID, err3 := uuid.Parse(messageID)

	if err1 != nil || err2 != nil || err3 != nil {
		return nil, fmt.Errorf("invalid uuid format")
	}

	isPart, err := s.isParticipant(ctx, convUUID, userUUID)
	if err != nil {
		return nil, fmt.Errorf("failed to verify participation: %w", err)
	}
	if !isPart {
		return nil, fmt.Errorf("user is not a participant")
	}

	query := `
		INSERT INTO public.dm_read_states (conversation_id, user_id, last_read_message_id, last_read_at)
		VALUES ($1, $2, $3, NOW())
		ON CONFLICT ON CONSTRAINT dm_read_states_pkey DO UPDATE SET
			last_read_message_id = EXCLUDED.last_read_message_id,
			last_read_at = NOW()
		RETURNING conversation_id, user_id, last_read_message_id, last_read_at
	`

	var rs models.DMReadState
	err = s.db.QueryRow(ctx, query, convUUID, userUUID, msgUUID).
		Scan(&rs.ConversationID, &rs.UserID, &rs.LastReadMessageID, &rs.LastReadAt)

	if err != nil {
		return nil, fmt.Errorf("failed to mark dm as read: %w", err)
	}

	return &rs, nil
}

func (s *dmMessageService) GetReadStates(ctx context.Context, userID string) ([]*models.DMReadState, error) {
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		return nil, fmt.Errorf("invalid uuid")
	}

	query := `
		SELECT conversation_id, user_id, last_read_message_id, last_read_at
		FROM public.dm_read_states
		WHERE user_id = $1
	`
	rows, err := s.db.Query(ctx, query, userUUID)
	if err != nil {
		return nil, fmt.Errorf("query failed: %w", err)
	}
	defer rows.Close()

	var states []*models.DMReadState
	for rows.Next() {
		rs := &models.DMReadState{}
		if err := rows.Scan(&rs.ConversationID, &rs.UserID, &rs.LastReadMessageID, &rs.LastReadAt); err != nil {
			return nil, fmt.Errorf("scan error: %w", err)
		}
		states = append(states, rs)
	}

	return states, nil
}
