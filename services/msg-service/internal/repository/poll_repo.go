package repository

import (
	"context"
	"time"

	"github.com/jackc/pgx/v5/pgxpool"
)

// PollRepo implements PollRepository using PostgreSQL.
type PollRepo struct {
	pool *pgxpool.Pool
}

// NewPollRepo creates a PollRepo.
func NewPollRepo(pool *pgxpool.Pool) *PollRepo {
	return &PollRepo{pool: pool}
}

// CreateWithOptions inserts a poll and its options inside a transaction.
func (r *PollRepo) CreateWithOptions(ctx context.Context, poll *Poll, options []*PollOption) error {
	tx, err := r.pool.Begin(ctx)
	if err != nil {
		return err
	}
	defer tx.Rollback(ctx)

	_, err = tx.Exec(ctx,
		`INSERT INTO polls (id, channel_id, creator_id, question, allow_multi_vote, expires_at)
		 VALUES ($1, $2, $3, $4, $5, $6)`,
		poll.ID, poll.ChannelID, poll.CreatorID, poll.Question,
		poll.AllowMultiVote, poll.ExpiresAt,
	)
	if err != nil {
		return err
	}

	for _, o := range options {
		_, err = tx.Exec(ctx,
			`INSERT INTO poll_options (id, poll_id, text, emoji, position)
			 VALUES ($1, $2, $3, $4, $5)`,
			o.ID, o.PollID, o.Text, o.Emoji, o.Position,
		)
		if err != nil {
			return err
		}
	}

	return tx.Commit(ctx)
}

// GetByID returns a single poll.
func (r *PollRepo) GetByID(ctx context.Context, pollID string) (*Poll, error) {
	row := r.pool.QueryRow(ctx,
		`SELECT id, channel_id, creator_id, question, allow_multi_vote,
		        expires_at, ended_at, created_at
		 FROM polls WHERE id = $1`, pollID)

	p := &Poll{}
	err := row.Scan(
		&p.ID, &p.ChannelID, &p.CreatorID, &p.Question,
		&p.AllowMultiVote, &p.ExpiresAt, &p.EndedAt, &p.CreatedAt,
	)
	if err != nil {
		return nil, err
	}
	return p, nil
}

// GetOptions returns all options for a poll with their vote counts.
func (r *PollRepo) GetOptions(ctx context.Context, pollID string) ([]*PollOption, error) {
	rows, err := r.pool.Query(ctx,
		`SELECT o.id, o.poll_id, o.text, COALESCE(o.emoji, ''), o.position,
		        COUNT(v.id)::int AS vote_count
		 FROM poll_options o
		 LEFT JOIN poll_votes v ON v.option_id = o.id
		 WHERE o.poll_id = $1
		 GROUP BY o.id
		 ORDER BY o.position`, pollID)
	if err != nil {
		return nil, err
	}
	defer rows.Close()

	var options []*PollOption
	for rows.Next() {
		o := &PollOption{}
		if err := rows.Scan(&o.ID, &o.PollID, &o.Text, &o.Emoji, &o.Position, &o.VoteCount); err != nil {
			return nil, err
		}
		options = append(options, o)
	}
	return options, rows.Err()
}

// AddVote inserts a vote row.
func (r *PollRepo) AddVote(ctx context.Context, pollID, optionID, userID string) error {
	_, err := r.pool.Exec(ctx,
		`INSERT INTO poll_votes (poll_id, option_id, user_id)
		 VALUES ($1, $2, $3)
		 ON CONFLICT (poll_id, user_id, option_id) DO NOTHING`,
		pollID, optionID, userID,
	)
	return err
}

// RemoveVote removes all votes by a user on a poll.
func (r *PollRepo) RemoveVote(ctx context.Context, pollID, userID string) error {
	_, err := r.pool.Exec(ctx,
		`DELETE FROM poll_votes WHERE poll_id = $1 AND user_id = $2`,
		pollID, userID,
	)
	return err
}

// EndPoll marks a poll as ended.
func (r *PollRepo) EndPoll(ctx context.Context, pollID string) error {
	_, err := r.pool.Exec(ctx,
		`UPDATE polls SET ended_at = $1 WHERE id = $2`,
		time.Now(), pollID,
	)
	return err
}
