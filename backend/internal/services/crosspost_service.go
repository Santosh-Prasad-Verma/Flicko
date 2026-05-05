package services

import (
	"context"
	"fmt"
	"log"

	"github.com/flicko-org/flicko-backend/internal/models"
	"github.com/google/uuid"
	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
)

type CrosspostService interface {
	CrosspostMessage(ctx context.Context, userID, originalMessageID, targetChannelID string) (*models.Message, error)
}

type crosspostService struct {
	db           *pgxpool.Pool
	permService  PermissionService
	auditService AuditLogService
}

func NewCrosspostService(db *pgxpool.Pool, permService PermissionService, auditService AuditLogService) CrosspostService {
	return &crosspostService{
		db:           db,
		permService:  permService,
		auditService: auditService,
	}
}

func (s *crosspostService) CrosspostMessage(ctx context.Context, userID, originalMessageID, targetChannelID string) (*models.Message, error) {
	// Parse IDs
	userUUID, err1 := uuid.Parse(userID)
	targetChanUUID, err2 := uuid.Parse(targetChannelID)
	origMsgUUID, err3 := uuid.Parse(originalMessageID)

	if err1 != nil || err2 != nil || err3 != nil {
		return nil, fmt.Errorf("invalid uuid provided")
	}

	// 1. Verify SEND_MESSAGES permission in the target channel
	hasPerm, err := s.permService.HasPermission(ctx, userUUID, targetChanUUID, "SEND_MESSAGES")
	if err != nil {
		return nil, fmt.Errorf("failed to check permissions: %w", err)
	}
	if !hasPerm {
		return nil, fmt.Errorf("user does not have SEND_MESSAGES permission in the target channel")
	}

	// 2. Begin transaction
	tx, err := s.db.BeginTx(ctx, pgx.TxOptions{})
	if err != nil {
		return nil, fmt.Errorf("failed to start transaction: %w", err)
	}
	defer tx.Rollback(ctx)

	// 3. Fetch original message
	var msg models.Message
	err = tx.QueryRow(ctx, "SELECT id, channel_id, author_id, content, created_at, updated_at FROM public.messages WHERE id = $1 AND deleted_at IS NULL", origMsgUUID).
		Scan(&msg.ID, &msg.ChannelID, &msg.AuthorID, &msg.Content, &msg.CreatedAt, &msg.UpdatedAt)
	if err != nil {
		if err == pgx.ErrNoRows {
			return nil, fmt.Errorf("original message not found or deleted")
		}
		return nil, fmt.Errorf("failed to fetch original message: %w", err)
	}

	// 4. Create new message
	newMsgID := uuid.New()
	newMsg := &models.Message{
		ID:        newMsgID.String(),
		ChannelID: targetChanUUID.String(),
		AuthorID:  msg.AuthorID, // Persist original author or set to crossposter? Usually crossposter or bot. Let's say user who crossposts or original.
		Content:   msg.Content,
	}

	newMsg.AuthorID = &userID

	_, err = tx.Exec(ctx, "INSERT INTO public.messages (id, channel_id, author_id, content) VALUES ($1, $2, $3, $4)",
		newMsgID, targetChanUUID, newMsg.AuthorID, newMsg.Content)
	if err != nil {
		return nil, fmt.Errorf("failed to insert crossposted message: %w", err)
	}

	// 5. Create basic flags for the new message
	_, err = tx.Exec(ctx, "INSERT INTO public.message_flags (message_id, is_crossposted) VALUES ($1, $2) ON CONFLICT (message_id) DO UPDATE SET is_crossposted = true", newMsgID, true)
	if err != nil {
		return nil, fmt.Errorf("failed to set flag on new message: %w", err)
	}

	// 6. Update original message flags
	_, err = tx.Exec(ctx, "INSERT INTO public.message_flags (message_id, is_crossposted) VALUES ($1, $2) ON CONFLICT (message_id) DO UPDATE SET is_crossposted = true", origMsgUUID, true)
	if err != nil {
		return nil, fmt.Errorf("failed to update original message flag: %w", err)
	}

	// 7. Copy attachments
	rows, err := tx.Query(ctx, "SELECT filename, size, mime_type, url, width, height, is_malware FROM public.attachments WHERE message_id = $1", origMsgUUID)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch original attachments: %w", err)
	}
	defer rows.Close()

	var attachments [][]interface{}
	for rows.Next() {
		var a struct {
			filename  string
			size      int64
			mime_type string
			url       string
			width     *int
			height    *int
			isMalware bool
		}
		if err := rows.Scan(&a.filename, &a.size, &a.mime_type, &a.url, &a.width, &a.height, &a.isMalware); err == nil {
			attachments = append(attachments, []interface{}{uuid.New(), newMsgID, a.filename, a.size, a.mime_type, a.url, a.width, a.height, a.isMalware})
		}
	}
	rows.Close()

	if len(attachments) > 0 {
		_, err = tx.CopyFrom(ctx, pgx.Identifier{"public", "attachments"},
			[]string{"id", "message_id", "filename", "size", "mime_type", "url", "width", "height", "is_malware"},
			pgx.CopyFromRows(attachments))
		if err != nil {
			log.Printf("[Crosspost] failed to copy attachments: %v", err)
		}
	}

	// 8. Copy embeds
	erows, err := tx.Query(ctx, "SELECT type, title, description, url, image_url, video_url, color FROM public.embeds WHERE message_id = $1", origMsgUUID)
	if err != nil {
		return nil, fmt.Errorf("failed to fetch original embeds: %w", err)
	}
	defer erows.Close()

	var embeds [][]interface{}
	for erows.Next() {
		var e struct {
			eType       string
			title       *string
			description *string
			url         *string
			image_url   *string
			video_url   *string
			color       *int
		}
		if err := erows.Scan(&e.eType, &e.title, &e.description, &e.url, &e.image_url, &e.video_url, &e.color); err == nil {
			embeds = append(embeds, []interface{}{uuid.New(), newMsgID, e.eType, e.title, e.description, e.url, e.image_url, e.video_url, e.color})
		}
	}
	erows.Close()

	if len(embeds) > 0 {
		_, err = tx.CopyFrom(ctx, pgx.Identifier{"public", "embeds"},
			[]string{"id", "message_id", "type", "title", "description", "url", "image_url", "video_url", "color"},
			pgx.CopyFromRows(embeds))
		if err != nil {
			log.Printf("[Crosspost] failed to copy embeds: %v", err)
		}
	}

	// 8.5 Audit Log
	// We need the server ID for the target channel.
	var serverID uuid.UUID
	err = tx.QueryRow(ctx, "SELECT server_id FROM public.channels WHERE id = $1", targetChanUUID).Scan(&serverID)
	if err == nil {
		s.auditService.CreateLog(ctx, serverID.String(), &userID, models.ActionMessageCrosspost, "channel", &targetChannelID, nil, map[string]interface{}{
			"original_message_id": originalMessageID,
			"target_channel_id":   targetChannelID,
		})
	}

	// 9. Commit
	if err := tx.Commit(ctx); err != nil {
		return nil, fmt.Errorf("failed to commit crosspost transaction: %w", err)
	}

	return newMsg, nil
}
