package services

import (
	"context"
	"crypto/rand"
	"encoding/base64"
	"fmt"
	"time"

	"github.com/flicko-org/flicko-backend/internal/events"
	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type InviteService interface {
	CreateInvite(ctx context.Context, inviterID, channelID string, maxUses int, expiresAt *time.Time) (*models.Invite, error)
	GetInvite(ctx context.Context, code string) (*models.Invite, error)
	AcceptInvite(ctx context.Context, userID, code string) error
	RevokeInvite(ctx context.Context, revokerID, code string) error
}

type inviteService struct {
	db          *pgxpool.Pool
	permService PermissionService
	eventBus    *events.EventBus
}

func NewInviteService(db *pgxpool.Pool, permService PermissionService, eventBus *events.EventBus) InviteService {
	return &inviteService{
		db:          db,
		permService: permService,
		eventBus:    eventBus,
	}
}

func generateInviteCode() string {
	b := make([]byte, 6)
	rand.Read(b)
	return base64.URLEncoding.EncodeToString(b)[:8]
}

func (s *inviteService) CreateInvite(ctx context.Context, inviterID, channelID string, maxUses int, expiresAt *time.Time) (*models.Invite, error) {
	inviterUUID, err1 := uuid.Parse(inviterID)
	channelUUID, err2 := uuid.Parse(channelID)

	if err1 != nil || err2 != nil {
		return nil, fmt.Errorf("invalid uuid")
	}

	// 1. Verify CREATE_INVITE permission
	hasPerm, err := s.permService.HasPermission(ctx, inviterUUID, channelUUID, "CREATE_INVITE")
	if err != nil {
		return nil, fmt.Errorf("failed to check permissions: %w", err)
	}
	if !hasPerm {
		return nil, fmt.Errorf("user does not have CREATE_INVITE permission for this channel")
	}

	// 2. Get server_id from channel
	var serverID uuid.UUID
	err = s.db.QueryRow(ctx, "SELECT server_id FROM public.channels WHERE id = $1", channelUUID).Scan(&serverID)
	if err != nil {
		return nil, fmt.Errorf("failed to find channel's server: %w", err)
	}

	code := generateInviteCode()

	query := `
		INSERT INTO public.invites (code, server_id, channel_id, inviter_id, max_uses, expires_at)
		VALUES ($1, $2, $3, $4, $5, $6)
		RETURNING code, server_id, channel_id, inviter_id, uses, max_uses, created_at, expires_at
	`

	var inv models.Invite
	err = s.db.QueryRow(ctx, query, code, serverID, channelUUID, inviterUUID, maxUses, expiresAt).
		Scan(&inv.Code, &inv.ServerID, &inv.ChannelID, &inv.InviterID, &inv.Uses, &inv.MaxUses, &inv.CreatedAt, &inv.ExpiresAt)
	if err != nil {
		return nil, fmt.Errorf("failed to create invite: %w", err)
	}

	return &inv, nil
}

func (s *inviteService) GetInvite(ctx context.Context, code string) (*models.Invite, error) {
	query := `
		SELECT code, server_id, channel_id, inviter_id, uses, max_uses, created_at, expires_at
		FROM public.invites
		WHERE code = $1
	`
	var inv models.Invite
	err := s.db.QueryRow(ctx, query, code).
		Scan(&inv.Code, &inv.ServerID, &inv.ChannelID, &inv.InviterID, &inv.Uses, &inv.MaxUses, &inv.CreatedAt, &inv.ExpiresAt)

	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, fmt.Errorf("invite not found or expired")
		}
		return nil, fmt.Errorf("database error: %w", err)
	}

	if inv.ExpiresAt != nil && inv.ExpiresAt.Before(time.Now()) {
		return nil, fmt.Errorf("invite expired")
	}
	if inv.MaxUses > 0 && inv.Uses >= inv.MaxUses {
		return nil, fmt.Errorf("invite use limit reached")
	}

	return &inv, nil
}

func (s *inviteService) AcceptInvite(ctx context.Context, userID, code string) error {
	userUUID, err1 := uuid.Parse(userID)
	if err1 != nil {
		return fmt.Errorf("invalid user id")
	}

	tx, err := s.db.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	// Retrieve & lock invite to handle uses bounds correctly
	var serverID, channelID uuid.UUID
	var uses, maxUses int
	var expiresAt *time.Time

	err = tx.QueryRow(ctx, "SELECT server_id, channel_id, uses, max_uses, expires_at FROM public.invites WHERE code = $1 FOR UPDATE", code).
		Scan(&serverID, &channelID, &uses, &maxUses, &expiresAt)

	if err != nil {
		if err == pgx.ErrNoRows {
			return fmt.Errorf("invite not found")
		}
		return err
	}

	if expiresAt != nil && expiresAt.Before(time.Now()) {
		return fmt.Errorf("invite expired")
	}
	if maxUses > 0 && uses >= maxUses {
		return fmt.Errorf("invite use limit reached")
	}

	// Update use count
	_, err = tx.Exec(ctx, "UPDATE public.invites SET uses = uses + 1 WHERE code = $1", code)
	if err != nil {
		return fmt.Errorf("failed to tracking invite uses: %w", err)
	}

	// Add member to server if not already in server
	_, err = tx.Exec(ctx, "INSERT INTO public.server_members (server_id, user_id) VALUES ($1, $2) ON CONFLICT DO NOTHING", serverID, userUUID)
	if err != nil {
		return err
	}

	// NOTE: Assign default role (@everyone) - normally assigned via DB triggers or app hooks directly to basic server membership
	if err := tx.Commit(ctx); err != nil {
		return err
	}

	// Publish MEMBER_JOIN event so bots (e.g. WelcomeBot) can react
	if s.eventBus != nil {
		s.eventBus.Publish(events.Event{
			Type:      events.MemberJoin,
			ServerID:  serverID.String(),
			UserID:    userUUID.String(),
			Data:      map[string]interface{}{},
			Timestamp: time.Now(),
		})
	}

	return nil
}

func (s *inviteService) RevokeInvite(ctx context.Context, revokerID, code string) error {
	revokerUUID, err1 := uuid.Parse(revokerID)
	if err1 != nil {
		return fmt.Errorf("invalid uuid")
	}

	var serverID uuid.UUID
	err := s.db.QueryRow(ctx, "SELECT server_id FROM public.invites WHERE code = $1", code).Scan(&serverID)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil // Already gone
		}
		return err
	}

	hasPerm, err := s.permService.HasPermission(ctx, revokerUUID, serverID, "MANAGE_GUILD")
	if err != nil {
		return err
	}

	// Allow if user is either inviter or MANAGE_GUILD admin
	var inviterID uuid.UUID
	err = s.db.QueryRow(ctx, "SELECT inviter_id FROM public.invites WHERE code = $1", code).Scan(&inviterID)
	if err == nil {
		if revokerUUID != inviterID && !hasPerm {
			return fmt.Errorf("unauthorized to revoke invite")
		}
	} else {
		return err
	}

	_, err = s.db.Exec(ctx, "DELETE FROM public.invites WHERE code = $1", code)
	return err
}
