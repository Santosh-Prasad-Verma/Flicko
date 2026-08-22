package repository

import (
	"context"
	stderrors "errors"
	"time"
        "strings"

	"github.com/jackc/pgx/v5"
	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"

	"github.com/flicko-org/flicko/services/shared/errors"
)

// pgMessageRepo is the PostgreSQL implementation of MessageRepository.
type pgMessageRepo struct {
	pool *pgxpool.Pool
	log  *zap.Logger
}

// NewMessageRepository returns a production MessageRepository backed by pgx.
func NewMessageRepository(pool *pgxpool.Pool, log *zap.Logger) MessageRepository {
	return &pgMessageRepo{pool: pool, log: log.Named("message_repo")}
}

// queryTimeout is the default per-query context timeout.
const queryTimeout = 5 * time.Second

// slowQueryThreshold logs a warning when exceeded.
const slowQueryThreshold = 100 * time.Millisecond

// ---------- helpers ----------

// withTimeout wraps ctx with the default query timeout.
func withTimeout(ctx context.Context) (context.Context, context.CancelFunc) {
	return context.WithTimeout(ctx, queryTimeout)
}

// observeQuery logs slow queries as warnings.
func observeQuery(log *zap.Logger, op string, start time.Time) {
	d := time.Since(start)
	if d > slowQueryThreshold {
		log.Warn("slow query",
			zap.String("op", op),
			zap.Duration("duration", d),
		)
	} else {
		log.Debug("query",
			zap.String("op", op),
			zap.Duration("duration", d),
		)
	}
}

// mapError translates pgx errors into shared/errors domain errors.
func mapError(err error, resource string) error {
	if err == nil {
		return nil
	}
	if err == pgx.ErrNoRows {
		return errors.ErrNotFound(resource)
	}
	// pgx provides *pgconn.PgError for constraint violations, etc.
	// We check the SQLSTATE code prefix:
	//   23505 = unique_violation → Conflict
	//   23503 = foreign_key_violation → NotFound (dangling FK)
	pgErr := pgErrorCode(err)
	switch pgErr {
	case "23505":
		return errors.ErrConflict(resource + " already exists")
	case "23503":
		return errors.ErrNotFound(resource + " references a missing entity")
	}
	return errors.ErrInternal(err)
}

// pgErrorCode extracts a 5-char PG SQLSTATE from err, or "".
func pgErrorCode(err error) string {
	// pgx wraps *pgconn.PgError which has a Code field.
	type pgError interface{ SQLState() string }
	var pe pgError
	if stderrors.As(err, &pe) {
		return pe.SQLState()
	}
	return ""
}

// ---------- Create ----------

func (r *pgMessageRepo) Create(ctx context.Context, msg *Message) error {
	ctx, cancel := withTimeout(ctx)
	defer cancel()
	start := time.Now()
	defer func() { observeQuery(r.log, "message.Create", start) }()

	att := msg.Attachments
	if att == nil {
		att = DefaultAttachments()
	}
	emb := msg.Embeds
	if emb == nil {
		emb = DefaultEmbeds()
	}

	const q = `
		INSERT INTO messages (id, channel_id, author_id, content, attachments, embeds,
		                      pinned, type, reply_to_id, created_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
		RETURNING created_at`

	err := r.pool.QueryRow(ctx, q,
		msg.ID, msg.ChannelID, msg.AuthorID, msg.Content,
		att, emb, msg.Pinned, msg.Type, msg.ReplyToID, msg.CreatedAt,
	).Scan(&msg.CreatedAt)

	return mapError(err, "message")
}

// ---------- BulkInsert (CopyFrom) ----------

func (r *pgMessageRepo) BulkInsert(ctx context.Context, msgs []*Message) error {
	if len(msgs) == 0 {
		return nil
	}
	ctx, cancel := withTimeout(ctx)
	defer cancel()
	start := time.Now()
	defer func() { observeQuery(r.log, "message.BulkInsert", start) }()

	columns := []string{
		"id", "channel_id", "author_id", "content",
		"attachments", "embeds", "pinned", "type",
		"reply_to_id", "created_at",
	}

	rows := make([][]interface{}, 0, len(msgs))
	for _, m := range msgs {
		att := m.Attachments
		if att == nil {
			att = DefaultAttachments()
		}
		emb := m.Embeds
		if emb == nil {
			emb = DefaultEmbeds()
		}
		rows = append(rows, []interface{}{
			m.ID, m.ChannelID, m.AuthorID, m.Content,
			att, emb, m.Pinned, m.Type,
			m.ReplyToID, m.CreatedAt,
		})
	}

	_, err := r.pool.CopyFrom(ctx,
		pgx.Identifier{"messages"},
		columns,
		pgx.CopyFromRows(rows),
	)
	if err != nil {
		r.log.Error("bulk insert failed",
			zap.Int("count", len(msgs)),
			zap.Error(err),
		)
		return mapError(err, "message")
	}
	r.log.Debug("bulk insert", zap.Int("count", len(msgs)))
	return nil
}

