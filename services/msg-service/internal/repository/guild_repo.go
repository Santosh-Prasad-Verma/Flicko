package repository

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
	"go.uber.org/zap"

	"github.com/flicko-org/flicko/services/shared/errors"
)

// pgGuildRepo is the PostgreSQL implementation of GuildRepository.
type pgGuildRepo struct {
	pool *pgxpool.Pool
	log  *zap.Logger
}

// NewGuildRepository returns a production GuildRepository backed by pgx.
func NewGuildRepository(pool *pgxpool.Pool, log *zap.Logger) GuildRepository {
	return &pgGuildRepo{pool: pool, log: log.Named("guild_repo")}
}

// ---------- Create ----------

func (r *pgGuildRepo) Create(ctx context.Context, g *Guild) error {
	ctx, cancel := withTimeout(ctx)
	defer cancel()
	start := time.Now()
	defer func() { observeQuery(r.log, "guild.Create", start) }()

	const q = `
		INSERT INTO servers (id, name, description, icon, banner, owner_id,
		                     region, verification_level, features, created_at)
		VALUES ($1,$2,$3,$4,$5,$6,$7,$8,$9,$10)
		RETURNING created_at`

	err := r.pool.QueryRow(ctx, q,
		g.ID, g.Name, g.Description, g.Icon, g.Banner, g.OwnerID,
		g.Region, g.VerificationLevel, g.Features, g.CreatedAt,
	).Scan(&g.CreatedAt)

	return mapError(err, "guild")
}

// ---------- GetByID ----------

func (r *pgGuildRepo) GetByID(ctx context.Context, guildID string) (*Guild, error) {
	ctx, cancel := withTimeout(ctx)
	defer cancel()
	start := time.Now()
	defer func() { observeQuery(r.log, "guild.GetByID", start) }()

	const q = `
		SELECT id, name, description, icon, banner, owner_id,
		       region, verification_level, features, created_at, updated_at
		FROM servers
		WHERE id = $1`

	g := &Guild{}
	err := r.pool.QueryRow(ctx, q, guildID).Scan(
		&g.ID, &g.Name, &g.Description, &g.Icon, &g.Banner, &g.OwnerID,
		&g.Region, &g.VerificationLevel, &g.Features,
		&g.CreatedAt, &g.UpdatedAt,
	)
	if err != nil {
		return nil, mapError(err, "guild")
	}
	return g, nil
}

// ---------- GetUserGuilds ----------

func (r *pgGuildRepo) GetUserGuilds(ctx context.Context, userID string) ([]*Guild, error) {
	ctx, cancel := withTimeout(ctx)
	defer cancel()
	start := time.Now()
	defer func() { observeQuery(r.log, "guild.GetUserGuilds", start) }()

	const q = `
		SELECT s.id, s.name, s.description, s.icon, s.banner, s.owner_id,
		       s.region, s.verification_level, s.features, s.created_at, s.updated_at
		FROM servers s
		INNER JOIN server_members sm ON sm.server_id = s.id
		WHERE sm.user_id = $1
		ORDER BY sm.joined_at DESC`

	rows, err := r.pool.Query(ctx, q, userID)
	if err != nil {
		return nil, mapError(err, "guild")
	}
	defer rows.Close()

	var result []*Guild
	for rows.Next() {
		g := &Guild{}
		if err := rows.Scan(
			&g.ID, &g.Name, &g.Description, &g.Icon, &g.Banner, &g.OwnerID,
			&g.Region, &g.VerificationLevel, &g.Features,
			&g.CreatedAt, &g.UpdatedAt,
		); err != nil {
			return nil, mapError(err, "guild")
		}
		result = append(result, g)
	}
	return result, rows.Err()
}

// ---------- AddMember ----------

func (r *pgGuildRepo) AddMember(ctx context.Context, guildID, userID string) error {
	ctx, cancel := withTimeout(ctx)
	defer cancel()
	start := time.Now()
	defer func() { observeQuery(r.log, "guild.AddMember", start) }()

	const q = `
		INSERT INTO server_members (server_id, user_id, joined_at)
		VALUES ($1, $2, NOW())
		ON CONFLICT (server_id, user_id) DO NOTHING`

	tag, err := r.pool.Exec(ctx, q, guildID, userID)
	if err != nil {
		return mapError(err, "member")
	}
	if tag.RowsAffected() == 0 {
		return errors.ErrConflict("already a member")
	}
	return nil
}

// ---------- RemoveMember ----------

func (r *pgGuildRepo) RemoveMember(ctx context.Context, guildID, userID string) error {
	ctx, cancel := withTimeout(ctx)
	defer cancel()
	start := time.Now()
	defer func() { observeQuery(r.log, "guild.RemoveMember", start) }()

	const q = `DELETE FROM server_members WHERE server_id = $1 AND user_id = $2`
	tag, err := r.pool.Exec(ctx, q, guildID, userID)
	if err != nil {
		return mapError(err, "member")
	}
	if tag.RowsAffected() == 0 {
		return errors.ErrNotFound("member")
	}
	return nil
}

// ---------- GetMembers ----------

func (r *pgGuildRepo) GetMembers(ctx context.Context, guildID string, limit, offset int) ([]*Member, error) {
	ctx, cancel := withTimeout(ctx)
	defer cancel()
	start := time.Now()
	defer func() { observeQuery(r.log, "guild.GetMembers", start) }()

	if limit <= 0 || limit > maxLimit {
		limit = defaultLimit
	}
	if offset < 0 {
		offset = 0
	}

	const q = `
		SELECT id, server_id, user_id, nickname, roles, joined_at,
		       communication_disabled_until
		FROM server_members
		WHERE server_id = $1
		ORDER BY joined_at ASC
		LIMIT $2 OFFSET $3`

	rows, err := r.pool.Query(ctx, q, guildID, limit, offset)
	if err != nil {
		return nil, mapError(err, "member")
	}
	defer rows.Close()

	var result []*Member
	for rows.Next() {
		m := &Member{}
		if err := rows.Scan(
			&m.ID, &m.ServerID, &m.UserID, &m.Nickname,
			&m.Roles, &m.JoinedAt, &m.CommunicationDisabledUntil,
		); err != nil {
			return nil, mapError(err, "member")
		}
		result = append(result, m)
	}
	return result, rows.Err()
}

// IsMember checks whether userID belongs to guildID.
func (r *pgGuildRepo) IsMember(ctx context.Context, guildID, userID string) (bool, error) {
	ctx, cancel := withTimeout(ctx)
	defer cancel()
	start := time.Now()
	defer func() { observeQuery(r.log, "guild.IsMember", start) }()

	const q = `
		SELECT EXISTS (
			SELECT 1
			FROM server_members
			WHERE server_id = $1 AND user_id = $2
		)`

	var exists bool
	err := r.pool.QueryRow(ctx, q, guildID, userID).Scan(&exists)
	if err != nil {
		return false, mapError(err, "member")
	}
	return exists, nil
}
