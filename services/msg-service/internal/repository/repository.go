package repository

import "context"

// MessageRepository defines data-access operations for the messages table.
type MessageRepository interface {
	// Create inserts a single message.
	Create(ctx context.Context, msg *Message) error

	// BulkInsert writes multiple messages in one round-trip (pgx CopyFrom).
	BulkInsert(ctx context.Context, msgs []*Message) error

	// GetByChannel returns messages for a channel with cursor-based pagination.
	// If before is empty, the latest messages are returned.
	// Results are ordered by created_at DESC (newest first).
	GetByChannel(ctx context.Context, channelID string, before string, limit int) ([]*Message, error)

	// GetByID returns a single message by channel and message ID.
	GetByID(ctx context.Context, channelID, msgID string) (*Message, error)

	// GetByMessageID returns a single message by message ID.
	GetByMessageID(ctx context.Context, msgID string) (*Message, error)

	// Update changes the content of a message (the DB trigger marks it edited).
	Update(ctx context.Context, msgID string, content string) error

	// SoftDelete marks a message as deleted (sets content to empty, pinned=false).
	// The row stays for audit; the application hides it from normal reads.
	SoftDelete(ctx context.Context, msgID string) error

	// GetByNonce returns a message by its nonce (idempotency check).
	// Returns nil, nil when no message matches.
	GetByNonce(ctx context.Context, channelID, nonce string) (*Message, error)

	// Search performs full-text search on messages in a channel.
	// Uses PostgreSQL ts_vector search with ILIKE fallback.
	Search(ctx context.Context, channelID, query, before string, limit int) ([]*Message, error)
}

// ChannelRepository defines data-access operations for the channels table.
type ChannelRepository interface {
	// Create inserts a new channel.
	Create(ctx context.Context, ch *Channel) error

	// GetByID returns a single channel.
	GetByID(ctx context.Context, channelID string) (*Channel, error)

	// GetByGuild returns all channels in a guild (server), ordered by position.
	GetByGuild(ctx context.Context, guildID string) ([]*Channel, error)

	// Update patches channel fields. Only non-nil fields in ChannelUpdate are changed.
	Update(ctx context.Context, channelID string, updates ChannelUpdate) error

	// Delete removes a channel.
	Delete(ctx context.Context, channelID string) error

	// IsMember checks whether userID is a member of the guild that owns channelID.
	IsMember(ctx context.Context, channelID, userID string) (bool, error)
}

// GuildRepository defines data-access operations for the servers table.
type GuildRepository interface {
	// Create inserts a new guild (server).
	Create(ctx context.Context, g *Guild) error

	// GetByID returns a guild by its ID.
	GetByID(ctx context.Context, guildID string) (*Guild, error)

	// GetUserGuilds returns all guilds the user is a member of.
	GetUserGuilds(ctx context.Context, userID string) ([]*Guild, error)

	// AddMember inserts a member row into server_members.
	AddMember(ctx context.Context, guildID, userID string) error

	// RemoveMember deletes a member row from server_members.
	RemoveMember(ctx context.Context, guildID, userID string) error

	// GetMembers returns guild members with offset-based pagination.
	GetMembers(ctx context.Context, guildID string, limit, offset int) ([]*Member, error)

	// IsMember checks whether userID is a member of guildID.
	IsMember(ctx context.Context, guildID, userID string) (bool, error)
}

// PollRepository defines data-access operations for polls.
type PollRepository interface {
	// CreateWithOptions inserts a poll and its options in a transaction.
	CreateWithOptions(ctx context.Context, poll *Poll, options []*PollOption) error

	// GetByID returns a poll by ID.
	GetByID(ctx context.Context, pollID string) (*Poll, error)

	// GetOptions returns all options for a poll with vote counts.
	GetOptions(ctx context.Context, pollID string) ([]*PollOption, error)

	// AddVote inserts a vote.
	AddVote(ctx context.Context, pollID, optionID, userID string) error

	// RemoveVote removes a user's vote(s) from a poll.
	RemoveVote(ctx context.Context, pollID, userID string) error

	// EndPoll sets ended_at on a poll.
	EndPoll(ctx context.Context, pollID string) error
}
