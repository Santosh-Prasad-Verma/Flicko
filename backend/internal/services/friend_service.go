package services

import (
	"context"
	"fmt"
	"strings"

	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

// FriendService is NOT wired into the HTTP router (cmd/server/main.go): the
// friends/friend-request domain is served by Supabase (PostgREST + RLS,
// enforced by migration 099_user_privacy_dm_fr_enforcement) and the mobile
// client hits it directly. Retained as a reference / ready-made backend-owned
// path. NewFriendService has no callers today — verified unused, not
// accidentally orphaned. Do not delete without confirming the Supabase-direct
// path still owns this domain.
type FriendService interface {
	SendFriendRequest(ctx context.Context, senderID, receiverID string, message *string) (*models.FriendRequest, error)
	GetPendingRequests(ctx context.Context, userID string) ([]*models.FriendRequest, error)
	AcceptFriendRequest(ctx context.Context, userID, requestID string) error
	DeclineFriendRequest(ctx context.Context, userID, requestID string) error

	GetFriends(ctx context.Context, userID string) ([]*models.Friendship, error)
	SetFriendNickname(ctx context.Context, userID, friendID string, nickname *string) error
	RemoveFriend(ctx context.Context, userID, friendID string) error

	BlockUser(ctx context.Context, blockerID, blockedID string) error
	UnblockUser(ctx context.Context, blockerID, blockedID string) error
	GetBlockedUsers(ctx context.Context, userID string) ([]*models.Block, error)
}

type friendService struct {
	db *pgxpool.Pool
}

func NewFriendService(db *pgxpool.Pool) FriendService {
	return &friendService{
		db: db,
	}
}

// ... helper methods ...

func (s *friendService) checkAlreadyFriends(ctx context.Context, user1, user2 uuid.UUID) (bool, error) {
	query := `
		SELECT EXISTS(
			SELECT 1 FROM public.friendships 
			WHERE (user_id = $1 AND friend_id = $2) OR (user_id = $2 AND friend_id = $1)
		)
	`
	var exists bool
	err := s.db.QueryRow(ctx, query, user1, user2).Scan(&exists)
	if err != nil {
		return false, err
	}
	return exists, nil
}

func (s *friendService) checkPendingRequest(ctx context.Context, user1, user2 uuid.UUID) (bool, error) {
	query := `
		SELECT EXISTS(
			SELECT 1 FROM public.friend_requests 
			WHERE status = 'pending' AND 
			((sender_id = $1 AND receiver_id = $2) OR (sender_id = $2 AND receiver_id = $1))
		)
	`
	var exists bool
	err := s.db.QueryRow(ctx, query, user1, user2).Scan(&exists)
	if err != nil {
		return false, err
	}
	return exists, nil
}

// ... existing methods ...

func (s *friendService) SendFriendRequest(ctx context.Context, senderID, receiverID string, message *string) (*models.FriendRequest, error) {
	senderUUID, err1 := uuid.Parse(senderID)
	receiverUUID, err2 := uuid.Parse(receiverID)

	if err1 != nil || err2 != nil {
		return nil, fmt.Errorf("invalid uuid")
	}
	if senderUUID == receiverUUID {
		return nil, fmt.Errorf("cannot send a friend request to yourself")
	}

	friends, err := s.checkAlreadyFriends(ctx, senderUUID, receiverUUID)
	if err != nil {
		return nil, fmt.Errorf("failed to check friendship: %w", err)
	}
	if friends {
		return nil, fmt.Errorf("already friends")
	}

	pending, err := s.checkPendingRequest(ctx, senderUUID, receiverUUID)
	if err != nil {
		return nil, err
	}
	if pending {
		return nil, fmt.Errorf("a pending request already exists")
	}

	reqID := uuid.New()
	query := `
		INSERT INTO public.friend_requests (id, sender_id, receiver_id, message, status)
		VALUES ($1, $2, $3, $4, 'pending')
		RETURNING id, sender_id, receiver_id, message, status, created_at, responded_at
	`
	var req models.FriendRequest
	err = s.db.QueryRow(ctx, query, reqID, senderUUID, receiverUUID, message).
		Scan(&req.ID, &req.SenderID, &req.ReceiverID, &req.Message, &req.Status, &req.CreatedAt, &req.RespondedAt)
	if err != nil {
		return nil, err
	}
	return &req, nil
}

func (s *friendService) GetPendingRequests(ctx context.Context, userID string) ([]*models.FriendRequest, error) {
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		return nil, fmt.Errorf("invalid uuid")
	}

	query := `
		SELECT id, sender_id, receiver_id, message, status, created_at, responded_at
		FROM public.friend_requests
		WHERE (sender_id = $1 OR receiver_id = $1) AND status = 'pending'
		ORDER BY created_at DESC
	`
	rows, err := s.db.Query(ctx, query, userUUID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var requests []*models.FriendRequest
	for rows.Next() {
		req := &models.FriendRequest{}
		if err := rows.Scan(&req.ID, &req.SenderID, &req.ReceiverID, &req.Message, &req.Status, &req.CreatedAt, &req.RespondedAt); err != nil {
			return nil, err
		}
		requests = append(requests, req)
	}
	return requests, nil
}

// ... new methods ...

func (s *friendService) AcceptFriendRequest(ctx context.Context, userID, requestID string) error {
	userUUID, err1 := uuid.Parse(userID)
	reqUUID, err2 := uuid.Parse(requestID)
	if err1 != nil || err2 != nil {
		return fmt.Errorf("invalid uuid")
	}

	tx, err := s.db.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	var senderUUID uuid.UUID
	err = tx.QueryRow(ctx, "SELECT sender_id FROM public.friend_requests WHERE id = $1 AND receiver_id = $2 AND status = 'pending'", reqUUID, userUUID).Scan(&senderUUID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return fmt.Errorf("pending request not found or unauthorized")
		}
		return err
	}

	_, err = tx.Exec(ctx, "UPDATE public.friend_requests SET status = 'accepted', responded_at = NOW() WHERE id = $1", reqUUID)
	if err != nil {
		return err
	}

	// Bidirectional friendships
	_, err = tx.Exec(ctx, "INSERT INTO public.friendships (user_id, friend_id) VALUES ($1, $2) ON CONFLICT DO NOTHING", userUUID, senderUUID)
	if err != nil {
		return err
	}
	_, err = tx.Exec(ctx, "INSERT INTO public.friendships (user_id, friend_id) VALUES ($1, $2) ON CONFLICT DO NOTHING", senderUUID, userUUID)
	if err != nil {
		return err
	}

	return tx.Commit(ctx)
}