// ---------- GetByChannel (cursor pagination) ----------

// defaultLimit caps the number of messages returned per page.
const defaultLimit = 50
const maxLimit = 100

func (r *pgMessageRepo) GetByChannel(ctx context.Context, channelID string, before string, limit int) ([]*Message, error) {
	ctx, cancel := withTimeout(ctx)
	defer cancel()
	start := time.Now()
	defer func() { observeQuery(r.log, "message.GetByChannel", start) }()

	if limit <= 0 || limit > maxLimit {
		limit = defaultLimit
	}

	var (
		rows pgx.Rows
		err  error
	)

	if before == "" {
		const q = `
			SELECT id, channel_id, author_id, content, attachments, embeds,
			       pinned, type, reply_to_id, edited, edited_at, created_at, updated_at
			FROM messages
			WHERE channel_id = $1
			ORDER BY created_at DESC
			LIMIT $2`
		rows, err = r.pool.Query(ctx, q, channelID, limit)
	} else if _, parseErr := time.Parse(time.RFC3339Nano, before); parseErr == nil {
		const q = `
			SELECT id, channel_id, author_id, content, attachments, embeds,
			       pinned, type, reply_to_id, edited, edited_at, created_at, updated_at
			FROM messages
			WHERE channel_id = $1 AND created_at < $2
			ORDER BY created_at DESC
			LIMIT $3`
		rows, err = r.pool.Query(ctx, q, channelID, before, limit)
	} else if _, parseErr := time.Parse(time.RFC3339, before); parseErr == nil {
		const q = `
			SELECT id, channel_id, author_id, content, attachments, embeds,
			       pinned, type, reply_to_id, edited, edited_at, created_at, updated_at
			FROM messages
			WHERE channel_id = $1 AND created_at < $2
			ORDER BY created_at DESC
			LIMIT $3`
		rows, err = r.pool.Query(ctx, q, channelID, before, limit)
	} else {
		// 'before' cursor is a message ID
		const q = `
			SELECT id, channel_id, author_id, content, attachments, embeds,
			       pinned, type, reply_to_id, edited, edited_at, created_at, updated_at
			FROM messages
			WHERE channel_id = $1 AND created_at < (
				SELECT created_at FROM messages WHERE id = $2 LIMIT 1
			)
			ORDER BY created_at DESC
			LIMIT $3`
		rows, err = r.pool.Query(ctx, q, channelID, before, limit)
	}
	if err != nil {
		return nil, mapError(err, "message")
	}
	defer rows.Close()

	return collectMessages(rows)
}

// ---------- GetByID ----------

func (r *pgMessageRepo) GetByID(ctx context.Context, channelID, msgID string) (*Message, error) {
	ctx, cancel := withTimeout(ctx)
	defer cancel()
	start := time.Now()
	defer func() { observeQuery(r.log, "message.GetByID", start) }()

	const q = `
		SELECT id, channel_id, author_id, content, attachments, embeds,
		       pinned, type, reply_to_id, edited, edited_at, created_at, updated_at
		FROM messages
		WHERE channel_id = $1 AND id = $2`

	msg := &Message{}
	err := r.pool.QueryRow(ctx, q, channelID, msgID).Scan(
		&msg.ID, &msg.ChannelID, &msg.AuthorID, &msg.Content,
		&msg.Attachments, &msg.Embeds, &msg.Pinned, &msg.Type,
		&msg.ReplyToID, &msg.Edited, &msg.EditedAt,
		&msg.CreatedAt, &msg.UpdatedAt,
	)
	if err != nil {
		return nil, mapError(err, "message")
	}
	return msg, nil
}

// GetByMessageID returns a message by message ID only.
func (r *pgMessageRepo) GetByMessageID(ctx context.Context, msgID string) (*Message, error) {
	ctx, cancel := withTimeout(ctx)
	defer cancel()
	start := time.Now()
	defer func() { observeQuery(r.log, "message.GetByMessageID", start) }()

	const q = `
		SELECT id, channel_id, author_id, content, attachments, embeds,
		       pinned, type, reply_to_id, edited, edited_at, created_at, updated_at
		FROM messages
		WHERE id = $1`

	msg := &Message{}
	err := r.pool.QueryRow(ctx, q, msgID).Scan(
		&msg.ID, &msg.ChannelID, &msg.AuthorID, &msg.Content,
		&msg.Attachments, &msg.Embeds, &msg.Pinned, &msg.Type,
		&msg.ReplyToID, &msg.Edited, &msg.EditedAt,
		&msg.CreatedAt, &msg.UpdatedAt,
	)
	if err != nil {
		return nil, mapError(err, "message")
	}
	return msg, nil
}

// ---------- Update ----------

