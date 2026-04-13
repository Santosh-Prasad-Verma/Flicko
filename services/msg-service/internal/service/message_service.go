// Package service holds the core business logic for messages, channels,
// guilds, and media operations in the msg-service.
//
// Each service struct depends on repository interfaces (for testability)
// and shared packages (redis, auth, etc.) injected via constructors.
package service

import (
	"context"
	"fmt"
	"strings"
	"time"

	"go.uber.org/zap"

	"github.com/flicko-org/flicko/services/msg-service/internal/abuse"
	"github.com/flicko-org/flicko/services/msg-service/internal/batcher"
	"github.com/flicko-org/flicko/services/msg-service/internal/pubsub"
	"github.com/flicko-org/flicko/services/msg-service/internal/repository"
	fkerr "github.com/flicko-org/flicko/services/shared/errors"
	"github.com/flicko-org/flicko/services/shared/id"
	flickoredis "github.com/flicko-org/flicko/services/shared/redis"
)

// MaxContentLength is the maximum message content length (2000 Unicode chars).
const MaxContentLength = 2000

// MessageService handles message CRUD and real-time publishing.
type MessageService struct {
	messages    repository.MessageRepository
	channels    repository.ChannelRepository
	batcher     *batcher.MessageBatcher
	idempotency *flickoredis.IdempotencyStore
	cache       *flickoredis.Cache
	detector    *abuse.Detector
	enforcer    *abuse.Enforcer
	publisher   *pubsub.Publisher
	log         *zap.Logger
}

// NewMessageService creates a MessageService.
//
// The batcher parameter may be nil—in that case CreateMessage falls
// back to synchronous single-row Create (useful in tests or when the
// batcher goroutine is not running).
//
// The detector and enforcer parameters may be nil—in that case abuse
// checking is skipped (useful in tests or when the abuse system is
// not configured).
//
// The publisher parameter may be nil—in that case Pub/Sub publish is
// skipped (useful in tests).
func NewMessageService(
	msgs repository.MessageRepository,
	chs repository.ChannelRepository,
	b *batcher.MessageBatcher,
	idempotency *flickoredis.IdempotencyStore,
	cache *flickoredis.Cache,
	detector *abuse.Detector,
	enforcer *abuse.Enforcer,
	pub *pubsub.Publisher,
	log *zap.Logger,
) *MessageService {
	return &MessageService{
		messages:    msgs,
		channels:    chs,
		batcher:     b,
		idempotency: idempotency,
		cache:       cache,
		detector:    detector,
		enforcer:    enforcer,
		publisher:   pub,
		log:         log.Named("svc.message"),
	}
}

// CreateMessageRequest is the validated input for message creation.
type CreateMessageRequest struct {
	ChannelID   string
	AuthorID    string
	Content     string
	Nonce       string
	Type        string
	ReferenceID string // reply_to

	// IsDM is true when the message targets a DM channel.
	IsDM bool
	// RecipientID is set when IsDM is true.
	RecipientID string
}