func (s *friendService) DeclineFriendRequest(ctx context.Context, userID, requestID string) error {
	userUUID, err1 := uuid.Parse(userID)
	reqUUID, err2 := uuid.Parse(requestID)
	if err1 != nil || err2 != nil {
		return fmt.Errorf("invalid uuid")
	}

	res, err := s.db.Exec(ctx, "UPDATE public.friend_requests SET status = 'declined', responded_at = NOW() WHERE id = $1 AND receiver_id = $2 AND status = 'pending'", reqUUID, userUUID)
	if err != nil {
		return err
	}
	if res.RowsAffected() == 0 {
		return fmt.Errorf("pending request not found")
	}
	return nil
}

func (s *friendService) GetFriends(ctx context.Context, userID string) ([]*models.Friendship, error) {
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		return nil, fmt.Errorf("invalid uuid")
	}

	query := `
		SELECT user_id, friend_id, nickname, created_at
		FROM public.friendships
		WHERE user_id = $1
		ORDER BY created_at DESC
	`
	rows, err := s.db.Query(ctx, query, userUUID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var friends []*models.Friendship
	for rows.Next() {
		f := &models.Friendship{}
		if err := rows.Scan(&f.UserID, &f.FriendID, &f.Nickname, &f.CreatedAt); err != nil {
			return nil, err
		}
		friends = append(friends, f)
	}
	return friends, nil
}

