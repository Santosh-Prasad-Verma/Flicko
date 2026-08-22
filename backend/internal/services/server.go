package services

import (
	"context"
	"errors"
	"fmt"
	"strings"
	"time"

	"github.com/flicko-org/flicko-backend/internal/cache"
	"github.com/flicko-org/flicko-backend/internal/database"
	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
)

// ServerService is NOT wired into the HTTP router (cmd/server/main.go):
// server CRUD is served by the direct architecture and REST endpoints.
// This service is retained as a reference / ready-made backend-owned path.
type ServerService interface {
	CreateServer(ctx context.Context, ownerID, name, description, icon string) (*models.Server, error)
	GetServer(ctx context.Context, serverID string) (*models.Server, error)
	UpdateServer(ctx context.Context, serverID string, updates map[string]interface{}, executorID string) (*models.Server, error)
	DeleteServer(ctx context.Context, serverID string, executorID string) error

	JoinServer(ctx context.Context, userID, inviteCode string) (*models.Member, error)
	LeaveServer(ctx context.Context, serverID, userID string) error
	GetServerMembers(ctx context.Context, serverID string) ([]*models.Member, error)
	KickMember(ctx context.Context, serverID, userID, executorID, reason string) error
	BanMember(ctx context.Context, serverID, userID, executorID, reason string) error
	UnbanMember(ctx context.Context, serverID, userID, executorID string) error
}

type serverService struct {
	db           database.DatabaseClient
	cache        cache.CacheLayer
	permService  PermissionService
	auditService AuditLogService
}

func NewServerService(db database.DatabaseClient, cache cache.CacheLayer, permService PermissionService, auditService AuditLogService) ServerService {
	return &serverService{
		db:           db,
		cache:        cache,
		permService:  permService,
		auditService: auditService,
	}
}