// CreateMessage validates, deduplicates, and persists a new message.
//
// Flow:
//  1. Check channel membership (via cache or DB)
//  2. Validate content length + sanitize
//  3. Abuse detection
//  4. Generate message ID (ULID)
//  5. Persist to PostgreSQL
//  6. Publish message.created event to Redis Pub/Sub for cross-gateway fanout
//  7. Return created message
func (s *MessageService) CreateMessage(ctx context.Context, req CreateMessageRequest) (*repository.Message, error) {
	// Validate content.
	content := strings.TrimSpace(req.Content)
	if content == "" {
		return nil, fkerr.ErrMissingField("content")
	}
	if len([]rune(content)) > MaxContentLength {
		return nil, fkerr.New(fkerr.CodeMessageTooLong,
			fmt.Sprintf("message content exceeds %d characters", MaxContentLength))
	}

	// Validate channel type.
	msgType := req.Type
	if msgType == "" {
		msgType = "default"
	}

	// Check membership.
	member, err := s.channels.IsMember(ctx, req.ChannelID, req.AuthorID)
	if err != nil {
		return nil, fkerr.ErrInternal(err)
	}
	if !member {
		return nil, fkerr.ErrNotMember()
	}

	// ── Abuse detection ───────────────────────────────────
	// Before persisting, check all abuse signals. If flagged, execute
	// the action and decide whether to proceed.
	if s.detector != nil && s.enforcer != nil {
		result := s.detector.Check(ctx, abuse.CheckInput{
			UserID:      req.AuthorID,
			ChannelID:   req.ChannelID,
			Content:     content,
			IsDM:        req.IsDM,
			RecipientID: req.RecipientID,
		})
		if result.Flagged {
			if execErr := s.enforcer.Execute(ctx, result, req.AuthorID); execErr != nil {
				s.log.Error("abuse action failed",
					zap.String("user_id", req.AuthorID),
					zap.Error(execErr),
				)
			}

			if result.Action == abuse.ActionShadowMute {
				// Shadow mute: store the message so the author sees it,
				// but skip Pub/Sub publishing so others never receive it.
				// Fall through to persist but mark for no-publish.
				s.log.Info("shadow mute: storing message without publish",
					zap.String("user_id", req.AuthorID),
					zap.String("reason", string(result.Reason)),
				)
				// Proceed to persist below — Pub/Sub publish is skipped
				// for shadow-muted users (shadowPublish = false).
			} else {
				// Hard mute / kick / ban: reject entirely.
				return nil, fkerr.New(fkerr.CodeUserMuted,
					"your message could not be sent")
			}
		}
	}

	// Track whether to skip pub/sub (shadow-muted users).
	shadowMuted := false
	if s.detector != nil && s.enforcer != nil {
		// Re-check: if we fell through above with ActionShadowMute,
		// mark for no-publish.
		result := s.detector.Check(ctx, abuse.CheckInput{
			UserID:    req.AuthorID,
			ChannelID: req.ChannelID,
			Content:   content,
		})
		if result.Flagged && result.Action == abuse.ActionShadowMute {
			shadowMuted = true
		}
	}

	// Build message model.
	msg := &repository.Message{
		ID:          id.New(),
		ChannelID:   req.ChannelID,
		AuthorID:    req.AuthorID,
		Content:     content,
		Attachments: repository.DefaultAttachments(),
		Embeds:      repository.DefaultEmbeds(),
		Type:        msgType,
	}
	if req.ReferenceID != "" {
		msg.ReplyToID = &req.ReferenceID
	}
	if req.Nonce != "" {
		msg.Nonce = &req.Nonce
	}

	// Persist — async via batcher when available, synchronous fallback
	// otherwise. The batcher Submit is non-blocking; the message will
	// appear in PostgreSQL within ≤50ms (maxWait).

	// We pass a callback to PublishMessageCreated so that Redis gets the event
	// ONLY AFTER the message is safely stored in the database.
	onFlushed := func() {
		if s.publisher != nil && !shadowMuted {
			createdAt := time.Now()
			if err := s.publisher.PublishMessageCreated(
				context.Background(), msg.ChannelID, msg.ID, msg.AuthorID, createdAt, req.IsDM,
			); err != nil {
				s.log.Error("pubsub publish failed (message persisted)",
					zap.String("message_id", msg.ID),
					zap.String("channel_id", msg.ChannelID),
					zap.Error(err),
				)
			}
		}
	}

	if s.batcher != nil {
		if err := s.batcher.Submit(msg, onFlushed); err != nil {
			return nil, err // backpressure error propagated as-is
		}
	} else {
		if err := s.messages.Create(ctx, msg); err != nil {
			return nil, fkerr.ErrInternal(err)
		}
		onFlushed()
	}

	// Return the newly constructed message object to the caller (it matches what will persist)
	return msg, nil
}

// GetMessages retrieves messages for a channel with cursor pagination.
func (s *MessageService) GetMessages(ctx context.Context, channelID, userID, before string, limit int) ([]*repository.Message, error) {
	// Check membership.
	member, err := s.channels.IsMember(ctx, channelID, userID)
	if err != nil {
		return nil, fkerr.ErrInternal(err)
	}
	if !member {
		return nil, fkerr.ErrNotMember()
	}

	msgs, err := s.messages.GetByChannel(ctx, channelID, before, limit)
	if err != nil {
		return nil, fkerr.ErrInternal(err)
	}
	return msgs, nil
}

// EditMessage updates a message's content. Only the author may edit.
func (s *MessageService) EditMessage(ctx context.Context, messageID, userID, content string) error {
	content = strings.TrimSpace(content)
	if content == "" {
		return fkerr.ErrMissingField("content")
	}
	if len([]rune(content)) > MaxContentLength {
		return fkerr.New(fkerr.CodeMessageTooLong,
			fmt.Sprintf("message content exceeds %d characters", MaxContentLength))
	}

	msg, err := s.messages.GetByMessageID(ctx, messageID)
	if err != nil {
		return err
	}
	if msg.AuthorID != userID {
		return fkerr.ErrForbidden("you can only edit your own messages")
	}

	if err := s.messages.Update(ctx, messageID, content); err != nil {
		return fkerr.ErrInternal(err)
	}

	// Publish message.updated event for cross-gateway fanout.
	if s.publisher != nil {
		if err := s.publisher.PublishMessageUpdated(ctx, msg.ChannelID, messageID, userID, false); err != nil {
			s.log.Error("failed to publish message updated event", zap.Error(err))
		}
	}
	return nil
}

// DeleteMessage soft-deletes a message.
func (s *MessageService) DeleteMessage(ctx context.Context, messageID, userID string) error {
	msg, err := s.messages.GetByMessageID(ctx, messageID)
	if err != nil {
		return err
	}
	if msg.AuthorID != userID {
		return fkerr.ErrForbidden("you can only delete your own messages")
	}

	if err := s.messages.SoftDelete(ctx, messageID); err != nil {
		return fkerr.ErrInternal(err)
	}

	// Publish message.deleted event for cross-gateway fanout.
	if s.publisher != nil {
		if err := s.publisher.PublishMessageDeleted(ctx, msg.ChannelID, messageID, userID, false); err != nil {
			s.log.Error("failed to publish message deleted event", zap.Error(err))
		}
	}
	return nil
}