func (s *friendService) SetFriendNickname(ctx context.Context, userID, friendID string, nickname *string) error {
	userUUID, err1 := uuid.Parse(userID)
	friendUUID, err2 := uuid.Parse(friendID)
	if err1 != nil || err2 != nil {
		return fmt.Errorf("invalid uuid")
	}

	if nickname != nil {
		trimmed := strings.TrimSpace(*nickname)
		if trimmed == "" {
			nickname = nil
		} else {
			nickname = &trimmed
		}
	}

	res, err := s.db.Exec(ctx, "UPDATE public.friendships SET nickname = $1 WHERE user_id = $2 AND friend_id = $3", nickname, userUUID, friendUUID)
	if err != nil {
		return err
	}
	if res.RowsAffected() == 0 {
		return fmt.Errorf("friendship not found")
	}
	return nil
}

func (s *friendService) RemoveFriend(ctx context.Context, userID, friendID string) error {
	userUUID, err1 := uuid.Parse(userID)
	friendUUID, err2 := uuid.Parse(friendID)
	if err1 != nil || err2 != nil {
		return fmt.Errorf("invalid uuid")
	}

	tx, err := s.db.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	res, err := tx.Exec(ctx, "DELETE FROM public.friendships WHERE (user_id = $1 AND friend_id = $2) OR (user_id = $2 AND friend_id = $1)", userUUID, friendUUID)
	if err != nil {
		return err
	}
	if res.RowsAffected() == 0 {
		return fmt.Errorf("friendship not found")
	}
	return tx.Commit(ctx)
}

func (s *friendService) BlockUser(ctx context.Context, blockerID, blockedID string) error {
	blockerUUID, err1 := uuid.Parse(blockerID)
	blockedUUID, err2 := uuid.Parse(blockedID)
	if err1 != nil || err2 != nil {
		return fmt.Errorf("invalid uuid")
	}

	if blockerUUID == blockedUUID {
		return fmt.Errorf("cannot block yourself")
	}

	tx, err := s.db.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	_, err = tx.Exec(ctx, "INSERT INTO public.blocks (blocker_id, blocked_id) VALUES ($1, $2)", blockerUUID, blockedUUID)
	if err != nil {
		return fmt.Errorf("failed to block user: %w", err)
	}

	// Cascade delete friendships
	_, _ = tx.Exec(ctx, "DELETE FROM public.friendships WHERE (user_id = $1 AND friend_id = $2) OR (user_id = $2 AND friend_id = $1)", blockerUUID, blockedUUID)

	return tx.Commit(ctx)
}

func (s *friendService) UnblockUser(ctx context.Context, blockerID, blockedID string) error {
	blockerUUID, err1 := uuid.Parse(blockerID)
	blockedUUID, err2 := uuid.Parse(blockedID)
	if err1 != nil || err2 != nil {
		return fmt.Errorf("invalid uuid")
	}

	res, err := s.db.Exec(ctx, "DELETE FROM public.blocks WHERE blocker_id = $1 AND blocked_id = $2", blockerUUID, blockedUUID)
	if err != nil {
		return err
	}
	if res.RowsAffected() == 0 {
		return fmt.Errorf("block not found")
	}
	return nil
}

func (s *friendService) GetBlockedUsers(ctx context.Context, userID string) ([]*models.Block, error) {
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		return nil, fmt.Errorf("invalid uuid")
	}

	query := `SELECT blocker_id, blocked_id, created_at FROM public.blocks WHERE blocker_id = $1 ORDER BY created_at DESC`
	rows, err := s.db.Query(ctx, query, userUUID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var blocks []*models.Block
	for rows.Next() {
		b := &models.Block{}
		if err := rows.Scan(&b.BlockerID, &b.BlockedID, &b.CreatedAt); err != nil {
			return nil, err
		}
		blocks = append(blocks, b)
	}
	return blocks, nil
}
