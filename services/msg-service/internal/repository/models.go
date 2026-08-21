// Package repository implements PostgreSQL query functions.
package repository

import (
	"encoding/json"
	"time"
)

// ---------- Message ----------

// Message maps to the public.messages table.
// PK: id (UUID). Core indexes: (channel_id, created_at DESC), (author_id).
type Message struct {
	ID          string          `db:"id"           json:"id"`
	ChannelID   string          `db:"channel_id"   json:"channel_id"`
	AuthorID    string          `db:"author_id"    json:"author_id"`
	Content     string          `db:"content"      json:"content"`
	Attachments json.RawMessage `db:"attachments"  json:"attachments"`
	Embeds      json.RawMessage `db:"embeds"       json:"embeds"`
	Pinned      bool            `db:"pinned"       json:"pinned"`
	Type        string          `db:"type"         json:"type"`
	ReplyToID   *string         `db:"reply_to_id"  json:"reply_to_id,omitempty"`
	Edited      bool            `db:"edited"       json:"edited"`
	EditedAt    *time.Time      `db:"edited_at"    json:"edited_at,omitempty"`
	CreatedAt   time.Time       `db:"created_at"   json:"created_at"`
	UpdatedAt   *time.Time      `db:"updated_at"   json:"updated_at,omitempty"`
	// Nonce is set by the client for idempotency.
	// Not stored in the original schema but used at the service layer
	// for dedup via the idempotency package.
	Nonce *string `db:"-" json:"nonce,omitempty"`
}

// DefaultAttachments returns the DB default for the attachments JSONB column.
func DefaultAttachments() json.RawMessage { return json.RawMessage(`[]`) }

// DefaultEmbeds returns the DB default for the embeds JSONB column.
func DefaultEmbeds() json.RawMessage { return json.RawMessage(`[]`) }

// ---------- Channel ----------

// Channel maps to the public.channels table.
// Types: 'text', 'voice', 'announcement', 'category'.
type Channel struct {
	ID               string     `db:"id"                  json:"id"`
	ServerID         string     `db:"server_id"           json:"server_id"`
	Name             string     `db:"name"                json:"name"`
	Type             string     `db:"type"                json:"type"`
	ParentID         *string    `db:"parent_id"           json:"parent_id,omitempty"`
	Position         int        `db:"position"            json:"position"`
	Topic            *string    `db:"topic"               json:"topic,omitempty"`
	RateLimitPerUser int        `db:"rate_limit_per_user" json:"rate_limit_per_user"`
	NSFW             bool       `db:"nsfw"                json:"nsfw"`
	CreatedAt        time.Time  `db:"created_at"          json:"created_at"`
	UpdatedAt        *time.Time `db:"updated_at"          json:"updated_at,omitempty"`
}

// ChannelUpdate holds fields that can be updated on a channel.
// Nil pointers mean "don't update this field".
type ChannelUpdate struct {
	Name             *string `json:"name,omitempty"`
	Topic            *string `json:"topic,omitempty"`
	Position         *int    `json:"position,omitempty"`
	RateLimitPerUser *int    `json:"rate_limit_per_user,omitempty"`
	NSFW             *bool   `json:"nsfw,omitempty"`
	ParentID         *string `json:"parent_id,omitempty"`
}

// ---------- Guild (Server) ----------

// Guild maps to the public.servers table.
// The prompt uses "guild" terminology; the DB table is "servers".
type Guild struct {
	ID                string     `db:"id"                 json:"id"`
	Name              string     `db:"name"               json:"name"`
	Description       *string    `db:"description"        json:"description,omitempty"`
	Icon              *string    `db:"icon"               json:"icon,omitempty"`
	Banner            *string    `db:"banner"             json:"banner,omitempty"`
	OwnerID           string     `db:"owner_id"           json:"owner_id"`
	Region            string     `db:"region"             json:"region"`
	VerificationLevel int        `db:"verification_level" json:"verification_level"`
	Features          []string   `db:"features"           json:"features"`
	CreatedAt         time.Time  `db:"created_at"         json:"created_at"`
	UpdatedAt         *time.Time `db:"updated_at"         json:"updated_at,omitempty"`
}

// ---------- Member ----------

// Member maps to the public.server_members table.
// Unique constraint on (server_id, user_id).
type Member struct {
	ID                         string     `db:"id"                            json:"id"`
	ServerID                   string     `db:"server_id"                     json:"server_id"`
	UserID                     string     `db:"user_id"                       json:"user_id"`
	Nickname                   *string    `db:"nickname"                      json:"nickname,omitempty"`
	Roles                      []string   `db:"roles"                         json:"roles"`
	JoinedAt                   time.Time  `db:"joined_at"                     json:"joined_at"`
	CommunicationDisabledUntil *time.Time `db:"communication_disabled_until"  json:"communication_disabled_until,omitempty"`
}

// ---------- Read State ----------

// ReadState maps to the public.channel_read_states table.
// Composite PK: (user_id, channel_id).
type ReadState struct {
	UserID            string    `db:"user_id"              json:"user_id"`
	ChannelID         string    `db:"channel_id"           json:"channel_id"`
	LastReadMessageID *string   `db:"last_read_message_id" json:"last_read_message_id,omitempty"`
	MentionCount      int       `db:"mention_count"        json:"mention_count"`
	UpdatedAt         time.Time `db:"updated_at"           json:"updated_at"`
}

// ---------- Poll ----------

// Poll maps to the public.polls table.
type Poll struct {
	ID             string     `db:"id"               json:"id"`
	ChannelID      string     `db:"channel_id"       json:"channel_id"`
	CreatorID      string     `db:"creator_id"       json:"creator_id"`
	Question       string     `db:"question"         json:"question"`
	AllowMultiVote bool       `db:"allow_multi_vote" json:"allow_multi_vote"`
	ExpiresAt      *time.Time `db:"expires_at"       json:"expires_at,omitempty"`
	EndedAt        *time.Time `db:"ended_at"         json:"ended_at,omitempty"`
	CreatedAt      time.Time  `db:"created_at"       json:"created_at"`
}

// PollOption maps to the public.poll_options table.
type PollOption struct {
	ID        string `db:"id"        json:"id"`
	PollID    string `db:"poll_id"   json:"poll_id"`
	Text      string `db:"text"      json:"text"`
	Emoji     string `db:"emoji"     json:"emoji,omitempty"`
	Position  int    `db:"position"  json:"position"`
	VoteCount int    `db:"vote_count" json:"vote_count"` // aggregated, not a DB column
}

// PollVote maps to the public.poll_votes table.
type PollVote struct {
	ID       string    `db:"id"        json:"id"`
	PollID   string    `db:"poll_id"   json:"poll_id"`
	OptionID string    `db:"option_id" json:"option_id"`
	UserID   string    `db:"user_id"   json:"user_id"`
	VotedAt  time.Time `db:"voted_at"  json:"voted_at"`
}
