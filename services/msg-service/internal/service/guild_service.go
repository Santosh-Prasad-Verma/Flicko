package service

import (
	"context"
	"strings"

	"go.uber.org/zap"

	"github.com/flicko-org/flicko/services/msg-service/internal/repository"
	fkerr "github.com/flicko-org/flicko/services/shared/errors"
	"github.com/flicko-org/flicko/services/shared/id"
)

// GuildService handles guild CRUD and membership.
type GuildService struct {
	guilds repository.GuildRepository
	log    *zap.Logger
}

// NewGuildService creates a GuildService.
func NewGuildService(
	guilds repository.GuildRepository,
	log *zap.Logger,
) *GuildService {
	return &GuildService{
		guilds: guilds,
		log:    log.Named("svc.guild"),
	}
}

// CreateGuildRequest is the validated input for guild creation.
type CreateGuildRequest struct {
	UserID      string // becomes owner
	Name        string
	Description string
	Region      string
}

// CreateGuild validates, persists, and auto-adds the owner as member.
func (s *GuildService) CreateGuild(ctx context.Context, req CreateGuildRequest) (*repository.Guild, error) {
	name := strings.TrimSpace(req.Name)
	if name == "" {
		return nil, fkerr.ErrMissingField("name")
	}
	if len(name) > 100 {
		return nil, fkerr.ErrValidation("guild name must be 100 characters or less")
	}

	region := req.Region
	if region == "" {
		region = "us-east"
	}

	g := &repository.Guild{
		ID:      id.New(),
		Name:    name,
		OwnerID: req.UserID,
		Region:  region,
	}
	if req.Description != "" {
		desc := req.Description
		g.Description = &desc
	}

	if err := s.guilds.Create(ctx, g); err != nil {
		return nil, fkerr.ErrInternal(err)
	}

	// Auto-add owner as first member.
	if err := s.guilds.AddMember(ctx, g.ID, req.UserID); err != nil {
		s.log.Error("failed to add owner as member", zap.Error(err))
		// Guild was created; don't fail the entire request.
	}

	return g, nil
}

// GetGuild returns a guild by ID.
func (s *GuildService) GetGuild(ctx context.Context, guildID string) (*repository.Guild, error) {
	g, err := s.guilds.GetByID(ctx, guildID)
	if err != nil {
		return nil, fkerr.ErrInternal(err)
	}
	if g == nil {
		return nil, fkerr.ErrNotFound("guild")
	}
	return g, nil
}

// GetMyGuilds returns all guilds the user is a member of.
func (s *GuildService) GetMyGuilds(ctx context.Context, userID string) ([]*repository.Guild, error) {
	guilds, err := s.guilds.GetUserGuilds(ctx, userID)
	if err != nil {
		return nil, fkerr.ErrInternal(err)
	}
	return guilds, nil
}

// JoinGuild adds a user to a guild.
func (s *GuildService) JoinGuild(ctx context.Context, guildID, requesterID, targetUserID string) error {
	if requesterID != targetUserID {
		return fkerr.ErrForbidden("you can only join as yourself")
	}

	if err := s.guilds.AddMember(ctx, guildID, targetUserID); err != nil {
		return fkerr.ErrInternal(err)
	}
	return nil
}

// LeaveGuild removes a user from a guild.
func (s *GuildService) LeaveGuild(ctx context.Context, guildID, requesterID, targetUserID string) error {
	if requesterID != targetUserID {
		return fkerr.ErrForbidden("you can only remove yourself")
	}

	if err := s.guilds.RemoveMember(ctx, guildID, targetUserID); err != nil {
		return fkerr.ErrInternal(err)
	}
	return nil
}

// ListMembers returns paginated guild members.
func (s *GuildService) ListMembers(ctx context.Context, guildID string, limit, offset int) ([]*repository.Member, error) {
	members, err := s.guilds.GetMembers(ctx, guildID, limit, offset)
	if err != nil {
		return nil, fkerr.ErrInternal(err)
	}
	return members, nil
}
