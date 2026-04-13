package repository

import (
	"context"
	"fmt"
	"strings"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"

	"github.com/flicko-org/flicko/services/shared/errors"
)

// pgChannelRepo is the PostgreSQL implementation of ChannelRepository.
type pgChannelRepo struct {
	pool *pgxpool.Pool
	log  *zap.Logger
}

// NewChannelRepository returns a production ChannelRepository backed by pgx.
func NewChannelRepository(pool *pgxpool.Pool, log *zap.Logger) ChannelRepository {
	return &pgChannelRepo{pool: pool, log: log.Named("channel_repo")}
}

// ---------- Create ----------

func (r *pgChannelRepo) Create(ctx context.Context, ch *Channel) error {
	ctx, cancel := withTimeout(ctx)
	defer cancel()
	start := time.Now()
	defer func() { observeQuery(r.log, "channel.Create", start) }()

	const q = `
		INSERT INTO channels (id, server_id, name, type, parent_id, position,
		                      topic, rate_limit_per_user, nsfw, created_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
		RETURNING created_at`

	err := r.pool.QueryRow(ctx, q,
		ch.ID, ch.ServerID, ch.Name, ch.Type, ch.ParentID,
		ch.Position, ch.Topic, ch.RateLimitPerUser, ch.NSFW, ch.CreatedAt,
	).Scan(&ch.CreatedAt)

	return mapError(err, "channel")
}

// ---------- GetByID ----------

func (r *pgChannelRepo) GetByID(ctx context.Context, channelID string) (*Channel, error) {
	ctx, cancel := withTimeout(ctx)
	defer cancel()
	start := time.Now()
	defer func() { observeQuery(r.log, "channel.GetByID", start) }()

	const q = `
		SELECT id, server_id, name, type, parent_id, position,
		       topic, rate_limit_per_user, nsfw, created_at, updated_at
		FROM channels
		WHERE id = $1`

	ch := &Channel{}
	err := r.pool.QueryRow(ctx, q, channelID).Scan(
		&ch.ID, &ch.ServerID, &ch.Name, &ch.Type, &ch.ParentID,
		&ch.Position, &ch.Topic, &ch.RateLimitPerUser, &ch.NSFW,
		&ch.CreatedAt, &ch.UpdatedAt,
	)
	if err != nil {
		return nil, mapError(err, "channel")
	}
	return ch, nil
}

// ---------- GetByGuild ----------

func (r *pgChannelRepo) GetByGuild(ctx context.Context, guildID string) ([]*Channel, error) {
	ctx, cancel := withTimeout(ctx)
	defer cancel()
	start := time.Now()
	defer func() { observeQuery(r.log, "channel.GetByGuild", start) }()

	const q = `
		SELECT id, server_id, name, type, parent_id, position,
		       topic, rate_limit_per_user, nsfw, created_at, updated_at
		FROM channels
		WHERE server_id = $1
		ORDER BY position ASC, created_at ASC`

	rows, err := r.pool.Query(ctx, q, guildID)
	if err != nil {
		return nil, mapError(err, "channel")
	}
	defer rows.Close()

	var result []*Channel
	for rows.Next() {
		ch := &Channel{}
		if err := rows.Scan(
			&ch.ID, &ch.ServerID, &ch.Name, &ch.Type, &ch.ParentID,
			&ch.Position, &ch.Topic, &ch.RateLimitPerUser, &ch.NSFW,
			&ch.CreatedAt, &ch.UpdatedAt,
		); err != nil {
			return nil, mapError(err, "channel")
		}
		result = append(result, ch)
	}
	return result, rows.Err()
}

// ---------- Update (dynamic SET) ----------

func (r *pgChannelRepo) Update(ctx context.Context, channelID string, u ChannelUpdate) error {
	ctx, cancel := withTimeout(ctx)
	defer cancel()
	start := time.Now()
	defer func() { observeQuery(r.log, "channel.Update", start) }()

	// Build a dynamic SET clause from non-nil fields.
	setClauses := make([]string, 0, 6)
	args := make([]interface{}, 0, 8)
	argIdx := 1

	addField := func(col string, val interface{}) {
		setClauses = append(setClauses, fmt.Sprintf("%s = $%d", col, argIdx))
		args = append(args, val)
		argIdx++
	}

	if u.Name != nil {
		addField("name", *u.Name)
	}
	if u.Topic != nil {
		addField("topic", *u.Topic)
	}
	if u.Position != nil {
		addField("position", *u.Position)
	}
	if u.RateLimitPerUser != nil {
		addField("rate_limit_per_user", *u.RateLimitPerUser)
	}
	if u.NSFW != nil {
		addField("nsfw", *u.NSFW)
	}
	if u.ParentID != nil {
		addField("parent_id", *u.ParentID)
	}

	if len(setClauses) == 0 {
		return nil // nothing to update
	}

	// Always bump updated_at.
	setClauses = append(setClauses, fmt.Sprintf("updated_at = $%d", argIdx))
	args = append(args, time.Now())
	argIdx++

	args = append(args, channelID)
	q := fmt.Sprintf("UPDATE channels SET %s WHERE id = $%d",
		strings.Join(setClauses, ", "), argIdx)

	tag, err := r.pool.Exec(ctx, q, args...)
	if err != nil {
		return mapError(err, "channel")
	}
	if tag.RowsAffected() == 0 {
		return errors.ErrNotFound("channel")
	}
	return nil
}

// ---------- Delete ----------

func (r *pgChannelRepo) Delete(ctx context.Context, channelID string) error {
	ctx, cancel := withTimeout(ctx)
	defer cancel()
	start := time.Now()
	defer func() { observeQuery(r.log, "channel.Delete", start) }()

	const q = `DELETE FROM channels WHERE id = $1`
	tag, err := r.pool.Exec(ctx, q, channelID)
	if err != nil {
		return mapError(err, "channel")
	}
	if tag.RowsAffected() == 0 {
		return errors.ErrNotFound("channel")
	}
	return nil
}

// ---------- IsMember ----------

func (r *pgChannelRepo) IsMember(ctx context.Context, channelID, userID string) (bool, error) {
	ctx, cancel := withTimeout(ctx)
	defer cancel()
	start := time.Now()
	defer func() { observeQuery(r.log, "channel.IsMember", start) }()

	// Check if the user is a member of the guild that owns the channel.
	const q = `
		SELECT EXISTS (
			SELECT 1
			FROM server_members sm
			JOIN channels c ON c.server_id = sm.server_id
			WHERE c.id = $1 AND sm.user_id = $2
		)`

	var exists bool
	err := r.pool.QueryRow(ctx, q, channelID, userID).Scan(&exists)
	if err != nil {
		return false, mapError(err, "member")
	}
	return exists, nil
}