func (s *serverService) CreateServer(ctx context.Context, ownerID, name, description, icon string) (*models.Server, error) {
	if len(name) < 2 || len(name) > 100 {
		return nil, fmt.Errorf("server name must be between 2 and 100 characters")
	}

	ownerUUID, err := uuid.Parse(ownerID)
	if err != nil {
		return nil, fmt.Errorf("invalid owner id: %w", err)
	}

	// Use a transaction to ensure server and owner membership are created together
	tx, err := s.db.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	query := `
		INSERT INTO public.servers (name, description, owner_id, icon_url)
		VALUES ($1, $2, $3, $4)
		RETURNING id, name, description, owner_id, icon_url, banner_url, system_channel_id, 
				  rules_channel_id, public_updates_channel_id, preferred_locale, features, 
				  verification_level, default_message_notifications, explicit_content_filter, 
				  mfa_level, nsfw_level, premium_tier, premium_subscription_count, 
				  vanity_url_code, discovery_enabled, created_at, updated_at
	`

	var server models.Server
	err = tx.QueryRow(ctx, query, name, description, ownerUUID, icon).Scan(
		&server.ID, &server.Name, &server.Description, &server.OwnerID, &server.IconURL,
		&server.BannerURL, &server.SystemChannelID, &server.RulesChannelID,
		&server.PublicUpdatesChannelID, &server.PreferredLocale, &server.Features,
		&server.VerificationLevel, &server.DefaultMessageNotifications,
		&server.ExplicitContentFilter, &server.MFALevel, &server.NSFWLevel,
		&server.PremiumTier, &server.PremiumSubscriptionCount, &server.VanityURLCode,
		&server.DiscoveryEnabled, &server.CreatedAt, &server.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("error creating server: %w", err)
	}

	// Add owner as a member
	_, err = tx.Exec(ctx, `INSERT INTO public.server_members (server_id, user_id) VALUES ($1, $2)`, server.ID, ownerUUID)
	if err != nil {
		return nil, fmt.Errorf("error adding owner as member: %w", err)
	}

	// Create default welcome settings for the new server
	_, err = tx.Exec(ctx, `INSERT INTO welcome_settings (server_id, enabled, welcome_message) VALUES ($1, true, 'Welcome to the server, {user}! 🎉')`, server.ID)
	if err != nil {
		return nil, fmt.Errorf("error creating welcome settings: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("failed to commit transaction: %w", err)
	}

	cacheKey := fmt.Sprintf("server:%s", server.ID)
	s.cache.SetJSON(ctx, cacheKey, &server, 1*time.Hour)

	// Audit Log
	_ = s.auditService.CreateLog(ctx, server.ID, &ownerID, models.ActionServerCreate, "server", &server.ID, nil, map[string]interface{}{
		"name": name,
	})

	return &server, nil
}

func (s *serverService) GetServer(ctx context.Context, serverID string) (*models.Server, error) {
	cacheKey := fmt.Sprintf("server:%s", serverID)
	var server models.Server
	err := s.cache.GetJSON(ctx, cacheKey, &server)
	if err == nil {
		return &server, nil
	}

	if s.db == nil {
		return &models.Server{ID: serverID, Name: "MockServer"}, nil
	}

	query := `
		SELECT id, name, description, owner_id, icon_url, banner_url, system_channel_id, 
			   rules_channel_id, public_updates_channel_id, preferred_locale, features, 
			   verification_level, default_message_notifications, explicit_content_filter, 
			   mfa_level, nsfw_level, premium_tier, premium_subscription_count, 
			   vanity_url_code, discovery_enabled, created_at, updated_at
		FROM public.servers
		WHERE id = $1
	`
	row := s.db.QueryRow(ctx, query, serverID)
	err = row.Scan(
		&server.ID, &server.Name, &server.Description, &server.OwnerID, &server.IconURL,
		&server.BannerURL, &server.SystemChannelID, &server.RulesChannelID,
		&server.PublicUpdatesChannelID, &server.PreferredLocale, &server.Features,
		&server.VerificationLevel, &server.DefaultMessageNotifications,
		&server.ExplicitContentFilter, &server.MFALevel, &server.NSFWLevel,
		&server.PremiumTier, &server.PremiumSubscriptionCount, &server.VanityURLCode,
		&server.DiscoveryEnabled, &server.CreatedAt, &server.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("error fetching server: %w", err)
	}

	s.cache.SetJSON(ctx, cacheKey, &server, 1*time.Hour)
	return &server, nil
}

func (s *serverService) UpdateServer(ctx context.Context, serverID string, updates map[string]interface{}, executorID string) (*models.Server, error) {
	executorUUID, err := uuid.Parse(executorID)
	if err != nil {
		return nil, fmt.Errorf("invalid executor id: %w", err)
	}

	serverUUID, err := uuid.Parse(serverID)
	if err != nil {
		return nil, fmt.Errorf("invalid server id: %w", err)
	}

	// Check permissions
	hasPerm, err := s.permService.HasServerPermission(ctx, executorUUID, serverUUID, "MANAGE_GUILD")
	if err != nil {
		return nil, fmt.Errorf("error checking permissions: %w", err)
	}
	if !hasPerm {
		return nil, errors.New("unauthorized: missing MANAGE_GUILD permission")
	}

	// Invalidate cache
	cacheKey := fmt.Sprintf("server:%s", serverID)
	defer s.cache.Delete(ctx, cacheKey)

	allowedFields := map[string]bool{
		"name":                          true,
		"description":                   true,
		"icon_url":                      true,
		"banner_url":                    true,
		"system_channel_id":             true,
		"rules_channel_id":              true,
		"public_updates_channel_id":      true,
		"preferred_locale":              true,
		"verification_level":            true,
		"default_message_notifications": true,
		"explicit_content_filter":       true,
		"mfa_level":                     true,
		"nsfw_level":                    true,
		"discovery_enabled":             true,
	}

	setClauses := []string{}
	args := []interface{}{serverID}
	argIdx := 2

	changes := make(map[string]interface{})
	for field, value := range updates {
		if !allowedFields[field] {
			continue
		}
		setClauses = append(setClauses, fmt.Sprintf("%s = $%d", field, argIdx))
		args = append(args, value)
		changes[field] = value
		argIdx++
	}

	if len(setClauses) == 0 {
		return s.GetServer(ctx, serverID)
	}

	query := fmt.Sprintf(`
		UPDATE public.servers
		SET %s, updated_at = NOW()
		WHERE id = $1
		RETURNING id, name, description, owner_id, icon_url, banner_url, system_channel_id, 
				  rules_channel_id, public_updates_channel_id, preferred_locale, features, 
				  verification_level, default_message_notifications, explicit_content_filter, 
				  mfa_level, nsfw_level, premium_tier, premium_subscription_count, 
				  vanity_url_code, discovery_enabled, created_at, updated_at
	`, strings.Join(setClauses, ", "))

	var server models.Server
	row := s.db.QueryRow(ctx, query, args...)
	err = row.Scan(
		&server.ID, &server.Name, &server.Description, &server.OwnerID, &server.IconURL,
		&server.BannerURL, &server.SystemChannelID, &server.RulesChannelID,
		&server.PublicUpdatesChannelID, &server.PreferredLocale, &server.Features,
		&server.VerificationLevel, &server.DefaultMessageNotifications,
		&server.ExplicitContentFilter, &server.MFALevel, &server.NSFWLevel,
		&server.PremiumTier, &server.PremiumSubscriptionCount, &server.VanityURLCode,
		&server.DiscoveryEnabled, &server.CreatedAt, &server.UpdatedAt,
	)
	if err != nil {
		return nil, fmt.Errorf("error updating server: %w", err)
	}

	// Audit Log
	_ = s.auditService.CreateLog(ctx, server.ID, &executorID, models.ActionServerUpdate, "server", &server.ID, nil, changes)

	return &server, nil
}

func (s *serverService) DeleteServer(ctx context.Context, serverID string, executorID string) error {
	executorUUID, err := uuid.Parse(executorID)
	if err != nil {
		return fmt.Errorf("invalid executor id: %w", err)
	}

	serverUUID, err := uuid.Parse(serverID)
	if err != nil {
		return fmt.Errorf("invalid server id: %w", err)
	}

	// Check if executor is the owner
	server, err := s.GetServer(ctx, serverID)
	if err != nil {
		return fmt.Errorf("error fetching server: %w", err)
	}

	if server.OwnerID != executorUUID.String() {
		return errors.New("unauthorized: only the owner can delete the server")
	}

	// Invalidate cache
	cacheKey := fmt.Sprintf("server:%s", serverID)
	s.cache.Delete(ctx, cacheKey)

	// Delete from database
	_, err = s.db.Exec(ctx, "DELETE FROM public.servers WHERE id = $1", serverUUID)
	if err != nil {
		return fmt.Errorf("error deleting server: %w", err)
	}

	// Audit Log
	_ = s.auditService.CreateLog(ctx, serverID, &executorID, models.ActionServerDelete, "server", &serverID, nil, map[string]interface{}{
		"name": server.Name,
	})

	return nil
}

func (s *serverService) JoinServer(ctx context.Context, userID, inviteCode string) (*models.Member, error) {
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		return nil, fmt.Errorf("invalid user id: %w", err)
	}

	// Check if user is already a member
	var exists bool
	err = s.db.QueryRow(ctx, "SELECT EXISTS(SELECT 1 FROM public.server_members WHERE server_id = (SELECT server_id FROM public.invites WHERE code = $1) AND user_id = $2)", inviteCode, userUUID).Scan(&exists)
	if err == nil && exists {
		return nil, errors.New("user is already a member of this server")
	}

	// Check if user is banned
	var isBanned bool
	err = s.db.QueryRow(ctx, "SELECT EXISTS(SELECT 1 FROM public.server_bans WHERE server_id = (SELECT server_id FROM public.invites WHERE code = $1) AND user_id = $2)", inviteCode, userUUID).Scan(&isBanned)
	if err == nil && isBanned {
		return nil, errors.New("user is banned from this server")
	}

	// Transaction to handle invite use and membership
	tx, err := s.db.Begin(ctx)
	if err != nil {
		return nil, fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	// Lookup invite
	var serverID uuid.UUID
	var uses, maxUses int
	var expiresAt *time.Time
	err = tx.QueryRow(ctx, "SELECT server_id, uses, max_uses, expires_at FROM public.invites WHERE code = $1 FOR UPDATE", inviteCode).
		Scan(&serverID, &uses, &maxUses, &expiresAt)
	if err != nil {
		if errors.Is(err, pgx.ErrNoRows) {
			return nil, errors.New("invalid or expired invite code")
		}
		return nil, fmt.Errorf("error fetching invite: %w", err)
	}

	// Check expiry/uses
	if expiresAt != nil && expiresAt.Before(time.Now()) {
		return nil, errors.New("invite code expired")
	}
	if maxUses > 0 && uses >= maxUses {
		return nil, errors.New("invite code reached maximum uses")
	}

	// Increment uses
	_, err = tx.Exec(ctx, "UPDATE public.invites SET uses = uses + 1 WHERE code = $1", inviteCode)
	if err != nil {
		return nil, fmt.Errorf("error updating invite uses: %w", err)
	}

	// Add member
	var member models.Member
	err = tx.QueryRow(ctx, `
		INSERT INTO public.server_members (server_id, user_id) 
		VALUES ($1, $2) 
		ON CONFLICT (server_id, user_id) DO UPDATE SET joined_at = EXCLUDED.joined_at
		RETURNING id, server_id, user_id, nickname, roles, joined_at, timeout_until, communication_disabled_until
	`, serverID, userUUID).Scan(
		&member.ID, &member.ServerID, &member.UserID, &member.Nickname, &member.Roles, &member.JoinedAt, &member.TimeoutUntil, &member.CommunicationDisabledUntil,
	)
	if err != nil {
		return nil, fmt.Errorf("error joining server: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("failed to commit transaction: %w", err)
	}

	// Audit Log
	sidStr := serverID.String()
	_ = s.auditService.CreateLog(ctx, sidStr, &userID, models.ActionMemberJoin, "server", &sidStr, nil, nil)

	return &member, nil
}

func (s *serverService) LeaveServer(ctx context.Context, serverID, userID string) error {
	executorUUID, err := uuid.Parse(userID)
	if err != nil {
		return fmt.Errorf("invalid user id: %w", err)
	}

	serverUUID, err := uuid.Parse(serverID)
	if err != nil {
		return fmt.Errorf("invalid server id: %w", err)
	}

	// Check if user is owner
	server, err := s.GetServer(ctx, serverID)
	if err != nil {
		return fmt.Errorf("error fetching server: %w", err)
	}

	if server.OwnerID == userID {
		return errors.New("owner cannot leave the server; transfer ownership first or delete the server")
	}

	// Remove from database
	tag, err := s.db.Exec(ctx, "DELETE FROM public.server_members WHERE server_id = $1 AND user_id = $2", serverUUID, executorUUID)
	if err != nil {
		return fmt.Errorf("error leaving server: %w", err)
	}

	if tag.RowsAffected() == 0 {
		return errors.New("user is not a member of this server")
	}

	// Audit Log
	_ = s.auditService.CreateLog(ctx, serverID, &userID, models.ActionMemberLeave, "server", &serverID, nil, nil)

	return nil
}

func (s *serverService) GetServerMembers(ctx context.Context, serverID string) ([]*models.Member, error) {
	serverUUID, err := uuid.Parse(serverID)
	if err != nil {
		return nil, fmt.Errorf("invalid server id: %w", err)
	}

	const maxMembersCap = 1000
	query := `
		SELECT id, server_id, user_id, nickname, roles, joined_at, timeout_until, communication_disabled_until
		FROM public.server_members
		WHERE server_id = $1
		ORDER BY joined_at ASC
		LIMIT $2
	`
	rows, err := s.db.Query(ctx, query, serverUUID, maxMembersCap)
	if err != nil {
		return nil, fmt.Errorf("error fetching server members: %w", err)
	}
	defer rows.Close()

	members := make([]*models.Member, 0, 64)
	for rows.Next() {
		var m models.Member
		err := rows.Scan(&m.ID, &m.ServerID, &m.UserID, &m.Nickname, &m.Roles, &m.JoinedAt, &m.TimeoutUntil, &m.CommunicationDisabledUntil)
		if err != nil {
			return nil, fmt.Errorf("error scanning member: %w", err)
		}
		members = append(members, &m)
	}

	return members, nil
}

func (s *serverService) KickMember(ctx context.Context, serverID, userID, executorID, reason string) error {
	executorUUID, err := uuid.Parse(executorID)
	if err != nil {
		return fmt.Errorf("invalid executor id: %w", err)
	}
	serverUUID, err := uuid.Parse(serverID)
	if err != nil {
		return fmt.Errorf("invalid server id: %w", err)
	}
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		return fmt.Errorf("invalid user id: %w", err)
	}

	// Permission Check
	hasPerm, err := s.permService.HasServerPermission(ctx, executorUUID, serverUUID, "KICK_MEMBERS")
	if err != nil {
		return fmt.Errorf("error checking permissions: %w", err)
	}
	if !hasPerm {
		return errors.New("unauthorized: missing KICK_MEMBERS permission")
	}

	// Don't allow kicking the owner
	server, err := s.GetServer(ctx, serverID)
	if err == nil && server.OwnerID == userID {
		return errors.New("cannot kick the server owner")
	}

	// Execute delete
	tag, err := s.db.Exec(ctx, "DELETE FROM public.server_members WHERE server_id = $1 AND user_id = $2", serverUUID, userUUID)
	if err != nil {
		return fmt.Errorf("failed to kick member: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return errors.New("user is not a member of this server")
	}

	// Audit Log
	_ = s.auditService.CreateLog(ctx, serverID, &executorID, models.ActionMemberKick, "user", &userID, &reason, nil)

	return nil
}

func (s *serverService) BanMember(ctx context.Context, serverID, userID, executorID, reason string) error {
	executorUUID, err := uuid.Parse(executorID)
	if err != nil {
		return fmt.Errorf("invalid executor id: %w", err)
	}
	serverUUID, err := uuid.Parse(serverID)
	if err != nil {
		return fmt.Errorf("invalid server id: %w", err)
	}
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		return fmt.Errorf("invalid user id: %w", err)
	}

	// Permission Check
	hasPerm, err := s.permService.HasServerPermission(ctx, executorUUID, serverUUID, "BAN_MEMBERS")
	if err != nil {
		return fmt.Errorf("error checking permissions: %w", err)
	}
	if !hasPerm {
		return errors.New("unauthorized: missing BAN_MEMBERS permission")
	}

	// Don't allow banning the owner
	server, err := s.GetServer(ctx, serverID)
	if err == nil && server.OwnerID == userID {
		return errors.New("cannot ban the server owner")
	}

	// Transaction
	tx, err := s.db.Begin(ctx)
	if err != nil {
		return fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	// Insert into bans
	_, err = tx.Exec(ctx, "INSERT INTO public.server_bans (server_id, user_id, executor_id, reason) VALUES ($1, $2, $3, $4) ON CONFLICT (server_id, user_id) DO UPDATE SET reason = EXCLUDED.reason", serverUUID, userUUID, executorUUID, reason)
	if err != nil {
		return fmt.Errorf("failed to ban member: %w", err)
	}

	// Remove from members
	_, err = tx.Exec(ctx, "DELETE FROM public.server_members WHERE server_id = $1 AND user_id = $2", serverUUID, userUUID)
	if err != nil {
		return fmt.Errorf("failed to remove banned member: %w", err)
	}

	if err := tx.Commit(ctx); err != nil {
		return fmt.Errorf("failed to commit transaction: %w", err)
	}

	// Audit Log
	_ = s.auditService.CreateLog(ctx, serverID, &executorID, models.ActionMemberBan, "user", &userID, &reason, nil)

	return nil
}

func (s *serverService) UnbanMember(ctx context.Context, serverID, userID, executorID string) error {
	executorUUID, err := uuid.Parse(executorID)
	if err != nil {
		return fmt.Errorf("invalid executor id: %w", err)
	}
	serverUUID, err := uuid.Parse(serverID)
	if err != nil {
		return fmt.Errorf("invalid server id: %w", err)
	}
	userUUID, err := uuid.Parse(userID)
	if err != nil {
		return fmt.Errorf("invalid user id: %w", err)
	}

	// Permission Check
	hasPerm, err := s.permService.HasServerPermission(ctx, executorUUID, serverUUID, "BAN_MEMBERS")
	if err != nil {
		return fmt.Errorf("error checking permissions: %w", err)
	}
	if !hasPerm {
		return errors.New("unauthorized: missing BAN_MEMBERS permission")
	}

	// Delete from bans
	tag, err := s.db.Exec(ctx, "DELETE FROM public.server_bans WHERE server_id = $1 AND user_id = $2", serverUUID, userUUID)
	if err != nil {
		return fmt.Errorf("failed to unban member: %w", err)
	}
	if tag.RowsAffected() == 0 {
		return errors.New("user is not banned from this server")
	}

	// Audit Log
	_ = s.auditService.CreateLog(ctx, serverID, &executorID, models.ActionMemberUnban, "user", &userID, nil, nil)

	return nil
}
