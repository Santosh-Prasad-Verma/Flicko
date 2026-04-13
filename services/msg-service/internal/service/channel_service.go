package service

import (
	"context"
	"strings"

	"go.uber.org/zap"

	"github.com/flicko-org/flicko/services/msg-service/internal/repository"
	fkerr "github.com/flicko-org/flicko/services/shared/errors"
	"github.com/flicko-org/flicko/services/shared/id"
)

// ChannelService handles channel CRUD.
type ChannelService struct {
	channels repository.ChannelRepository
	guilds   repository.GuildRepository
	log      *zap.Logger
}

// NewChannelService creates a ChannelService.
func NewChannelService(
	chs repository.ChannelRepository,
	guilds repository.GuildRepository,
	log *zap.Logger,
) *ChannelService {
	return &ChannelService{
		channels: chs,
		guilds:   guilds,
		log:      log.Named("svc.channel"),
	}
}

// CreateChannelRequest is the validated input for channel creation.
type CreateChannelRequest struct {
	GuildID  string
	UserID   string // must be guild member
	Name     string
	Type     string
	ParentID string
	Topic    string
}

// CreateChannel validates and persists a new channel.
func (s *ChannelService) CreateChannel(ctx context.Context, req CreateChannelRequest) (*repository.Channel, error) {
	guild, err := s.guilds.GetByID(ctx, req.GuildID)
	if err != nil {
		return nil, err
	}
	if guild.OwnerID != req.UserID {
		return nil, fkerr.ErrForbidden("only the guild owner can create channels")
	}

	name := strings.TrimSpace(req.Name)
	if name == "" {
		return nil, fkerr.ErrMissingField("name")
	}
	if len(name) > 100 {
		return nil, fkerr.ErrValidation("channel name must be 100 characters or less")
	}

	chType := req.Type
	if chType == "" {
		chType = "text"
	}

	ch := &repository.Channel{
		ID:       id.New(),
		ServerID: req.GuildID,
		Name:     name,
		Type:     chType,
	}
	if req.ParentID != "" {
		ch.ParentID = &req.ParentID
	}
	if req.Topic != "" {
		topic := req.Topic
		ch.Topic = &topic
	}

	if err := s.channels.Create(ctx, ch); err != nil {
		return nil, fkerr.ErrInternal(err)
	}
	return ch, nil
}

// ListChannels returns all channels in a guild.
func (s *ChannelService) ListChannels(ctx context.Context, guildID, userID string) ([]*repository.Channel, error) {
	isMember, err := s.guilds.IsMember(ctx, guildID, userID)
	if err != nil {
		return nil, fkerr.ErrInternal(err)
	}
	if !isMember {
		return nil, fkerr.ErrNotMember()
	}

	chs, err := s.channels.GetByGuild(ctx, guildID)
	if err != nil {
		return nil, fkerr.ErrInternal(err)
	}
	return chs, nil
}

// UpdateChannel patches a channel's fields.
func (s *ChannelService) UpdateChannel(ctx context.Context, channelID, userID string, updates repository.ChannelUpdate) error {
	channel, err := s.channels.GetByID(ctx, channelID)
	if err != nil {
		return err
	}
	guild, err := s.guilds.GetByID(ctx, channel.ServerID)
	if err != nil {
		return err
	}
	if guild.OwnerID != userID {
		return fkerr.ErrForbidden("only the guild owner can update channels")
	}

	if err := s.channels.Update(ctx, channelID, updates); err != nil {
		return fkerr.ErrInternal(err)
	}
	return nil
}

// DeleteChannel removes a channel.
func (s *ChannelService) DeleteChannel(ctx context.Context, channelID, userID string) error {
	channel, err := s.channels.GetByID(ctx, channelID)
	if err != nil {
		return err
	}
	guild, err := s.guilds.GetByID(ctx, channel.ServerID)
	if err != nil {
		return err
	}
	if guild.OwnerID != userID {
		return fkerr.ErrForbidden("only the guild owner can delete channels")
	}

	if err := s.channels.Delete(ctx, channelID); err != nil {
		return fkerr.ErrInternal(err)
	}
	return nil
}