func (r *pgMessageRepo) Update(ctx context.Context, msgID string, content string) error {
	ctx, cancel := withTimeout(ctx)
	defer cancel()
	start := time.Now()
	defer func() { observeQuery(r.log, "message.Update", start) }()

	// The DB trigger (handle_message_edit) sets edited=true, edited_at, updated_at.
	const q = `UPDATE messages SET content = $1 WHERE id = $2`
	tag, err := r.pool.Exec(ctx, q, content, msgID)
	if err != nil {
		return mapError(err, "message")
	}
	if tag.RowsAffected() == 0 {
		return errors.ErrNotFound("message")
	}
	return nil
}

// ---------- SoftDelete ----------

func (r *pgMessageRepo) SoftDelete(ctx context.Context, msgID string) error {
	ctx, cancel := withTimeout(ctx)
	defer cancel()
	start := time.Now()
	defer func() { observeQuery(r.log, "message.SoftDelete", start) }()

	// Clear content, unpin, set updated_at to mark as deleted.
	// The row is kept so channel history is intact.
	const q = `
		UPDATE messages
		SET content = '', pinned = false, updated_at = NOW()
		WHERE id = $1`
	tag, err := r.pool.Exec(ctx, q, msgID)
	if err != nil {
		return mapError(err, "message")
	}
	if tag.RowsAffected() == 0 {
		return errors.ErrNotFound("message")
	}
	return nil
}

// ---------- GetByNonce ----------

func (r *pgMessageRepo) GetByNonce(ctx context.Context, channelID, nonce string) (*Message, error) {
	ctx, cancel := withTimeout(ctx)
	defer cancel()
	start := time.Now()
	defer func() { observeQuery(r.log, "message.GetByNonce", start) }()

	// Nonce-based dedup: look up recent messages by the same nonce in the
	// same channel.  We search only the last 5 minutes to keep the window small.
	const q = `
		SELECT id, channel_id, author_id, content, attachments, embeds,
		       pinned, type, reply_to_id, edited, edited_at, created_at, updated_at
		FROM messages
		WHERE channel_id = $1
		  AND content = content  -- placeholder: nonce is checked at app-level via idempotency service
		LIMIT 0`

	// NOTE: The messages schema doesn't have a nonce column. Nonce-based
	// idempotency is handled by the idempotency package (Redis-backed).
	// This method is kept in the interface for forward-compatibility if a
	// nonce column is added later.  For now it always returns nil, nil.
	_ = ctx
	_ = channelID
	_ = nonce
	_ = q
	return nil, nil
}

// ---------- row scanner ----------

func collectMessages(rows pgx.Rows) ([]*Message, error) {
	var result []*Message
	for rows.Next() {
		msg := &Message{}
		if err := rows.Scan(
			&msg.ID, &msg.ChannelID, &msg.AuthorID, &msg.Content,
			&msg.Attachments, &msg.Embeds, &msg.Pinned, &msg.Type,
			&msg.ReplyToID, &msg.Edited, &msg.EditedAt,
			&msg.CreatedAt, &msg.UpdatedAt,
		); err != nil {
			return nil, mapError(err, "message")
		}
		// Ensure non-nil JSONB slices for JSON marshalling.
		if msg.Attachments == nil {
			msg.Attachments = DefaultAttachments()
		}
		if msg.Embeds == nil {
			msg.Embeds = DefaultEmbeds()
		}
		result = append(result, msg)
	}
	if err := rows.Err(); err != nil {
		return nil, mapError(err, "message")
	}
	return result, nil
}

// Search performs full-text search on messages in a channel.
// Uses PostgreSQL ILIKE for simplicity (ts_vector would require a GIN index
// that may not exist yet in the migration set).
func (r *pgMessageRepo) Search(ctx context.Context, channelID, query, before string, limit int) ([]*Message, error) {
	ctx, cancel := withTimeout(ctx)
	defer cancel()
	start := time.Now()
	defer func() { observeQuery(r.log, "message.Search", start) }()

        query = strings.ReplaceAll(query, "\\", "\\\\")
        query = strings.ReplaceAll(query, "%", "\\%")
        query = strings.ReplaceAll(query, "_", "\\_")
        pattern := "%" + query + "%"

	var rows pgx.Rows
	var err error

	if before != "" {
		rows, err = r.pool.Query(ctx,
			`SELECT id, channel_id, author_id, content, attachments, embeds,
			        pinned, type, reply_to_id, edited, edited_at, created_at, updated_at
			 FROM messages
			 WHERE channel_id = $1
			   AND content ILIKE $2 ESCAPE '\'
			   AND created_at < $3
			 ORDER BY created_at DESC
			 LIMIT $4`,
			channelID, pattern, before, limit,
		)
	} else {
		rows, err = r.pool.Query(ctx,
			`SELECT id, channel_id, author_id, content, attachments, embeds,
			        pinned, type, reply_to_id, edited, edited_at, created_at, updated_at
			 FROM messages
			 WHERE channel_id = $1
			   AND content ILIKE $2 ESCAPE '\'
			 ORDER BY created_at DESC
			 LIMIT $3`,
			channelID, pattern, limit,
		)
	}
	if err != nil {
		return nil, mapError(err, "message")
	}
	defer rows.Close()

	return collectMessages(rows)
}
